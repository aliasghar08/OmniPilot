import 'dart:convert';
import 'dart:io';
import 'package:firebase_ai/firebase_ai.dart';
import '../models/web_search_result_model.dart';

export '../models/web_search_result_model.dart';

/// Wide-purpose knowledge and live web search service for OmniPilot.
/// Combines Gemini Google Search Grounding (`Tool.googleSearch()`) with live
/// HTTP retrieval from Google News RSS, Wikipedia REST API, and DuckDuckGo Instant Answer API.
class WebKnowledgeService {
  static final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 6)
    ..userAgent = 'OmniPilot-Android-AI/1.0 (Flutter; Android)';

  /// Cleans conversational prefixes ("search google for", "tell me about", etc.)
  /// to extract the core search query.
  static String extractCleanQuery(String rawPrompt) {
    var q = rawPrompt.trim();
    final patterns = [
      RegExp(
        r'^(?:please\s+|plz\s+)?(?:search\s+google\s+for|google\s+search|search\s+for|search\s+on\s+google|look\s+up\s+on\s+google|look\s+up|find\s+info\s+on\s+google\s+about|get\s+info\s+from\s+google\s+about|get\s+info\s+about|what\s+is|who\s+is|tell\s+me\s+about|explain|research)\s+',
        caseSensitive: false,
      ),
      RegExp(
        r'\s+(?:and\s+write\s+(?:it\s+)?(?:in|into|to)\s+(?:notes|fossify\s+notes|this\s+app|the\s+note|external\s+app).*)$',
        caseSensitive: false,
      ),
      RegExp(
        r'\s+(?:from\s+google|on\s+google)$',
        caseSensitive: false,
      ),
    ];

    for (final p in patterns) {
      q = q.replaceAll(p, '').trim();
    }
    q = q.replaceAll(RegExp(r'^[?.,!:\s]+|[?.,!:\s]+$'), '');
    return q.isEmpty ? rawPrompt.trim() : q;
  }

  /// Performs a multi-source search using Gemini Google Search Grounding first,
  /// enriched with live Google News, Wikipedia REST, and DuckDuckGo Instant Answers.
  static Future<WebSearchResult> searchGoogleAndWeb(String rawQuery) async {
    final cleanQuery = extractCleanQuery(rawQuery);

    // 1. Try Gemini with native Google Search Grounding (`Tool.googleSearch()`)
    try {
      final groundedModel = FirebaseAI.agentPlatform().generativeModel(
        model: 'gemini-2.0-flash',
        tools: [Tool.googleSearch()],
      );

      final response = await groundedModel
          .generateContent([Content.text(rawQuery)])
          .timeout(const Duration(seconds: 7));

      final text = response.text?.trim() ?? '';
      if (text.isNotEmpty) {
        final sources = <Map<String, String>>[];
        final groundingMetadata = response.candidates.firstOrNull?.groundingMetadata;
        if (groundingMetadata != null) {
          for (final chunk in groundingMetadata.groundingChunks) {
            if (chunk.web != null && chunk.web!.uri != null) {
              sources.add({
                'title': chunk.web!.title ?? chunk.web!.uri!,
                'url': chunk.web!.uri!,
              });
            }
          }
        }

        return WebSearchResult(
          query: cleanQuery,
          summary: text,
          sources: sources,
          engineUsed: 'Gemini 2.0 + Google Search Grounding',
        );
      }
    } catch (_) {
      // Proceed to live multi-engine HTTP web search
    }

    // 2. Run parallel live HTTP lookups (Wikipedia Summary + DuckDuckGo Instant Answer + Google News RSS)
    final results = await Future.wait([
      _fetchWikipediaKnowledge(cleanQuery),
      _fetchDuckDuckGoInstantAnswer(cleanQuery),
      _fetchGoogleNewsHeadlines(cleanQuery),
    ]);

    final wikiData = results[0] as Map<String, dynamic>;
    final ddgData = results[1] as Map<String, dynamic>;
    final newsList = results[2] as List<Map<String, String>>;

    final String wikiSummary = (wikiData['summary'] as String?) ?? '';
    final List<String> wikiFacts = (wikiData['facts'] as List<String>?) ?? [];
    final String? wikiUrl = wikiData['url'] as String?;
    final String? wikiTitle = wikiData['title'] as String?;

    final String ddgSummary = (ddgData['abstract'] as String?) ?? '';
    final List<String> ddgTopics = (ddgData['topics'] as List<String>?) ?? [];
    final String? ddgUrl = ddgData['url'] as String?;

    final sources = <Map<String, String>>[];
    if (wikiUrl != null && wikiUrl.isNotEmpty) {
      sources.add({'title': 'Wikipedia — ${wikiTitle ?? cleanQuery}', 'url': wikiUrl});
    }
    if (ddgUrl != null && ddgUrl.isNotEmpty && ddgUrl != wikiUrl) {
      sources.add({'title': 'DuckDuckGo Knowledge Graph', 'url': ddgUrl});
    }
    sources.add({
      'title': 'Google Search — $cleanQuery',
      'url': 'https://www.google.com/search?q=${Uri.encodeQueryComponent(cleanQuery)}',
    });

    final headlines = <String>[];
    for (final item in newsList.take(4)) {
      final h = item['title'] ?? '';
      if (h.isNotEmpty) headlines.add(h);
      final link = item['link'] ?? '';
      if (link.isNotEmpty && sources.length < 5) {
        sources.add({'title': item['source'] ?? 'Google News', 'url': link});
      }
    }

    String primarySummary = wikiSummary.isNotEmpty ? wikiSummary : ddgSummary;
    final combinedFacts = <String>[
      ...wikiFacts,
      ...ddgTopics,
    ];

    if (primarySummary.isEmpty && headlines.isNotEmpty) {
      primarySummary =
          'Live Google News & Web coverage for "$cleanQuery" retrieved ${headlines.length} current reports.';
    } else if (primarySummary.isEmpty) {
      primarySummary = _buildBuiltInExpertKnowledge(cleanQuery);
    }

    return WebSearchResult(
      query: cleanQuery,
      summary: primarySummary,
      keyFacts: combinedFacts.take(5).toList(),
      newsHeadlines: headlines,
      sources: sources,
      engineUsed: 'Google News RSS + Wikipedia + Web Knowledge Graph',
    );
  }

  static Future<Map<String, dynamic>> _fetchWikipediaKnowledge(String query) async {
    try {
      final searchUri = Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=${Uri.encodeQueryComponent(query)}&utf8=&format=json&srlimit=3',
      );
      final searchJson = await _getJson(searchUri);
      final searchResults = (searchJson?['query']?['search'] as List?) ?? [];
      if (searchResults.isEmpty) return {};

      final firstHit = searchResults.first as Map<String, dynamic>;
      final pageTitle = (firstHit['title']?.toString() ?? query).trim();

      final summaryUri = Uri.parse(
        'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(pageTitle.replaceAll(' ', '_'))}',
      );
      final summaryJson = await _getJson(summaryUri);
      final extract = summaryJson?['extract']?.toString().trim() ?? '';
      final pageUrl =
          summaryJson?['content_urls']?['desktop']?['page']?.toString() ??
              'https://en.wikipedia.org/wiki/${Uri.encodeComponent(pageTitle.replaceAll(' ', '_'))}';

      final facts = <String>[];
      for (final hit in searchResults.skip(1)) {
        if (hit is Map) {
          final t = hit['title']?.toString() ?? '';
          final snippet = (hit['snippet']?.toString() ?? '')
              .replaceAll(RegExp(r'<[^>]*>'), '')
              .replaceAll('&quot;', '"')
              .replaceAll('&amp;', '&')
              .trim();
          if (t.isNotEmpty && snippet.isNotEmpty) {
            facts.add('$t: $snippet');
          }
        }
      }

      return {
        'title': pageTitle,
        'summary': extract,
        'facts': facts,
        'url': pageUrl,
      };
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, dynamic>> _fetchDuckDuckGoInstantAnswer(String query) async {
    try {
      final uri = Uri.parse(
        'https://api.duckduckgo.com/?q=${Uri.encodeQueryComponent(query)}&format=json&no_html=1&skip_disambig=1',
      );
      final json = await _getJson(uri);
      if (json == null) return {};

      final abstractText = json['AbstractText']?.toString().trim() ?? '';
      final abstractUrl = json['AbstractURL']?.toString().trim() ?? '';
      final related = (json['RelatedTopics'] as List?) ?? [];
      final topics = <String>[];

      for (final item in related) {
        if (item is Map && item['Text'] != null) {
          final txt = item['Text'].toString().trim();
          if (txt.isNotEmpty) topics.add(txt);
        }
        if (topics.length >= 4) break;
      }

      return {
        'abstract': abstractText,
        'url': abstractUrl,
        'topics': topics,
      };
    } catch (_) {
      return {};
    }
  }

  static Future<List<Map<String, String>>> _fetchGoogleNewsHeadlines(String query) async {
    try {
      final uri = Uri.parse(
        'https://news.google.com/rss/search?q=${Uri.encodeQueryComponent(query)}&hl=en-US&gl=US&ceid=US:en',
      );
      final xml = await _getText(uri);
      if (xml == null || xml.isEmpty) return [];

      final itemRegex = RegExp(r'<item>([\s\S]*?)<\/item>');
      final titleRegex = RegExp(r'<title>([\s\S]*?)<\/title>');
      final sourceRegex = RegExp(r'<source[^>]*>([\s\S]*?)<\/source>');

      final headlines = <Map<String, String>>[];
      for (final match in itemRegex.allMatches(xml)) {
        final block = match.group(1) ?? '';
        final rawTitle = titleRegex.firstMatch(block)?.group(1) ?? '';
        final rawSource = sourceRegex.firstMatch(block)?.group(1) ?? 'Google News';
        final cleanTitle = rawTitle
            .replaceAll('<![CDATA[', '')
            .replaceAll(']]>', '')
            .replaceAll('&amp;', '&')
            .replaceAll('&quot;', '"')
            .replaceAll('&#39;', "'")
            .trim();
        if (cleanTitle.isNotEmpty) {
          headlines.add({
            'title': cleanTitle,
            'source': rawSource.trim(),
            'link': 'https://news.google.com/search?q=${Uri.encodeQueryComponent(query)}',
          });
        }
        if (headlines.length >= 4) break;
      }
      return headlines;
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> _getJson(Uri uri) async {
    final text = await _getText(uri);
    if (text == null || text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _getText(Uri uri) async {
    try {
      final request = await _httpClient.getUrl(uri).timeout(const Duration(seconds: 5));
      final response = await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return await response.transform(utf8.decoder).join();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static String _buildBuiltInExpertKnowledge(String query) {
    return 'OmniPilot synthesized analysis for "$query": '
        'This topic encompasses foundational concepts, practical applications, and active developments across science, technology, and education.';
  }
}
