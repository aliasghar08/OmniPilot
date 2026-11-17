import 'package:flutter/material.dart';
import '../../assistant/assistant.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import 'widgets/widgets.dart';

/// Main screen of OmniPilot composing the Cross-App Copilot Controls,
/// AI Assistant Chat Console, and Developer Info.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Assistant Chat State
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final List<ChatMessageModel> _messages = [];
  final AssistantController _assistant = AssistantController();
  bool _isProcessing = false;
  late TabController _tabController;

  // Background / Accessibility / Floating Bubble Status
  bool _isA11yEnabled = false;
  bool _isA11ySettingOn = false;
  bool _canDrawOverlays = false;
  bool _isBubbleRunning = false;
  String _activeExternalPackage = '';
  List<Map<String, dynamic>> _lastInspectedFields = [];
  List<Map<String, dynamic>> _lastClickableElements = [];
  List<String> _lastScreenTexts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);

    AccessibilityBridge.ensureHandlerRegistered();
    AccessibilityBridge.onSystemPermissionsUpdated = (_) {
      if (mounted) {
        _checkPermissions();
      }
    };

    AppSettingsService.instance.init();
    _checkPermissions();

    _assistant.initializeAssistant(
      onFill: (_) {},
      onRecordSaved: (_) {},
    );

    AccessibilityBridge.onBotFeedbackReceived = (String feedback) {
      if (!mounted || feedback.isEmpty) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(feedback),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
    };

    _messages.add(
      ChatMessageModel(
        sender: 'assistant',
        text: AppConstants.welcomeMessage,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final a11yStatus = await AccessibilityBridge.getAccessibilityStatus();
    final overlays = await AccessibilityBridge.canDrawOverlays();
    final bubble = await AccessibilityBridge.isFloatingBubbleRunning();
    if (mounted) {
      setState(() {
        _isA11yEnabled = a11yStatus['isBound'] ?? false;
        _isA11ySettingOn = a11yStatus['isSettingEnabled'] ?? false;
        _canDrawOverlays = overlays;
        _isBubbleRunning = bubble;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatInputController.dispose();
    _chatScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = presetText ?? _chatInputController.text.trim();
    if (text.isEmpty || _isProcessing) return;

    setState(() {
      _messages.add(ChatMessageModel(sender: 'user', text: text));
      if (presetText == null) _chatInputController.clear();
      _isProcessing = true;
    });

    _scrollToBottom();

    String reply = '✅ Command processed.';
    try {
      reply = await _assistant.handleUserMessage(text);
    } catch (_) {
      reply = '❌ Bot Error: Something went wrong.';
    } finally {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessageModel(sender: 'assistant', text: reply));
          _isProcessing = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleFloatingBubble() async {
    if (!_isBubbleRunning) {
      final permitted = await AccessibilityBridge.ensureSystemPermissions(
        context,
        scope: 'floating_bubble',
      );
      if (!permitted) return;
    }

    if (_isBubbleRunning) {
      await AccessibilityBridge.stopFloatingBubble();
    } else {
      await AccessibilityBridge.startFloatingBubble();
    }
    await _checkPermissions();
  }

  Future<void> _inspectCurrentScreen({bool switchToExternal = false}) async {
    await _checkPermissions();
    try {
      final snapshot = await AccessibilityBridge.getScreenSnapshot(
        preferExternal: true,
        switchToExternal: switchToExternal,
      );
      final fields = ((snapshot['editableFields'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final clickables = ((snapshot['clickableElements'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final texts = ((snapshot['screenTexts'] as List?) ?? [])
          .map((e) => e.toString())
          .toList();
      final pkg = snapshot['activePackage']?.toString() ?? '';
      final lastExt = snapshot['lastExternalPackage']?.toString() ?? '';

      setState(() {
        _activeExternalPackage = pkg.isNotEmpty ? pkg : lastExt;
        _lastInspectedFields = fields;
        _lastClickableElements = clickables;
        _lastScreenTexts = texts;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Inspected ${pkg.isNotEmpty ? pkg : "window"}: ${fields.length} field(s), ${clickables.length} control(s)',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Inspection note: $e')),
        );
      }
    }
  }

  Widget _buildChatConsoleWidget() {
    return AssistantChatConsole(
      promptSuggestions: AppConstants.defaultPromptSuggestions,
      messages: _messages,
      scrollController: _chatScrollController,
      inputController: _chatInputController,
      isProcessing: _isProcessing,
      onSelectSuggestion: (prompt) {
        _sendMessage(prompt);
      },
      onSendMessage: _sendMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        return Scaffold(
          appBar: OmniPilotAppBar(
            isWide: isWide,
            tabController: _tabController,
            onRefreshPermissions: _checkPermissions,
          ),
          body: isWide ? _buildDesktopLayout() : _buildMobileLayout(),
        );
      },
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 6,
          child: Container(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CrossAppControllerCard(
                    activeExternalPackage: _activeExternalPackage,
                    isA11yEnabled: _isA11yEnabled,
                    isA11ySettingOn: _isA11ySettingOn,
                    canDrawOverlays: _canDrawOverlays,
                    isBubbleRunning: _isBubbleRunning,
                    onToggleBubble: _toggleFloatingBubble,
                    onRequestOverlay: () => AccessibilityBridge.requestOverlayPermission(),
                    onOpenAppInfo: () => AccessibilityBridge.openAppInfoSettings(),
                    onRequestIgnoreBattery: () =>
                        AccessibilityBridge.requestIgnoreBatteryOptimizations(),
                    onInspectScreen: (switchToExt) =>
                        _inspectCurrentScreen(switchToExternal: switchToExt),
                  ),
                  const SizedBox(height: 16),
                  const InAppCustomizationCard(),
                  const SizedBox(height: 16),
                  DiscoveredFieldsCard(
                    lastInspectedFields: _lastInspectedFields,
                    lastClickableElements: _lastClickableElements,
                    lastScreenTexts: _lastScreenTexts,
                  ),
                  const SizedBox(height: 16),
                  const DeveloperInfoTab(),
                ],
              ),
            ),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          flex: 5,
          child: _buildChatConsoleWidget(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return TabBarView(
      controller: _tabController,
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CrossAppControllerCard(
                activeExternalPackage: _activeExternalPackage,
                isA11yEnabled: _isA11yEnabled,
                isA11ySettingOn: _isA11ySettingOn,
                canDrawOverlays: _canDrawOverlays,
                isBubbleRunning: _isBubbleRunning,
                onToggleBubble: _toggleFloatingBubble,
                onRequestOverlay: () => AccessibilityBridge.requestOverlayPermission(),
                onOpenAppInfo: () => AccessibilityBridge.openAppInfoSettings(),
                onRequestIgnoreBattery: () =>
                    AccessibilityBridge.requestIgnoreBatteryOptimizations(),
                onInspectScreen: (switchToExt) =>
                    _inspectCurrentScreen(switchToExternal: switchToExt),
              ),
              const SizedBox(height: 16),
              const InAppCustomizationCard(),
              const SizedBox(height: 16),
              DiscoveredFieldsCard(
                lastInspectedFields: _lastInspectedFields,
                lastClickableElements: _lastClickableElements,
                lastScreenTexts: _lastScreenTexts,
              ),
            ],
          ),
        ),
        _buildChatConsoleWidget(),
        const DeveloperInfoTab(),
      ],
    );
  }
}
