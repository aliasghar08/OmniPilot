import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../assistant/assistant.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import 'widgets/widgets.dart';

/// Main screen of OmniPilot composing the Cross-App Controller, Period Attendance Form,
/// Saved Period Records, and Wide-Purpose AI Assistant Console.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // --- Complex Period Attendance Form Controllers & State ---
  final TextEditingController _nameController = TextEditingController(text: 'Ali Asghar');
  final TextEditingController _rollController = TextEditingController(text: 'CS-2026-012');
  final TextEditingController _startDateController = TextEditingController(text: '2026-10-01');
  final TextEditingController _endDateController = TextEditingController(text: '2026-10-31');
  final TextEditingController _workingDaysController = TextEditingController(text: '24');
  final TextEditingController _daysPresentController = TextEditingController(text: '22');
  final TextEditingController _approvedLeavesController = TextEditingController(text: '1');
  final TextEditingController _absentDaysController = TextEditingController(text: '1');
  final TextEditingController _lateArrivalsController = TextEditingController(text: '1');
  final TextEditingController _remarksController = TextEditingController(
    text: 'Consistent attendance throughout October; 1 day excused medical leave verified.',
  );

  String _selectedPeriodType = AppConstants.periodTypeOptions.first;
  String _selectedDepartment = AppConstants.departmentOptions.first;
  String _selectedSection = AppConstants.sectionOptions.first;

  String _selectedStanding = AppConstants.standingOptions.first;
  String _selectedTrend = 'Consistent';

  bool _medicalCertSubmitted = true;
  bool _parentNotified = false;
  bool _examEligible = true;
  bool _makeupRequired = false;

  bool _verifiedByAdvisor = true;
  double _participationScore = 94.0;

  // Local Saved Period Records History
  final List<Map<String, dynamic>> _localSavedRecords = [];

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
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);

    AppSettingsService.instance.init();
    _checkPermissions();

    for (final c in [
      _workingDaysController,
      _daysPresentController,
      _approvedLeavesController,
      _absentDaysController,
      _lateArrivalsController,
    ]) {
      c.addListener(() {
        if (mounted) setState(() {});
      });
    }

    _assistant.initializeAssistant(
      onFill: _applyComplexFormFill,
      onRecordSaved: (record) {
        setState(() {
          _localSavedRecords.insert(0, record);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('💾 Saved period record for ${record['student_name'] ?? record['class_id']}'),
            backgroundColor: Colors.teal.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );

    _messages.add(
      ChatMessageModel(
        sender: 'assistant',
        text: AppConstants.welcomeMessage,
      ),
    );
  }

  void _resetPeriodForm() {
    setState(() {
      _nameController.clear();
      _rollController.clear();
      _workingDaysController.text = '24';
      _daysPresentController.text = '0';
      _approvedLeavesController.text = '0';
      _absentDaysController.text = '0';
      _lateArrivalsController.text = '0';
      _remarksController.clear();
      _selectedStanding = 'Good Standing';
      _selectedTrend = 'Consistent';
      _medicalCertSubmitted = false;
      _parentNotified = false;
      _examEligible = true;
      _makeupRequired = false;
      _verifiedByAdvisor = false;
      _participationScore = 80.0;
    });
  }

  void _applyComplexFormFill(Map<String, dynamic> data) {
    setState(() {
      if (data['studentName'] != null) _nameController.text = data['studentName'].toString();
      if (data['rollNo'] != null) _rollController.text = data['rollNo'].toString();
      if (data['startDate'] != null) _startDateController.text = data['startDate'].toString();
      if (data['endDate'] != null) _endDateController.text = data['endDate'].toString();
      if (data['totalWorkingDays'] != null) {
        _workingDaysController.text = data['totalWorkingDays'].toString();
      }
      if (data['daysPresent'] != null) {
        _daysPresentController.text = data['daysPresent'].toString();
      }
      if (data['approvedLeaveDays'] != null) {
        _approvedLeavesController.text = data['approvedLeaveDays'].toString();
      }
      if (data['unexcusedAbsentDays'] != null) {
        _absentDaysController.text = data['unexcusedAbsentDays'].toString();
      }
      if (data['lateArrivalsCount'] != null) {
        _lateArrivalsController.text = data['lateArrivalsCount'].toString();
      }
      if (data['advisorRemarks'] != null) {
        _remarksController.text = data['advisorRemarks'].toString();
      }

      if (data['periodType'] != null) {
        final pt = data['periodType'].toString();
        _selectedPeriodType = AppConstants.periodTypeOptions.firstWhere(
          (o) => o.toLowerCase().contains(pt.toLowerCase()) || pt.toLowerCase().contains(o.toLowerCase()),
          orElse: () => _selectedPeriodType,
        );
      }
      if (data['department'] != null || data['classGrade'] != null) {
        final dept = (data['department'] ?? data['classGrade']).toString();
        _selectedDepartment = AppConstants.departmentOptions.firstWhere(
          (o) => o.toLowerCase().contains(dept.toLowerCase()) || dept.toLowerCase().contains(o.toLowerCase()),
          orElse: () => _selectedDepartment,
        );
      }
      if (data['section'] != null) {
        final sec = data['section'].toString();
        _selectedSection = AppConstants.sectionOptions.firstWhere(
          (o) => o.toLowerCase().contains(sec.toLowerCase()) || sec.toLowerCase().contains(o.toLowerCase()),
          orElse: () => _selectedSection,
        );
      }

      if (data['attendanceStanding'] != null || data['status'] != null) {
        final st = (data['attendanceStanding'] ?? data['status']).toString();
        _selectedStanding = AppConstants.standingOptions.firstWhere(
          (o) => o.toLowerCase().contains(st.toLowerCase()) || st.toLowerCase().contains(o.toLowerCase()),
          orElse: () => _selectedStanding,
        );
      }
      if (data['attendanceTrend'] != null) {
        final tr = data['attendanceTrend'].toString();
        _selectedTrend = AppConstants.trendOptions.firstWhere(
          (o) => o.toLowerCase().contains(tr.toLowerCase()),
          orElse: () => _selectedTrend,
        );
      }

      if (data['medicalCertSubmitted'] is bool) {
        _medicalCertSubmitted = data['medicalCertSubmitted'] as bool;
      }
      if (data['parentNotified'] is bool) {
        _parentNotified = data['parentNotified'] as bool;
      }
      if (data['examEligible'] is bool) {
        _examEligible = data['examEligible'] as bool;
      }
      if (data['makeupRequired'] is bool) {
        _makeupRequired = data['makeupRequired'] as bool;
      }

      if (data['verifiedByAdvisor'] is bool) {
        _verifiedByAdvisor = data['verifiedByAdvisor'] as bool;
      }
      if (data['participationScore'] is num) {
        _participationScore = (data['participationScore'] as num).toDouble().clamp(0.0, 100.0);
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✨ AI populated Period Form for ${_nameController.text} ($_selectedPeriodType • $_selectedStanding)',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.indigo.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  PeriodAttendanceModel get _currentFormModel {
    return PeriodAttendanceModel(
      studentName: _nameController.text.trim(),
      rollNo: _rollController.text.trim(),
      periodType: _selectedPeriodType,
      department: _selectedDepartment,
      section: _selectedSection,
      startDate: _startDateController.text.trim(),
      endDate: _endDateController.text.trim(),
      totalWorkingDays: int.tryParse(_workingDaysController.text.trim()) ?? 0,
      daysPresent: int.tryParse(_daysPresentController.text.trim()) ?? 0,
      approvedLeaveDays: int.tryParse(_approvedLeavesController.text.trim()) ?? 0,
      unexcusedAbsentDays: int.tryParse(_absentDaysController.text.trim()) ?? 0,
      lateArrivalsCount: int.tryParse(_lateArrivalsController.text.trim()) ?? 0,
      standing: _selectedStanding,
      trend: _selectedTrend,
      medicalCertSubmitted: _medicalCertSubmitted,
      parentNotified: _parentNotified,
      examEligible: _examEligible,
      makeupRequired: _makeupRequired,
      verifiedByAdvisor: _verifiedByAdvisor,
      participationScore: _participationScore,
      advisorRemarks: _remarksController.text.trim(),
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
    _nameController.dispose();
    _rollController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _workingDaysController.dispose();
    _daysPresentController.dispose();
    _approvedLeavesController.dispose();
    _absentDaysController.dispose();
    _lateArrivalsController.dispose();
    _remarksController.dispose();
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

    final reply = await _assistant.handleUserMessage(text);

    setState(() {
      _messages.add(ChatMessageModel(sender: 'assistant', text: reply));
      _isProcessing = false;
    });

    _scrollToBottom();
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

  Future<void> _manualSaveRecord() async {
    final model = _currentFormModel;
    if (model.studentName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in student name first')),
      );
      return;
    }

    final recordMap = model.toFirestoreMap();

    setState(() {
      _localSavedRecords.insert(0, recordMap);
    });

    try {
      await FirebaseFirestore.instance.collection('attendance_logs').add({
        ...recordMap,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Period Record Saved for ${model.studentName} (${recordMap['percentage']}% • $_selectedStanding)',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Saved locally for ${model.studentName} (${recordMap['percentage']}% • $_selectedStanding)',
            ),
            backgroundColor: Colors.indigo.shade700,
          ),
        );
      }
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = DateTime.tryParse(controller.text.trim()) ?? DateTime(2026, 10, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2030, 12, 31),
    );
    if (picked != null) {
      final formatted =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {
        controller.text = formatted;
      });
    }
  }

  Future<void> _toggleFloatingBubble() async {
    if (!_canDrawOverlays) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please grant "Display over other apps" permission to show the floating assistant.'),
            backgroundColor: Colors.amber,
          ),
        );
      }
      await AccessibilityBridge.requestOverlayPermission();
      return;
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

  Widget _buildPeriodFormCard() {
    final model = _currentFormModel;
    return PeriodAttendanceFormCard(
      nameController: _nameController,
      rollController: _rollController,
      startDateController: _startDateController,
      endDateController: _endDateController,
      workingDaysController: _workingDaysController,
      daysPresentController: _daysPresentController,
      approvedLeavesController: _approvedLeavesController,
      absentDaysController: _absentDaysController,
      lateArrivalsController: _lateArrivalsController,
      remarksController: _remarksController,
      selectedPeriodType: _selectedPeriodType,
      selectedDepartment: _selectedDepartment,
      selectedSection: _selectedSection,
      selectedStanding: _selectedStanding,
      selectedTrend: _selectedTrend,
      medicalCertSubmitted: _medicalCertSubmitted,
      parentNotified: _parentNotified,
      examEligible: _examEligible,
      makeupRequired: _makeupRequired,
      verifiedByAdvisor: _verifiedByAdvisor,
      participationScore: _participationScore,
      effectivePercentage: model.effectivePercentage,
      rawPercentage: model.rawPercentage,
      onReset: _resetPeriodForm,
      onApplyAiScenario: _applyComplexFormFill,
      onPeriodTypeChanged: (val) => setState(() => _selectedPeriodType = val),
      onDepartmentChanged: (val) => setState(() => _selectedDepartment = val),
      onSectionChanged: (val) => setState(() => _selectedSection = val),
      onPickDate: _pickDate,
      onStandingChanged: (val) => setState(() => _selectedStanding = val),
      onTrendChanged: (val) => setState(() => _selectedTrend = val),
      onMedicalCertChanged: (val) => setState(() => _medicalCertSubmitted = val),
      onParentNotifiedChanged: (val) => setState(() => _parentNotified = val),
      onExamEligibleChanged: (val) => setState(() => _examEligible = val),
      onMakeupRequiredChanged: (val) => setState(() => _makeupRequired = val),
      onParticipationScoreChanged: (val) => setState(() => _participationScore = val),
      onVerifiedByAdvisorChanged: (val) => setState(() => _verifiedByAdvisor = val),
      onSaveRecord: _manualSaveRecord,
    );
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
        if (prompt.toLowerCase().contains('period attendance')) {
          _tabController.animateTo(1);
        }
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
                  _buildPeriodFormCard(),
                  const SizedBox(height: 24),
                  SavedPeriodRecordsCard(localSavedRecords: _localSavedRecords),
                  const SizedBox(height: 24),
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
        SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPeriodFormCard(),
              const SizedBox(height: 20),
              SavedPeriodRecordsCard(localSavedRecords: _localSavedRecords),
            ],
          ),
        ),
        _buildChatConsoleWidget(),
      ],
    );
  }
}
