import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/features/laptop/data/laptop_control_service.dart';
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class LaptopControlScreen extends StatefulWidget {
  const LaptopControlScreen({super.key});

  @override
  State<LaptopControlScreen> createState() => _LaptopControlScreenState();
}

class _LaptopControlScreenState extends State<LaptopControlScreen>
    with SingleTickerProviderStateMixin {
  final _service = LaptopControlService();
  late TabController _tabController;

  bool _connected = false;
  bool _connecting = false;
  Map<String, dynamic>? _systemInfo;
  Uint8List? _screenshot;
  bool _takingScreenshot = false;

  // Trackpad
  Offset _lastPos = Offset.zero;
  final double _sensitivity = 2.2;

  // Keyboard
  final _textController = TextEditingController();

  // Terminal
  final _terminalController = TextEditingController();
  final _terminalOutputController = TextEditingController();

  // AI Agent Tab
  final _aiAgentInputController = TextEditingController();
  final List<Map<String, dynamic>> _aiAgentMessages = [];
  bool _isAiAgentExecuting = false;

  // Live Desktop AIRA Voice & Vision State
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _speechEnabled = false;
  bool _isListeningLive = false;
  String _liveVoiceCommand = '';
  bool _isExecutingLiveCommand = false;
  String? _lastLiveActionMessage;
  final _liveCommandTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _initSpeechAndTts();
    _service.loadConfig().then((_) {
      if (_service.isConfigured) {
        _testConnection();
      }
    });
  }

  void _initSpeechAndTts() async {
    try {
      _speechEnabled = await _speech.initialize();
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
    } catch (_) {}
  }

  @override
  void dispose() {
    _service.disconnectWebSocket();
    _speech.stop();
    _tts.stop();
    _liveCommandTextController.dispose();
    _tabController.dispose();
    _textController.dispose();
    _terminalController.dispose();
    _terminalOutputController.dispose();
    _aiAgentInputController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() => _connecting = true);
    final result = await _service.testConnection();
    final connected = result['success'] == true;

    if (connected) {
      final info = await _service.getInfo();
      setState(() {
        _connected = true;
        _connecting = false;
        _systemInfo = info['data'];
      });
    } else {
      setState(() {
        _connected = false;
        _connecting = false;
      });
      if (mounted) {
        _showSnackBar('❌ ${result['error'] ?? "Cannot connect to laptop"}', isError: true);
      }
    }
  }

  Future<void> _takeScreenshot() async {
    HapticFeedback.lightImpact();
    setState(() => _takingScreenshot = true);
    final bytes = await _service.captureScreenshot();
    setState(() {
      _screenshot = bytes;
      _takingScreenshot = false;
    });
    if (bytes == null) {
      _showSnackBar('❌ Could not capture screenshot.', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.sourceSerif4(fontSize: 13)),
        backgroundColor: isError ? Colors.red.shade700 : AiraColors.claudeTerracotta,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _fetchStats() async {
    final stats = await _service.getSystemStats();
    setState(() => _systemInfo = {...?_systemInfo, ...stats});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: theme.colorScheme.onSurface, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Laptop Remote',
              style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _connected ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  _connecting
                      ? 'Connecting...'
                      : (_connected
                          ? (_service.hostname ?? _systemInfo?['hostname'] as String? ?? 'Connected')
                          : 'Not Connected'),
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 11.5,
                    color: _connected ? Colors.green : Colors.red.shade400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_connected) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: _service.isPaired
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _service.isPaired ? Colors.green : Colors.amber,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _service.isPaired ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                          size: 9,
                          color: _service.isPaired ? Colors.green : Colors.amber,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          _service.isPaired ? 'PAIRED' : 'PIN AUTH',
                          style: GoogleFonts.firaCode(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: _service.isPaired ? Colors.green : Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          if (_connected)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.mic_rounded, size: 14, color: Colors.white),
                label: Text(
                  'Live Desktop AIRA',
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E8E3E),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                ),
                onPressed: _openLiveDesktopAiraModal,
              ),
            ),
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: AiraColors.claudeTerracotta, size: 20),
            onPressed: _testConnection,
            tooltip: 'Reconnect',
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined,
                color: theme.colorScheme.onSurface, size: 20),
            onPressed: _showConnectDialog,
            tooltip: 'Pairing & Settings',
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AiraColors.claudeTerracotta,
          unselectedLabelColor:
              isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
          indicatorColor: AiraColors.claudeTerracotta,
          indicatorWeight: 2.5,
          labelStyle: GoogleFonts.sourceSerif4(
              fontSize: 12, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              GoogleFonts.sourceSerif4(fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.psychology_rounded, size: 18), text: 'AI Agent'),
            Tab(icon: Icon(Icons.touch_app_rounded, size: 18), text: 'Trackpad'),
            Tab(icon: Icon(Icons.screenshot_monitor_rounded, size: 18), text: 'Screen'),
            Tab(icon: Icon(Icons.terminal_rounded, size: 18), text: 'Terminal'),
            Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'Controls'),
            Tab(icon: Icon(Icons.security_rounded, size: 18), text: 'Bridge'),
          ],
        ),
      ),
      body: !_connected
          ? _buildNotConnectedView(theme, isDark)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAiAgentTab(theme, isDark),
                _buildTrackpadTab(theme, isDark),
                _buildScreenTab(theme, isDark),
                _buildTerminalTab(theme, isDark),
                _buildControlsTab(theme, isDark),
                _buildDeviceBridgeTab(theme, isDark),
              ],
            ),
    );
  }

  // ── Not Connected View ─────────────────────────────────────────────────

  Widget _buildNotConnectedView(ThemeData theme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.laptop_outlined,
                size: 72, color: AiraColors.claudeTerracotta),
            const SizedBox(height: 20),
            Text(
              'Connect Your Laptop',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Run AIRA Desktop Agent on your laptop, then enter its IP address and PIN below to connect.',
              textAlign: TextAlign.center,
              style: GoogleFonts.sourceSerif4(
                fontSize: 14,
                color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            _buildSetupSteps(isDark),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _connecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.link_rounded, color: Colors.white),
                label: Text(
                  _connecting ? 'Connecting...' : 'Connect Laptop',
                  style: GoogleFonts.sourceSerif4(
                      fontWeight: FontWeight.w700, color: Colors.white),
                ),
                onPressed: _connecting ? null : _showConnectDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AiraColors.claudeTerracotta,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupSteps(bool isDark) {
    final steps = [
      ('1', 'Download & run start_aira_desktop.bat on your laptop'),
      ('2', 'Note the IP address shown (e.g. 192.168.1.x)'),
      ('3', 'Enter IP and PIN (default: 123456) here'),
    ];
    final mutedColor = isDark ? AiraColors.textMuted : AiraColors.textMutedLight;

    return Column(
      children: steps.map((s) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: AiraColors.claudeTerracotta),
                child: Center(
                  child: Text(s.$1,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(s.$2,
                    style: GoogleFonts.sourceSerif4(
                        fontSize: 13, color: mutedColor)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── AI Agent Tab (Autonomous Multi-Step Laptop Brain) ────────────────

  Widget _buildAiAgentTab(ThemeData theme, bool isDark) {
    final cardBg = isDark ? AiraColors.cardDark : AiraColors.cardLight;
    final borderColor = isDark ? AiraColors.borderDark : AiraColors.borderLight;

    return Column(
      children: [
        // Quick Action Suggestion Chips
        Container(
          height: 44,
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              _buildSuggestionChip('▶️ Play Hanuman Chalisa on YouTube', isDark),
              _buildSuggestionChip('🔍 Search React documentation in Chrome', isDark),
              _buildSuggestionChip('📝 Create note on Desktop: Roadmap', isDark),
              _buildSuggestionChip('📸 Screenshot and check screen', isDark),
              _buildSuggestionChip('📁 Organize Downloads folder', isDark),
              _buildSuggestionChip('🔒 Lock laptop & sleep', isDark),
            ],
          ),
        ),

        // Message & Action Execution Log
        Expanded(
          child: _aiAgentMessages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AiraColors.claudeTerracotta.withValues(alpha: isDark ? 0.18 : 0.1),
                          ),
                          child: const Icon(
                            Icons.psychology_rounded,
                            size: 42,
                            color: AiraColors.claudeTerracotta,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Autonomous Laptop AI',
                          style: GoogleFonts.playfairDisplay(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tell AIRA any complex goal. The AI will reason, call tools, and execute multi-step actions on your laptop.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.sourceSerif4(
                            fontSize: 13,
                            color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  itemCount: _aiAgentMessages.length,
                  itemBuilder: (context, idx) {
                    final msg = _aiAgentMessages[idx];
                    final isUser = msg['role'] == 'user';
                    final steps = (msg['steps'] as List?) ?? [];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment:
                            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? AiraColors.claudeTerracotta
                                  : (isDark ? AiraColors.cardDark : AiraColors.cardLight),
                              borderRadius: BorderRadius.circular(16),
                              border: isUser
                                  ? null
                                  : Border.all(color: borderColor),
                            ),
                            child: Text(
                              msg['content'] as String,
                              style: GoogleFonts.sourceSerif4(
                                fontSize: 13.5,
                                color: isUser ? Colors.white : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (!isUser && steps.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF141310) : const Color(0xFFFAF9F5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ACTION PLAN EXECUTION (${steps.length} STEPS)',
                                    style: GoogleFonts.firaCode(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                      color: AiraColors.claudeTerracotta,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...steps.map((st) {
                                    final stepMap = st as Map;
                                    final status = stepMap['status'] ?? 'completed';
                                    final desc = stepMap['description'] ?? '';
                                    final output = stepMap['output'] ?? '';
                                    final isOk = status == 'completed';

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(isOk ? '✅' : '❌', style: const TextStyle(fontSize: 13)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  desc,
                                                  style: GoogleFonts.sourceSerif4(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: theme.colorScheme.onSurface,
                                                  ),
                                                ),
                                                if (output.toString().isNotEmpty)
                                                  Text(
                                                    output.toString(),
                                                    style: GoogleFonts.firaCode(
                                                      fontSize: 11,
                                                      color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Thinking Indicator
        if (_isAiAgentExecuting)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AiraColors.claudeTerracotta.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AiraColors.claudeTerracotta.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AiraColors.claudeTerracotta),
                ),
                const SizedBox(width: 10),
                Text(
                  '🧠 Reasoning & calling tools on laptop...',
                  style: GoogleFonts.sourceSerif4(fontSize: 12.5, color: AiraColors.claudeTerracotta, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

        // Bottom Input Bar
        Container(
          padding: EdgeInsets.fromLTRB(14, 8, 14, MediaQuery.of(context).padding.bottom + 8),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: borderColor, width: 0.8)),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _aiAgentInputController,
                    style: GoogleFonts.sourceSerif4(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Tell laptop AI what to do...',
                      hintStyle: GoogleFonts.sourceSerif4(
                        fontSize: 13.5,
                        color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onSubmitted: _sendAiAgentTask,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: AiraColors.claudeTerracotta,
                    padding: const EdgeInsets.all(8),
                  ),
                  onPressed: () => _sendAiAgentTask(_aiAgentInputController.text),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionChip(String label, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: GoogleFonts.sourceSerif4(fontSize: 11.5)),
        backgroundColor: isDark ? AiraColors.cardDark : AiraColors.cardLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _sendAiAgentTask(label.substring(3).trim()),
      ),
    );
  }

  Future<void> _sendAiAgentTask(String prompt) async {
    final text = prompt.trim();
    if (text.isEmpty || _isAiAgentExecuting) return;

    _aiAgentInputController.clear();
    setState(() {
      _aiAgentMessages.add({
        'role': 'user',
        'content': text,
        'time': DateTime.now(),
      });
      _isAiAgentExecuting = true;
    });

    try {
      final result = await _service.executeAgentTask(text);
      final success = result['success'] == true;
      final results = (result['results'] as List?) ?? [];
      final message = result['message'] ?? (success ? 'Task executed successfully on laptop' : 'Some steps encountered issues');

      setState(() {
        _isAiAgentExecuting = false;
        _aiAgentMessages.add({
          'role': 'assistant',
          'content': message,
          'success': success,
          'steps': results,
          'time': DateTime.now(),
        });
      });
    } catch (e) {
      setState(() {
        _isAiAgentExecuting = false;
        _aiAgentMessages.add({
          'role': 'assistant',
          'content': 'Error executing task on laptop: $e',
          'success': false,
          'time': DateTime.now(),
        });
      });
    }
  }

  // ── Trackpad Tab (Fixed Full-Height Ergonomic Layout) ─────────────────

  Widget _buildTrackpadTab(ThemeData theme, bool isDark) {
    final cardBg = isDark ? AiraColors.cardDark : AiraColors.cardLight;
    final borderColor = isDark ? AiraColors.borderDark : AiraColors.borderLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        children: [
          // Trackpad Surface (Full Height Expanded, Zero Scrolling Conflict)
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF181714) : const Color(0xFFF6F4EE),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AiraColors.claudeTerracotta.withValues(alpha: 0.4), width: 1.2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Main Touch Area
                    Positioned.fill(
                      right: 48,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (details) {
                          _lastPos = details.localPosition;
                        },
                        onPanUpdate: (details) {
                          final current = details.localPosition;
                          final dx = ((current.dx - _lastPos.dx) * _sensitivity).toInt();
                          final dy = ((current.dy - _lastPos.dy) * _sensitivity).toInt();
                          if (dx != 0 || dy != 0) {
                            _service.moveMouse(dx, dy);
                            _lastPos = current;
                          }
                        },
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _service.leftClick();
                        },
                        onDoubleTap: () {
                          HapticFeedback.mediumImpact();
                          _service.doubleClick();
                        },
                        onLongPress: () {
                          HapticFeedback.heavyImpact();
                          _service.rightClick();
                        },
                        onSecondaryTap: () {
                          HapticFeedback.heavyImpact();
                          _service.rightClick();
                        },
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.touch_app_rounded,
                                size: 48,
                                color: AiraColors.claudeTerracotta.withValues(alpha: 0.35),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Trackpad Surface',
                                style: GoogleFonts.sourceSerif4(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Swipe = Move • Tap = Left Click\nDouble Tap = Open • Hold = Right Click',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.sourceSerif4(
                                  fontSize: 12,
                                  color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Dedicated Right-Side Scroll Strip (Hardware style)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: 0,
                      width: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04)),
                          border: Border(left: BorderSide(color: borderColor, width: 0.8)),
                        ),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: (details) {
                            if (details.delta.dy < -2) {
                              _service.scroll(2);
                            } else if (details.delta.dy > 2) {
                              _service.scroll(-2);
                            }
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_drop_up_rounded, color: AiraColors.claudeTerracotta, size: 24),
                              RotatedBox(
                                quarterTurns: 1,
                                child: Text(
                                  'SCROLL',
                                  style: GoogleFonts.firaCode(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                    color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                                  ),
                                ),
                              ),
                              Icon(Icons.arrow_drop_down_rounded, color: AiraColors.claudeTerracotta, size: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Docked Mouse Buttons (Left, Right, Double Click, Type)
          Row(
            children: [
              _clickButton('Left Click', Icons.mouse_outlined, () {
                HapticFeedback.lightImpact();
                _service.leftClick();
              }, cardBg, borderColor, theme),
              const SizedBox(width: 8),
              _clickButton('Right Click', Icons.touch_app_outlined, () {
                HapticFeedback.lightImpact();
                _service.rightClick();
              }, cardBg, borderColor, theme),
              const SizedBox(width: 8),
              _clickButton('Double Click', Icons.ads_click_rounded, () {
                HapticFeedback.mediumImpact();
                _service.doubleClick();
              }, cardBg, borderColor, theme),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton('Keyboard', Icons.keyboard_rounded, () {
                  _showKeyboardDialog(theme, isDark);
                }, cardBg, borderColor, theme),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showKeyboardDialog(ThemeData theme, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.keyboard_rounded, color: AiraColors.claudeTerracotta, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Type on Laptop Keyboard',
                  style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    autofocus: true,
                    style: GoogleFonts.sourceSerif4(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter text to type...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        _service.typeText(val.trim());
                        _textController.clear();
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final text = _textController.text.trim();
                    if (text.isNotEmpty) {
                      _service.typeText(text);
                      _textController.clear();
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AiraColors.claudeTerracotta,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Send'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Enter ↵'),
                  onPressed: () => _service.pressKey('enter'),
                ),
                ActionChip(
                  label: const Text('Backspace ⌫'),
                  onPressed: () => _service.pressKey('backspace'),
                ),
                ActionChip(
                  label: const Text('Tab ⇥'),
                  onPressed: () => _service.pressKey('tab'),
                ),
                ActionChip(
                  label: const Text('Space ␣'),
                  onPressed: () => _service.pressKey('space'),
                ),
                ActionChip(
                  label: const Text('Esc ⎋'),
                  onPressed: () => _service.pressKey('escape'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _clickButton(String label, IconData icon, VoidCallback onTap,
      Color cardBg, Color borderColor, ThemeData theme) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AiraColors.claudeTerracotta),
              const SizedBox(height: 2),
              Text(label,
                  style: GoogleFonts.sourceSerif4(
                      fontSize: 10.5, color: theme.colorScheme.onSurface)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback onTap,
      Color cardBg, Color borderColor, ThemeData theme) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AiraColors.claudeTerracotta),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.sourceSerif4(
                    fontSize: 12, color: theme.colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }

  // ── Screen Tab ─────────────────────────────────────────────────────────

  Widget _buildScreenTab(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Screenshot Viewer
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141311) : const Color(0xFFECEBE6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isDark ? AiraColors.borderDark : AiraColors.borderLight),
              ),
              child: _screenshot != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: InteractiveViewer(
                        child: Image.memory(_screenshot!, fit: BoxFit.contain),
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.screenshot_monitor_outlined,
                              size: 60,
                              color: AiraColors.claudeTerracotta.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(
                            'Tap "📸 Capture" to see your laptop screen',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.sourceSerif4(
                              fontSize: 13,
                              color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: _takingScreenshot
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.screenshot_rounded,
                          color: Colors.white, size: 18),
                  label: Text(
                    _takingScreenshot ? 'Capturing...' : '📸 Capture Screen',
                    style: GoogleFonts.sourceSerif4(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  onPressed: _takingScreenshot ? null : _takeScreenshot,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AiraColors.claudeTerracotta,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded,
                    color: AiraColors.claudeTerracotta, size: 18),
                label: Text('Refresh',
                    style: GoogleFonts.sourceSerif4(
                        color: AiraColors.claudeTerracotta)),
                onPressed: _takeScreenshot,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AiraColors.claudeTerracotta),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Terminal Tab ───────────────────────────────────────────────────────

  Widget _buildTerminalTab(ThemeData theme, bool isDark) {
    final suggestions = [
      'python --version',
      'dir',
      'ipconfig',
      'tasklist',
      'pip list',
      'git status',
      'node --version',
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Output
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF141311),
                borderRadius: BorderRadius.circular(14),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _terminalOutputController.text.isEmpty
                      ? '> AIRA Terminal — Safe command execution\n> Type a command below and tap Run.\n'
                      : _terminalOutputController.text,
                  style: GoogleFonts.firaCode(
                    fontSize: 12.5,
                    color: Colors.green.shade300,
                    height: 1.55,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: suggestions.map((cmd) {
              return GestureDetector(
                onTap: () => _terminalController.text = cmd,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AiraColors.surfaceDark : AiraColors.surfaceLightWarm,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isDark ? AiraColors.borderDark : AiraColors.borderLight),
                  ),
                  child: Text(cmd,
                      style: GoogleFonts.firaCode(
                          fontSize: 11,
                          color: AiraColors.claudeTerracotta)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _terminalController,
                  style: GoogleFonts.firaCode(
                      fontSize: 13, color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'python --version',
                    hintStyle: GoogleFonts.firaCode(
                        fontSize: 13,
                        color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight),
                    prefixText: '> ',
                    prefixStyle: GoogleFonts.firaCode(
                        color: AiraColors.claudeTerracotta, fontSize: 13),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1E1D1A)
                        : const Color(0xFFF3F1EC),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onSubmitted: (_) => _runTerminalCommand(),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _runTerminalCommand,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AiraColors.claudeTerracotta,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _runTerminalCommand() async {
    final command = _terminalController.text.trim();
    if (command.isEmpty) return;

    HapticFeedback.lightImpact();
    _terminalController.clear();

    setState(() {
      _terminalOutputController.text += '\n> $command\n';
    });

    final result = await _service.runCommand(command);
    final output = result['stdout'] as String? ?? '';
    final error = result['stderr'] as String? ?? '';
    final errorMsg = result['error'] as String? ?? '';

    setState(() {
      if (output.isNotEmpty) {
        _terminalOutputController.text += output;
      } else if (error.isNotEmpty) {
        _terminalOutputController.text += 'STDERR: $error';
      } else if (errorMsg.isNotEmpty) {
        _terminalOutputController.text += 'ERROR: $errorMsg';
      } else {
        _terminalOutputController.text += '(no output)';
      }
      _terminalOutputController.text += '\n';
    });
  }

  // ── Controls Tab ───────────────────────────────────────────────────────

  Widget _buildControlsTab(ThemeData theme, bool isDark) {
    final cardBg = isDark ? AiraColors.cardDark : AiraColors.cardLight;
    final borderColor = isDark ? AiraColors.borderDark : AiraColors.borderLight;
    final mutedColor = isDark ? AiraColors.textMuted : AiraColors.textMutedLight;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System Stats Card
          if (_systemInfo != null) _buildStatsCard(cardBg, borderColor, mutedColor, theme, isDark),
          const SizedBox(height: 16),

          // Volume Controls
          _sectionHeader('Volume', theme),
          const SizedBox(height: 8),
          Row(
            children: [
              _controlBtn('Vol −', Icons.volume_down_rounded, () {
                HapticFeedback.lightImpact();
                _service.volumeDown();
              }, cardBg, borderColor, theme),
              const SizedBox(width: 8),
              _controlBtn('Mute', Icons.volume_off_rounded, () {
                HapticFeedback.lightImpact();
                _service.muteVolume();
              }, cardBg, borderColor, theme),
              const SizedBox(width: 8),
              _controlBtn('Vol +', Icons.volume_up_rounded, () {
                HapticFeedback.lightImpact();
                _service.volumeUp();
              }, cardBg, borderColor, theme),
            ],
          ),
          const SizedBox(height: 16),

          // Keyboard Shortcuts
          _sectionHeader('Quick Shortcuts', theme),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _shortcutChip('Copy', ['ctrl', 'c'], theme, borderColor, isDark),
              _shortcutChip('Paste', ['ctrl', 'v'], theme, borderColor, isDark),
              _shortcutChip('Cut', ['ctrl', 'x'], theme, borderColor, isDark),
              _shortcutChip('Undo', ['ctrl', 'z'], theme, borderColor, isDark),
              _shortcutChip('Select All', ['ctrl', 'a'], theme, borderColor, isDark),
              _shortcutChip('Save', ['ctrl', 's'], theme, borderColor, isDark),
              _shortcutChip('New Tab', ['ctrl', 't'], theme, borderColor, isDark),
              _shortcutChip('Close Tab', ['ctrl', 'w'], theme, borderColor, isDark),
              _shortcutChip('Task Mgr', ['ctrl', 'shift', 'esc'], theme, borderColor, isDark),
              _shortcutChip('Show Desktop', ['win', 'd'], theme, borderColor, isDark),
              _shortcutChip('Screenshot', ['win', 'shift', 's'], theme, borderColor, isDark),
              _shortcutChip('Alt+F4', ['alt', 'f4'], theme, borderColor, isDark),
            ],
          ),
          const SizedBox(height: 16),

          // Power Controls
          _sectionHeader('Power & Lock', theme),
          const SizedBox(height: 8),
          Row(
            children: [
              _powerBtn('🔒 Lock', Colors.blue.shade400, () {
                HapticFeedback.mediumImpact();
                _service.lockScreen();
                _showSnackBar('🔒 Laptop locked!');
              }, theme),
              const SizedBox(width: 8),
              _powerBtn('😴 Sleep', Colors.purple.shade400, () {
                HapticFeedback.mediumImpact();
                _service.sleepLaptop();
                _showSnackBar('😴 Laptop sleeping...');
              }, theme),
              const SizedBox(width: 8),
              _powerBtn('🔄 Restart', Colors.orange.shade400, () {
                _showPowerConfirmDialog(
                    'Restart Laptop',
                    'Your laptop will restart in 10 seconds.',
                    () => _service.restartLaptop());
              }, theme),
              const SizedBox(width: 8),
              _powerBtn('⏹ Shutdown', Colors.red.shade400, () {
                _showPowerConfirmDialog(
                    'Shutdown Laptop',
                    'Your laptop will shut down in 10 seconds.',
                    () => _service.shutdownLaptop());
              }, theme),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.cancel_outlined,
                color: AiraColors.claudeTerracotta, size: 18),
            label: Text('Cancel Pending Shutdown/Restart',
                style: GoogleFonts.sourceSerif4(
                    color: AiraColors.claudeTerracotta, fontSize: 12.5)),
            onPressed: () {
              _service.cancelShutdown();
              _showSnackBar('✅ Shutdown/restart cancelled.');
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AiraColors.claudeTerracotta),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 24),

          // Refresh Stats
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.refresh_rounded,
                  color: AiraColors.claudeTerracotta),
              label: Text('Refresh System Stats',
                  style: GoogleFonts.sourceSerif4(
                      color: AiraColors.claudeTerracotta)),
              onPressed: _fetchStats,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(Color cardBg, Color borderColor, Color mutedColor,
      ThemeData theme, bool isDark) {
    final cpu = _systemInfo?['cpu_percent']?.toString() ?? '?';
    final ramUsed = _systemInfo?['ram_used_gb']?.toString() ?? '?';
    final ramTotal = _systemInfo?['ram_total_gb']?.toString() ?? '?';
    final battery = _systemInfo?['battery_percent']?.toString() ?? 'N/A';
    final charging = _systemInfo?['is_charging'] == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('CPU', '$cpu%', Icons.memory_rounded, theme, mutedColor),
          _statItem('RAM', '$ramUsed/$ramTotal GB', Icons.storage_rounded, theme, mutedColor),
          _statItem('Battery', '$battery%${charging ? ' ⚡' : ''}',
              Icons.battery_charging_full_rounded, theme, mutedColor),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon,
      ThemeData theme, Color mutedColor) {
    return Column(
      children: [
        Icon(icon, color: AiraColors.claudeTerracotta, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.sourceSerif4(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface)),
        Text(label,
            style: GoogleFonts.sourceSerif4(fontSize: 11, color: mutedColor)),
      ],
    );
  }

  Widget _sectionHeader(String title, ThemeData theme) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.sourceSerif4(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AiraColors.claudeTerracotta,
      ),
    );
  }

  Widget _controlBtn(String label, IconData icon, VoidCallback onTap,
      Color cardBg, Color borderColor, ThemeData theme) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AiraColors.claudeTerracotta),
              const SizedBox(height: 2),
              Text(label,
                  style: GoogleFonts.sourceSerif4(
                      fontSize: 10.5, color: theme.colorScheme.onSurface)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shortcutChip(String label, List<String> keys, ThemeData theme,
      Color borderColor, bool isDark) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        _service.sendHotkey(keys);
        _showSnackBar('⌨️ $label sent to laptop');
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? AiraColors.surfaceDark : AiraColors.surfaceLightWarm,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: GoogleFonts.sourceSerif4(
              fontSize: 12.5, color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _powerBtn(String label, Color color, VoidCallback onTap, ThemeData theme) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.sourceSerif4(
                  fontSize: 10.5, color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  void _showPowerConfirmDialog(String title, String body, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
        content: Text(body, style: GoogleFonts.sourceSerif4()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Confirm',
                style: GoogleFonts.sourceSerif4(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showConnectDialog() {
    final ipController = TextEditingController(text: _service.laptopIp);
    final pinController = TextEditingController(text: _service.laptopPin);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: AiraColors.claudeTerracotta, size: 22),
            const SizedBox(width: 8),
            Text(
              'Pair Laptop Bridge',
              style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pair phone with your laptop agent via 6-digit one-time code or PIN.',
                style: GoogleFonts.sourceSerif4(
                  fontSize: 12.5,
                  color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ipController,
                decoration: InputDecoration(
                  labelText: 'Laptop IP Address',
                  hintText: '192.168.1.100',
                  prefixIcon: const Icon(Icons.wifi_rounded, size: 18),
                  labelStyle: GoogleFonts.sourceSerif4(),
                  hintStyle: GoogleFonts.sourceSerif4(),
                  border: const OutlineInputBorder(),
                ),
                style: GoogleFonts.firaCode(fontSize: 13),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: pinController,
                decoration: InputDecoration(
                  labelText: '6-Digit Pairing PIN',
                  hintText: 'e.g. 123456 or terminal PIN',
                  prefixIcon: const Icon(Icons.key_rounded, size: 18),
                  helperText: 'Read 6-digit PIN from desktop terminal or use 123456',
                  helperMaxLines: 2,
                  labelStyle: GoogleFonts.sourceSerif4(),
                  border: const OutlineInputBorder(),
                ),
                style: GoogleFonts.firaCode(fontSize: 14, letterSpacing: 2),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AiraColors.claudeTerracotta.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: AiraColors.claudeTerracotta),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pairing issues a cryptographic Bearer token with 30s replay-protected commands.',
                        style: GoogleFonts.sourceSerif4(fontSize: 11, color: AiraColors.claudeTerracotta),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.sourceSerif4()),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.verified_user_rounded, size: 16, color: Colors.white),
            label: Text('Pair Securely', style: GoogleFonts.sourceSerif4(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AiraColors.claudeTerracotta,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () async {
              final ip = ipController.text.trim();
              final pin = pinController.text.trim();
              if (ip.isEmpty) {
                _showSnackBar('Please enter laptop IP address.', isError: true);
                return;
              }

              Navigator.pop(ctx);
              _showSnackBar('🔐 Handshaking with laptop $ip...');
              final res = await _service.pairDevice(ip, pin);
              if (res['success'] == true) {
                _showSnackBar('✅ Securely paired with ${res['hostname'] ?? "Laptop"}!');
                _testConnection();
              } else {
                // Fallback to static config if pair/confirm fails
                await _service.saveConfig(ip, pin);
                _testConnection();
              }
            },
          ),
        ],
      ),
    );
  }

  // ── Stage I: Device Bridge & Action Receipts Tab ───────────────────────────

  Widget _buildDeviceBridgeTab(ThemeData theme, bool isDark) {
    final cardBg = isDark ? AiraColors.cardDark : AiraColors.cardLight;
    final borderColor = isDark ? AiraColors.borderDark : AiraColors.borderLight;
    final receipts = _service.actionReceipts;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Security Status Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _service.isPaired
                  ? const Color(0xFF1E8E3E).withValues(alpha: isDark ? 0.15 : 0.08)
                  : Colors.amber.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _service.isPaired
                    ? const Color(0xFF1E8E3E).withValues(alpha: 0.4)
                    : Colors.amber.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _service.isPaired ? Icons.verified_user_rounded : Icons.gpp_maybe_rounded,
                  size: 32,
                  color: _service.isPaired ? const Color(0xFF1E8E3E) : Colors.amber.shade700,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _service.isPaired ? 'Cryptographic Device Bridge Active' : 'Unpaired / PIN Fallback Mode',
                        style: GoogleFonts.sourceSerif4(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: _service.isPaired ? const Color(0xFF1E8E3E) : Colors.amber.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _service.isPaired
                            ? 'Protected with short-lived TTL, idempotency caching, and per-device Bearer token.'
                            : 'Static PIN mode active. Run Pairing Wizard to upgrade to tokenized security.',
                        style: GoogleFonts.sourceSerif4(
                          fontSize: 11.5,
                          color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Host & Bridge Metadata Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bridge Connection Details',
                  style: GoogleFonts.playfairDisplay(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 14),
                _bridgeInfoRow('Laptop Host', _service.hostname ?? _systemInfo?['hostname'] as String? ?? 'AIRA Host', isDark),
                _bridgeInfoRow('IP & Port', '${_service.laptopIp}:8765', isDark),
                _bridgeInfoRow('Device ID', _service.deviceId ?? 'Not assigned', isDark),
                _bridgeInfoRow(
                  'Device Token',
                  _service.deviceToken != null && _service.deviceToken!.length > 12
                      ? '${_service.deviceToken!.substring(0, 8)}...${_service.deviceToken!.substring(_service.deviceToken!.length - 6)}'
                      : 'None (Unpaired)',
                  isDark,
                ),
                const Divider(height: 24),
                // Pause Remote Execution Toggle Switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pause Remote Execution',
                            style: GoogleFonts.sourceSerif4(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Temporarily freeze remote command execution on host',
                            style: GoogleFonts.sourceSerif4(
                              fontSize: 11,
                              color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _service.isRemotePaused,
                      activeThumbColor: Colors.amber.shade700,
                      onChanged: (val) async {
                        HapticFeedback.selectionClick();
                        await _service.toggleRemotePause(val);
                        setState(() {});
                        _showSnackBar(val ? '🔕 Remote execution paused on laptop' : '🔔 Remote execution active on laptop');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Actions Row: Pair Wizard / Revoke Pairing
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Colors.white),
                  label: Text('Pairing Wizard', style: GoogleFonts.sourceSerif4(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AiraColors.claudeTerracotta,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _showConnectDialog,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.link_off_rounded, size: 16, color: Colors.red),
                  label: Text('Revoke / Unpair', style: GoogleFonts.sourceSerif4(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _confirmUnpair,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Durable Action Receipts Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Durable Action Receipts',
                    style: GoogleFonts.playfairDisplay(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Idempotent audit log with replay & TTL verification',
                    style: GoogleFonts.sourceSerif4(
                      fontSize: 11,
                      color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                    ),
                  ),
                ],
              ),
              if (receipts.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    await _service.clearActionReceipts();
                    setState(() {});
                  },
                  child: Text('Clear', style: GoogleFonts.sourceSerif4(fontSize: 12, color: AiraColors.claudeTerracotta)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (receipts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 36, color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight),
                  const SizedBox(height: 8),
                  Text(
                    'No commands executed yet',
                    style: GoogleFonts.sourceSerif4(fontSize: 13, color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Send commands from Chat, Voice, or Controls to see live receipts here.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sourceSerif4(fontSize: 11, color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: receipts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, index) {
                final r = receipts[index];
                final status = r['status']?.toString() ?? 'unknown';
                final isReplayed = r['replayed'] == true;
                final tool = r['tool']?.toString() ?? 'action';
                final output = r['output']?.toString() ?? '';
                final duration = r['duration_ms'] ?? 0;
                final cmdId = r['command_id']?.toString() ?? '';
                final timeMs = r['executed_at'] as int? ?? 0;
                final timeStr = timeMs > 0 ? DateTime.fromMillisecondsSinceEpoch(timeMs).toLocal().toString().substring(11, 19) : '';

                Color statusColor = Colors.green;
                String statusLabel = 'Executed ($duration ms)';
                IconData statusIcon = Icons.check_circle_outline_rounded;

                if (isReplayed) {
                  statusColor = Colors.amber;
                  statusLabel = 'Idempotent Replay';
                  statusIcon = Icons.sync_rounded;
                } else if (status == 'expired') {
                  statusColor = Colors.orange;
                  statusLabel = 'Expired (TTL)';
                  statusIcon = Icons.timer_off_outlined;
                } else if (status == 'failed') {
                  statusColor = Colors.red;
                  statusLabel = 'Failed';
                  statusIcon = Icons.error_outline_rounded;
                }

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AiraColors.claudeTerracotta.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tool.toUpperCase(),
                                  style: GoogleFonts.firaCode(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AiraColors.claudeTerracotta,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timeStr,
                                style: GoogleFonts.firaCode(fontSize: 10.5, color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 11, color: statusColor),
                                const SizedBox(width: 3),
                                Text(
                                  statusLabel,
                                  style: GoogleFonts.sourceSerif4(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        output.isNotEmpty ? output : '(No output)',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.sourceSerif4(fontSize: 12, color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: $cmdId',
                        style: GoogleFonts.firaCode(fontSize: 9.5, color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _bridgeInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.sourceSerif4(fontSize: 12, color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight)),
          Text(value, style: GoogleFonts.firaCode(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _confirmUnpair() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Unpair Laptop Bridge?', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
        content: Text(
          'This will revoke your phone\'s cryptographic token on the laptop host and drop active connections immediately.',
          style: GoogleFonts.sourceSerif4(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.unpairDevice();
              setState(() {
                _connected = false;
                _systemInfo = null;
              });
              _showSnackBar('🚫 Laptop pairing revoked successfully.');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Unpair Now', style: GoogleFonts.sourceSerif4(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Live Desktop AIRA Voice & Vision Controller ────────────────────────────

  void _openLiveDesktopAiraModal() {
    _takeScreenshot();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            final cardBg = isDark ? AiraColors.cardDark : AiraColors.cardLight;
            final borderColor = isDark ? AiraColors.borderDark : AiraColors.borderLight;

            void startListening() async {
              if (!_speechEnabled) {
                _speechEnabled = await _speech.initialize();
              }
              if (!_speechEnabled) {
                _showSnackBar('Microphone permission or speech recognition not available', isError: true);
                return;
              }

              HapticFeedback.lightImpact();
              setModalState(() {
                _isListeningLive = true;
                _liveVoiceCommand = 'Listening to your voice...';
              });

              _speech.listen(
                onResult: (val) {
                  setModalState(() {
                    _liveVoiceCommand = val.recognizedWords;
                  });
                  if (val.finalResult && val.recognizedWords.trim().isNotEmpty) {
                    _speech.stop();
                    setModalState(() => _isListeningLive = false);
                    _sendLiveDesktopVoiceCommand(val.recognizedWords.trim(), setModalState);
                  }
                },
                listenOptions: stt.SpeechListenOptions(
                  listenMode: stt.ListenMode.confirmation,
                ),
              );
            }

            void stopListening() {
              _speech.stop();
              setModalState(() => _isListeningLive = false);
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E8E3E).withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.screen_search_desktop_rounded,
                                  color: Color(0xFF1E8E3E), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Live Desktop AIRA',
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  'Voice & Screen-Grounded Laptop Control',
                                  style: GoogleFonts.sourceSerif4(
                                    fontSize: 11.5,
                                    color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            stopListening();
                            Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E8E3E).withValues(alpha: isDark ? 0.14 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1E8E3E).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF1E8E3E)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Action executes directly on LAPTOP, not phone',
                            style: GoogleFonts.sourceSerif4(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E8E3E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_screenshot != null)
                              Image.memory(
                                _screenshot!,
                                fit: BoxFit.contain,
                              )
                            else
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.laptop_chromebook_rounded,
                                        size: 40,
                                        color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight),
                                    const SizedBox(height: 6),
                                    Text('Screen preview updating...',
                                        style: GoogleFonts.sourceSerif4(
                                            fontSize: 12,
                                            color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight)),
                                  ],
                                ),
                              ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () async {
                                  await _takeScreenshot();
                                  setModalState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.refresh_rounded, size: 12, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text('Refresh Screen',
                                          style: GoogleFonts.sourceSerif4(fontSize: 10, color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _buildVoiceChip('🟢 Press that green button', setModalState),
                        _buildVoiceChip('❌ Close this app', setModalState),
                        _buildVoiceChip('⬇️ Scroll down', setModalState),
                        _buildVoiceChip('🔍 Search YouTube for Hanuman Chalisa', setModalState),
                        _buildVoiceChip('🪟 Minimize window', setModalState),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _isListeningLive
                                    ? '🎙️ LISTENING...'
                                    : (_isExecutingLiveCommand
                                        ? '🧠 THINKING & WORKING ON LAPTOP...'
                                        : 'SPOKEN COMMAND'),
                                style: GoogleFonts.firaCode(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: _isListeningLive
                                      ? const Color(0xFF1E8E3E)
                                      : (_isExecutingLiveCommand
                                          ? AiraColors.claudeTerracotta
                                          : (isDark ? AiraColors.textMuted : AiraColors.textMutedLight)),
                                ),
                              ),
                              if (_isExecutingLiveCommand)
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AiraColors.claudeTerracotta),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _liveVoiceCommand.isEmpty
                                ? 'Tap the mic below and say "Press that green button" or "Close this app"'
                                : _liveVoiceCommand,
                            style: GoogleFonts.sourceSerif4(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          if (_lastLiveActionMessage != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AiraColors.claudeTerracotta.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '💻 Laptop: $_lastLiveActionMessage',
                                style: GoogleFonts.sourceSerif4(
                                  fontSize: 12,
                                  color: AiraColors.claudeTerracotta,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      if (_isListeningLive) {
                        stopListening();
                      } else {
                        startListening();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListeningLive ? Colors.red.shade600 : const Color(0xFF1E8E3E),
                        boxShadow: [
                          BoxShadow(
                            color: (_isListeningLive ? Colors.red.shade600 : const Color(0xFF1E8E3E))
                                .withValues(alpha: 0.45),
                            blurRadius: _isListeningLive ? 24 : 12,
                            spreadRadius: _isListeningLive ? 6 : 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          _isListeningLive ? Icons.stop_rounded : Icons.mic_rounded,
                          size: 38,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isListeningLive ? 'Tap to finish speaking' : 'Tap to speak to Laptop',
                    style: GoogleFonts.sourceSerif4(
                      fontSize: 12,
                      color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendLiveDesktopVoiceCommand(
    String command,
    StateSetter setModalState,
  ) async {
    final text = command.trim();
    if (text.isEmpty || _isExecutingLiveCommand) return;

    setModalState(() {
      _isExecutingLiveCommand = true;
      _lastLiveActionMessage = 'Executing on laptop: "$text"...';
    });

    try {
      final res = await _service.executeLiveDesktopCommand(text);
      final message = res['message']?.toString() ?? 'Action completed on laptop.';
      final screenshotB64 = res['screenshot'] as String?;

      if (screenshotB64 != null && screenshotB64.isNotEmpty) {
        try {
          final decoded = base64Decode(screenshotB64);
          setState(() {
            _screenshot = decoded;
          });
        } catch (_) {}
      }

      setModalState(() {
        _isExecutingLiveCommand = false;
        _lastLiveActionMessage = message;
      });

      final cleanTts = message.replaceAll(RegExp(r'[*#_`~]'), '');
      await _tts.speak(cleanTts);
    } catch (e) {
      setModalState(() {
        _isExecutingLiveCommand = false;
        _lastLiveActionMessage = 'Error: $e';
      });
    }
  }

  Widget _buildVoiceChip(String label, StateSetter setModalState) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: GoogleFonts.sourceSerif4(fontSize: 11)),
        backgroundColor: AiraColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onPressed: () {
          final clean = label.replaceFirst(RegExp(r'^[^\s]+\s+'), '');
          setModalState(() => _liveVoiceCommand = clean);
          _sendLiveDesktopVoiceCommand(clean, setModalState);
        },
      ),
    );
  }
}
