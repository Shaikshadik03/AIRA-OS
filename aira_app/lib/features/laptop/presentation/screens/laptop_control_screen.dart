import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/features/laptop/data/laptop_control_service.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _service.loadConfig().then((_) {
      if (_service.isConfigured) {
        _testConnection();
      }
    });
  }

  @override
  void dispose() {
    _service.disconnectWebSocket();
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
                          ? (_systemInfo?['hostname'] as String? ?? 'Connected')
                          : 'Not Connected'),
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 11.5,
                    color: _connected ? Colors.green : Colors.red.shade400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
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
            tooltip: 'Connection Settings',
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Text('Connect to Laptop',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipController,
              decoration: InputDecoration(
                labelText: 'Laptop IP Address',
                hintText: '192.168.1.100',
                labelStyle: GoogleFonts.sourceSerif4(),
                hintStyle: GoogleFonts.sourceSerif4(),
                border: const OutlineInputBorder(),
              ),
              style: GoogleFonts.firaCode(),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              decoration: InputDecoration(
                labelText: 'PIN (default: 123456)',
                labelStyle: GoogleFonts.sourceSerif4(),
                border: const OutlineInputBorder(),
              ),
              style: GoogleFonts.firaCode(),
              obscureText: true,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.sourceSerif4()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.saveConfig(
                  ipController.text, pinController.text);
              _testConnection();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AiraColors.claudeTerracotta),
            child: Text('Connect',
                style: GoogleFonts.sourceSerif4(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
