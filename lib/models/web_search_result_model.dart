/// Structured result from OmniPilot's Google Search Grounding + Live Web Knowledge Engine.
class WebSearchResult {
  final String query;
  final String summary;
  final List<String> keyFacts;
  final List<String> newsHeadlines;
  final List<Map<String, String>> sources;
  final String engineUsed;

  const WebSearchResult({
    required this.query,
    required this.summary,
    this.keyFacts = const [],
    this.newsHeadlines = const [],
    this.sources = const [],
    required this.engineUsed,
  });

  Map<String, Object?> toJson() => {
        'query': query,
        'summary': summary,
        'keyFacts': keyFacts,
        'newsHeadlines': newsHeadlines,
        'sources': sources,
        'engineUsed': engineUsed,
      };

  /// Formats a clean note suitable for writing into external note/document apps.
  String toNoteDocument() {
    final sb = StringBuffer();
    sb.writeln('🌐 OmniPilot Google & Web Research: $query');
    sb.writeln('══════════════════════════════════════');
    sb.writeln();
    sb.writeln('📌 Overview:');
    sb.writeln(summary);
    if (keyFacts.isNotEmpty) {
      sb.writeln();
      sb.writeln('🔑 Key Facts & Insights:');
      for (final fact in keyFacts.take(5)) {
        sb.writeln('• $fact');
      }
    }
    if (newsHeadlines.isNotEmpty) {
      sb.writeln();
      sb.writeln('📰 Latest Google News Headlines:');
      for (final headline in newsHeadlines.take(4)) {
        sb.writeln('• $headline');
      }
    }
    if (sources.isNotEmpty) {
      sb.writeln();
      sb.writeln('🔗 Sources:');
      for (final src in sources.take(4)) {
        sb.writeln('• ${src['title'] ?? 'Source'}: ${src['url'] ?? ''}');
      }
    }
    sb.writeln();
    sb.writeln('— Researched & verified by OmniPilot AI ($engineUsed)');
    return sb.toString().trim();
  }

  /// Formats a rich markdown response for the in-app OmniPilot Assistant chat.
  String toMarkdownReport() {
    final sb = StringBuffer();
    sb.writeln('🌐 **OmniPilot Google & Web Search: "$query"**');
    sb.writeln('_Engine: $engineUsed\n_');
    sb.writeln(summary);
    if (keyFacts.isNotEmpty) {
      sb.writeln('\n**🔑 Key Insights:**');
      for (final fact in keyFacts.take(5)) {
        sb.writeln('• $fact');
      }
    }
    if (newsHeadlines.isNotEmpty) {
      sb.writeln('\n**📰 Live Google News Headlines:**');
      for (final headline in newsHeadlines.take(4)) {
        sb.writeln('• $headline');
      }
    }
    if (sources.isNotEmpty) {
      sb.writeln('\n**🔗 Grounded Web Sources:**');
      for (final src in sources.take(4)) {
        final title = src['title'] ?? 'Web Source';
        final url = src['url'] ?? '';
        sb.writeln('• $title — $url');
      }
    }
    return sb.toString().trim();
  }
}

