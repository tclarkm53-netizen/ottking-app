// lib/presentation/screens/player_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme/app_theme.dart';
import '../providers/app_state.dart';
import 'player_widgets/player_top_panel.dart';
import 'player_widgets/player_bottom_bar.dart';
import 'player_widgets/channel_list_panel.dart';
import 'player_widgets/loading_overlay.dart';
import 'player_widgets/app_info_dialog.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  final FocusNode _focus = FocusNode(debugLabel: 'player-root');

  VideoPlayerController? _ctrl;
  VoidCallback? _ctrlListener;
  String? _activeChannelId;

  bool _showControls = true;
  bool _isLoading = false;
  bool _hasStreamError = false;
  bool _showChannelList = false;
  bool _liveBlink = true;

  AppState? _appState;

  Timer? _controlsTimer;
  Timer? _numberTimer;
  Timer? _retryTimer;
  Timer? _blinkTimer;

  String _typed = '';
  int _retryCount = 0;
  static const int _maxRetry = 3;

  DateTime? _okDown;
  bool _longHandled = false;

  // ========== Lifecycle ==========

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _wakelock();
      if (_ctrl?.value.hasError == true) {
        _retryCount = 0;
        _initController();
      }
    } else if (state == AppLifecycleState.paused) {
      _ctrl?.pause();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _forceFullLandscape();
    _wakelock();
    _startBlinkTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _appState = Provider.of<AppState>(context, listen: false);
        _initController();
        _startControlsTimer();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = context.watch<AppState>();
  }

  void _forceFullLandscape() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _wakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {}
  }

  void _startBlinkTimer() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted) setState(() => _liveBlink = !_liveBlink);
    });
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _showControls && _typed.isEmpty) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startControlsTimer();
  }

  // ========== Controller ==========

  void _disposeOld(VideoPlayerController old, VoidCallback? listener) {
    Future(() async {
      try {
        if (listener != null) old.removeListener(listener);
        await old.setVolume(0);
        if (old.value.isPlaying) await old.pause();
      } catch (_) {} finally {
        old.dispose();
      }
    });
  }

  Future<void> _initController() async {
    if (!mounted || _appState == null) return;
    final channel = _appState!.currentChannel;

    if (_activeChannelId == channel.id &&
        _ctrl != null &&
        _ctrl!.value.isInitialized &&
        !_ctrl!.value.hasError) return;

    setState(() {
      _isLoading = true;
      _hasStreamError = false;
      _activeChannelId = channel.id;
    });

    if (_ctrl != null) {
      final old = _ctrl!;
      final oldL = _ctrlListener;
      _ctrl = null;
      _ctrlListener = null;
      _disposeOld(old, oldL);
    }

    final newCtrl = VideoPlayerController.networkUrl(
      Uri.parse(channel.streamUrl),
      videoPlayerOptions: VideoPlayerOptions(
        allowBackgroundPlayback: false,
        mixWithOthers: false,
      ),
      httpHeaders: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36',
        'Accept': '*/*',
        'Connection': 'keep-alive',
      },
    );

    try {
      await newCtrl.initialize().timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw TimeoutException('timeout'),
          );

      if (!mounted) {
        newCtrl.dispose();
        return;
      }

      await newCtrl.play();
      _wakelock();

      _ctrlListener = _onCtrlUpdate;
      newCtrl.addListener(_ctrlListener!);
      _retryCount = 0;

      setState(() {
        _ctrl = newCtrl;
        _isLoading = false;
        _hasStreamError = false;
      });
    } catch (e) {
      debugPrint('Init error: $e');
      newCtrl.dispose();
      _handleLoadError();
    }
  }

  // [UPDATED] বাফারিং শেষে অটো-প্লে করার লজিক যুক্ত করা হয়েছে
  void _onCtrlUpdate() {
    if (!mounted) return;
    
    if (_ctrl?.value.hasError == true) {
      _scheduleRetry();
      return;
    }

    // বাফার লোড শেষ হলে যদি প্লেয়ার আটকে থাকে তবে ফোর্স প্লে করবে
    if (_ctrl != null && _ctrl!.value.isInitialized) {
      if (!_ctrl!.value.isBuffering && 
          !_ctrl!.value.isPlaying && 
          !_hasStreamError && 
          !_isLoading) {
        _ctrl!.play();
      }
    }
    
    setState(() {});
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    if (_retryCount >= _maxRetry) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasStreamError = true;
        });
      }
      return;
    }
    _retryCount++;
    if (mounted) setState(() => _isLoading = true);
    _retryTimer = Timer(Duration(seconds: _retryCount * 2), () {
      if (mounted) {
        setState(() => _activeChannelId = null);
        _initController();
      }
    });
  }

  void _handleLoadError() {
    if (!mounted) return;
    if (_retryCount < _maxRetry) {
      _scheduleRetry();
    } else {
      setState(() {
        _isLoading = false;
        _hasStreamError = true;
      });
    }
  }

  // ========== Channel Switch ==========

  void _switchChannel(int direction) {
    if (_appState == null) return;

    _retryTimer?.cancel();
    _retryCount = 0;

    if (_ctrl != null) {
      final old = _ctrl!;
      final oldL = _ctrlListener;
      _ctrl = null;
      _ctrlListener = null;
      _disposeOld(old, oldL);
    }

    setState(() {
      _showControls = true;
      _isLoading = true;
      _hasStreamError = false;
      _activeChannelId = null;
    });
    _startControlsTimer();

    _appState!.switchChannel(direction);

    Future.microtask(() {
      if (mounted) _initController();
    });
  }

  void _switchToIndex(int index) {
    if (_appState == null) return;
    final allCh = _appState!.channels;
    if (index < 0 || index >= allCh.length) {
      _showSnack('$index নম্বরে কোনো চ্যানেল নেই');
      return;
    }

    _retryTimer?.cancel();
    _retryCount = 0;

    if (_ctrl != null) {
      final old = _ctrl!;
      final oldL = _ctrlListener;
      _ctrl = null;
      _ctrlListener = null;
      _disposeOld(old, oldL);
    }

    setState(() {
      _showControls = true;
      _isLoading = true;
      _hasStreamError = false;
      _activeChannelId = null;
    });

    _appState!.selectChannelByIndex(index);
    Future.microtask(() {
      if (mounted) _initController();
    });
  }

  void _handleNumberInput(String digit) {
    _numberTimer?.cancel();
    setState(() {
      _showControls = true;
      _typed += digit;
    });
    _numberTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && _typed.isNotEmpty) {
        final n = int.tryParse(_typed);
        if (n != null) _switchToIndex(n - 1);
        setState(() => _typed = '');
        _startControlsTimer();
      }
    });
  }

  // ========== Settings Dialog ==========

  void _openSettings() {
    _controlsTimer?.cancel();
    showDialog(
      context: context,
      builder: (_) => Consumer<AppState>(
        builder: (ctx, state, __) => _SettingsDialog(
          state: state,
          onAppInfo: () {
            Navigator.pop(context); // settings বন্ধ করে
            _showAppInfo();
          },
          onNavigateSettings: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/settings');
          },
          onClose: () => Navigator.pop(context),
        ),
      ),
    ).then((_) => _startControlsTimer());
  }

  void _showAppInfo() {
    showDialog(
      context: context,
      builder: (_) => const AppInfoDialog(),
    ).then((_) => _startControlsTimer());
  }

  // ========== Exit Logic ==========

  Future<void> _handleExit() async {
    if (_appState == null) return;
    final shouldFullExit = _appState!.isPlayerBootEnabled;

    if (shouldFullExit) {
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.primary, width: 1.5),
          ),
          title: const Text(
            'অ্যাপ এক্সিট করবেন?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'সম্পূর্ণ অ্যাপ বন্ধ করতে চান?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('না', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('হ্যাঁ', style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) await _exit();
    } else {
      await _goToHome();
    }
  }

  Future<void> _goToHome() async {
    _controlsTimer?.cancel();
    _numberTimer?.cancel();
    _retryTimer?.cancel();
    _blinkTimer?.cancel();
    try { await WakelockPlus.disable(); } catch (_) {}
    try { await _ctrl?.pause(); } catch (_) {}
    if (!mounted) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _exit() async {
    _controlsTimer?.cancel();
    _numberTimer?.cancel();
    _retryTimer?.cancel();
    _blinkTimer?.cancel();
    try { await WakelockPlus.disable(); } catch (_) {}
    try { await _ctrl?.pause(); } catch (_) {}
    if (!mounted) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    exit(0);
  }

  void _togglePlayPause() {
    if (_isLoading || _hasStreamError) return;
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    setState(() {
      c.value.isPlaying ? c.pause() : c.play();
    });
    _wakelock();
    _startControlsTimer();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 2),
          backgroundColor: AppTheme.card));
  }

  // ========== Key Handler ==========

  void _handleKey(KeyEvent event) {
    final label = event.logicalKey.keyLabel;

    if (event is KeyDownEvent) {
      if (RegExp(r'^[0-9]$').hasMatch(label)) {
        _handleNumberInput(label);
        return;
      }

      if (event.logicalKey == LogicalKeyboardKey.channelUp ||
          event.logicalKey == LogicalKeyboardKey.pageUp ||
          event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _switchChannel(-1);
        return;
      }
      if (event.logicalKey == LogicalKeyboardKey.channelDown ||
          event.logicalKey == LogicalKeyboardKey.pageDown ||
          event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _switchChannel(1);
        return;
      }

      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.space) {
        _okDown ??= DateTime.now();
        _longHandled = false;
      }

      if (!_showControls) {
        setState(() => _showControls = true);
        _startControlsTimer();
        return;
      }
      _startControlsTimer();

      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.goBack) {
        _handleExit();
      }
    }

    if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.space) {
        final held = _okDown != null ? DateTime.now().difference(_okDown!) : Duration.zero;
        _okDown = null;

        if (!_longHandled && held.inMilliseconds >= 800) {
          _longHandled = true;
          setState(() => _showChannelList = !_showChannelList);
        } else if (!_longHandled) {
          _togglePlayPause();
        }
        _longHandled = false;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlsTimer?.cancel();
    _numberTimer?.cancel();
    _retryTimer?.cancel();
    _blinkTimer?.cancel();
    try { WakelockPlus.disable(); } catch (_) {}
    if (_ctrl != null && _ctrlListener != null) {
      _ctrl!.removeListener(_ctrlListener!);
    }
    _ctrl?.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_appState == null) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final ch = _appState!.currentChannel;
    final initialized = _ctrl != null && _ctrl!.value.isInitialized && !_hasStreamError;
    final isLive = _ctrl?.value.duration == Duration.zero || _ctrl?.value.duration == null;

    return KeyboardListener(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControls,
          onHorizontalDragEnd: (d) {
            if (d.primaryVelocity == null) return;
            if (d.primaryVelocity! < -300) _switchChannel(1);
            if (d.primaryVelocity! > 300) _switchChannel(-1);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (initialized)
                SizedBox.expand(
                  child: FittedBox(
                    // [UPDATED] BoxFit.contain থেকে BoxFit.fill এ পরিবর্তন করা হয়েছে (fitXY stretch)
                    fit: BoxFit.fill,
                    child: SizedBox(
                      width: _ctrl!.value.size.width,
                      height: _ctrl!.value.size.height,
                      child: VideoPlayer(_ctrl!),
                    ),
                  ),
                )
              else
                LoadingOverlay(
                  hasError: _hasStreamError,
                  retryCount: _retryCount,
                  maxRetry: _maxRetry,
                  channelName: ch.name,
                  onRetry: () {
                    _retryCount = 0;
                    setState(() {
                      _hasStreamError = false;
                      _activeChannelId = null;
                    });
                    _initController();
                  },
                  onNext: () => _switchChannel(1),
                ),

              if (_showControls)
                PlayerTopPanel(
                  channel: ch,
                  currentIndex: _appState!.currentChannelIndex,
                  totalChannels: _appState!.channels.length,
                  onSettings: _openSettings,
                  typedNumber: _typed,
                ),

              if (_showControls && initialized)
                PlayerBottomBar(
                  ctrl: _ctrl!,
                  isLive: isLive,
                  liveBlink: _liveBlink,
                  onPlayPause: _togglePlayPause,
                  onExit: _handleExit,
                  onChannelUp: () => _switchChannel(-1),
                  onChannelDown: () => _switchChannel(1),
                ),

              if (_showChannelList)
                ChannelListPanel(
                  channels: _appState!.channels,
                  currentIndex: _appState!.currentChannelIndex,
                  onSelect: (i) {
                    setState(() => _showChannelList = false);
                    _switchToIndex(i);
                  },
                  onClose: () => setState(() => _showChannelList = false),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== Settings Dialog Widget ==========

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({
    required this.state,
    required this.onAppInfo,
    required this.onNavigateSettings,
    required this.onClose,
  });

  final AppState state;
  final VoidCallback onAppInfo;
  final VoidCallback onNavigateSettings;
  final VoidCallback onClose;

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  final List<FocusNode> _focusNodes = [];
  final List<int> _itemIndices = [];
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    
    int totalItems = 3; 
    if (widget.state.isAuthenticated) {
      totalItems = 4; 
    }

    for (int i = 0; i < totalItems; i++) {
      _focusNodes.add(FocusNode());
      _itemIndices.add(i);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusNodes.isNotEmpty) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final n in _focusNodes) n.dispose();
    super.dispose();
  }

  void _moveFocus(int dir) {
    if (_focusNodes.isEmpty) return;
    final next = (_focusedIndex + dir).clamp(0, _focusNodes.length - 1);
    setState(() => _focusedIndex = next);
    _focusNodes[next].requestFocus();
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveFocus(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveFocus(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _focusableItem({
    required int listIndex,
    required Widget child,
    required VoidCallback onActivate,
  }) {
    final isFocused = _focusedIndex == listIndex;
    return Focus(
      focusNode: _focusNodes[listIndex],
      onFocusChange: (v) {
        if (v) setState(() => _focusedIndex = listIndex);
      },
      onKeyEvent: (_, e) {
        if (e is KeyDownEvent &&
            (e.logicalKey == LogicalKeyboardKey.enter ||
                e.logicalKey == LogicalKeyboardKey.select)) {
          onActivate();
          return KeyEventResult.handled;
        }
        return _onKey(e);
      },
      child: GestureDetector(
        onTap: onActivate,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isFocused ? AppTheme.primary.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isFocused ? AppTheme.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    int currentVisualIndex = 0;

    return AlertDialog(
      backgroundColor: Colors.black.withOpacity(0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      title: const Row(
        children: [
          Icon(Icons.settings, color: Colors.white),
          SizedBox(width: 10),
          Text('প্লেয়ার সেটিংস', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _focusableItem(
            listIndex: currentVisualIndex++,
            onActivate: () => state.togglePlayerBoot(),
            child: SwitchListTile(
              title: const Text('Boot Player (অটো প্লেয়ার)', style: TextStyle(color: Colors.white)),
              subtitle: Text(
                'অ্যাপ চালু হলে সরাসরি লাইভ টিভি খুলবে',
                style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12),
              ),
              activeColor: AppTheme.primary,
              value: state.isPlayerBootEnabled,
              onChanged: (v) => state.togglePlayerBoot(),
            ),
          ),

          if (state.isAuthenticated)
            _focusableItem(
              listIndex: currentVisualIndex++,
              onActivate: () {},
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ListTile(
                  leading: const Icon(Icons.stars_rounded, color: Color(0xFFEAB308)),
                  title: Text(
                    state.userProfile?.email ?? '',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'প্ল্যান: ${state.userProfile?.plan ?? ''}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ),
            ),

          const Divider(color: Colors.white12, height: 20),

          _focusableItem(
            listIndex: currentVisualIndex++,
            onActivate: widget.onAppInfo,
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded, color: AppTheme.primary),
              title: const Text('অ্যাপ তথ্য (App Info)', style: TextStyle(color: Colors.white)),
              subtitle: const Text('ভার্সন ও ডেভেলপার তথ্য',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            ),
          ),
        ],
      ),
      actions: [
        _focusableItem(
          listIndex: currentVisualIndex++,
          onActivate: widget.onNavigateSettings,
          child: TextButton(
            onPressed: widget.onNavigateSettings,
            child: const Text('সেটিংস', style: TextStyle(color: Colors.white54)),
          ),
        ),
        TextButton(
          onPressed: widget.onClose,
          child: Text('বন্ধ', style: TextStyle(color: AppTheme.primary)),
        ),
      ],
    );
  }
}
