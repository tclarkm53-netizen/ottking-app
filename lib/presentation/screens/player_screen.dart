// lib/presentation/screens/player_screen.dart
// ✅ TV-only landscape player
// ✅ Channel switch ALWAYS works — even when stream is offline/error
// ✅ Boot player remembers last channel (restored via AppState)
// ✅ Settings dialog has Boot Player toggle

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme/app_theme.dart';
import '../providers/app_state.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  final FocusNode _focus = FocusNode(debugLabel: 'player-root');

  VideoPlayerController? _ctrl;
  VoidCallback? _ctrlListener;
  String? _activeChannelId;

  bool _showControls = true;
  bool _isLoading = false;
  bool _hasStreamError = false; // stream has fatal error but we still show UI

  AppState? _appState;

  Timer? _controlsTimer;
  Timer? _numberTimer;
  Timer? _retryTimer;

  String _typed = '';
  int _retryCount = 0;
  static const int _maxRetry = 3;

  DateTime? _okDown;
  bool _longHandled = false;

  // Channel side-panel
  bool _showChannelList = false;

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

  // ── Controls timer ────────────────────────────────────────────────────────

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

  // ── Controller lifecycle ──────────────────────────────────────────────────

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

    // Already playing this channel and no error — skip
    if (_activeChannelId == channel.id &&
        _ctrl != null &&
        _ctrl!.value.isInitialized &&
        !_ctrl!.value.hasError) return;

    setState(() {
      _isLoading = true;
      _hasStreamError = false;
      _activeChannelId = channel.id;
    });

    // Dispose old
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

  void _onCtrlUpdate() {
    if (!mounted) return;
    if (_ctrl?.value.hasError == true) {
      _scheduleRetry();
    }
    setState(() {});
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    if (_retryCount >= _maxRetry) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasStreamError = true; // show error overlay but DON'T block switching
        });
      }
      return;
    }
    _retryCount++;
    if (mounted) setState(() => _isLoading = true);
    _retryTimer =
        Timer(Duration(seconds: _retryCount * 2), () {
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

  // ── Channel switching — ALWAYS works regardless of stream error ───────────

  /// Core switch — always resets error state and loads new channel.
  void _switchChannel(int direction) {
    if (_appState == null) return;

    // Cancel retries and reset error state immediately
    _retryTimer?.cancel();
    _retryCount = 0;

    // Dispose current controller right away
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

  // ── Number input ──────────────────────────────────────────────────────────

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

  // ── Settings dialog ───────────────────────────────────────────────────────

  void _openSettings() {
    _controlsTimer?.cancel();
    showDialog(
      context: context,
      builder: (_) => Consumer<AppState>(
        builder: (ctx, state, __) => AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.primary, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.settings, color: Colors.white),
              SizedBox(width: 10),
              Text('প্লেয়ার সেটিংস',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Boot Player (অটো প্লেয়ার)',
                    style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  'অ্যাপ চালু হলে সরাসরি লাইভ টিভি খুলবে',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 12),
                ),
                activeColor: AppTheme.primary,
                value: state.isPlayerBootEnabled,
                onChanged: (v) => state.togglePlayerBoot(),
              ),
              if (state.isAuthenticated)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ListTile(
                    leading: const Icon(Icons.stars_rounded,
                        color: Color(0xFFEAB308)),
                    title: Text(
                      state.userProfile?.email ?? '',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'প্ল্যান: ${state.userProfile?.plan ?? ''}',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/settings');
              },
              child: const Text('সেটিংস',
                  style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('বন্ধ',
                  style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        ),
      ),
    ).then((_) => _startControlsTimer());
  }

  // ── Key handler ───────────────────────────────────────────────────────────

  void _handleKey(KeyEvent event) {
    final label = event.logicalKey.keyLabel;

    if (event is KeyDownEvent) {
      // Number input
      if (RegExp(r'^[0-9]$').hasMatch(label)) {
        _handleNumberInput(label);
        return;
      }

      // Channel switch — Up/Down; also Page Up/Down as alternates
      if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.pageUp) {
        _switchChannel(-1);
        return;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
          event.logicalKey == LogicalKeyboardKey.pageDown) {
        _switchChannel(1);
        return;
      }

      // OK / Select long-press for settings
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.space) {
        _okDown ??= DateTime.now();
        _longHandled = false;
      }

      // Show controls on any key
      if (!_showControls) {
        setState(() => _showControls = true);
        _startControlsTimer();
        return;
      }
      _startControlsTimer();

      // Back → exit to home
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.goBack) {
        _exit();
      }

      // Right → channel list panel
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        setState(() => _showChannelList = !_showChannelList);
      }
    }

    if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.space) {
        final held = _okDown != null
            ? DateTime.now().difference(_okDown!)
            : Duration.zero;
        _okDown = null;

        if (!_longHandled && held.inMilliseconds >= 800) {
          _longHandled = true;
          _openSettings();
        } else if (!_longHandled) {
          _togglePlayPause();
        }
        _longHandled = false;
      }
    }
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

  Future<void> _exit() async {
    _controlsTimer?.cancel();
    _numberTimer?.cancel();
    _retryTimer?.cancel();
    try { await WakelockPlus.disable(); } catch (_) {}
    try { await _ctrl?.pause(); } catch (_) {}
    if (!mounted) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Navigator.pushReplacementNamed(context, '/home');
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlsTimer?.cancel();
    _numberTimer?.cancel();
    _retryTimer?.cancel();
    try { WakelockPlus.disable(); } catch (_) {}
    if (_ctrl != null && _ctrlListener != null) {
      _ctrl!.removeListener(_ctrlListener!);
    }
    _ctrl?.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_appState == null) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final ch = _appState!.currentChannel;
    final initialized =
        _ctrl != null && _ctrl!.value.isInitialized && !_hasStreamError;
    final isLive = _ctrl?.value.duration == Duration.zero ||
        _ctrl?.value.duration == null;

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
              // ── Video ──────────────────────────────────────────────────────
              if (initialized)
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: _ctrl!.value.size.width,
                      height: _ctrl!.value.size.height,
                      child: VideoPlayer(_ctrl!),
                    ),
                  ),
                )
              else
                _LoadingOverlay(
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

              // ── Top bar ────────────────────────────────────────────────────
              if (_showControls)
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: _TopOverlay(
                    channel: ch,
                    isAuthenticated: _appState!.isAuthenticated,
                    userPlan: _appState?.userProfile?.plan,
                    onSettings: _openSettings,
                    onExit: _exit,
                  ),
                ),

              // ── Bottom bar ─────────────────────────────────────────────────
              if (_showControls && initialized)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: _BottomOverlay(
                    ctrl: _ctrl!,
                    isLive: isLive,
                    onPlayPause: _togglePlayPause,
                    channelIndex: _appState!.currentChannelIndex,
                    totalChannels: _appState!.channels.length,
                  ),
                ),

              // ── Channel toast ──────────────────────────────────────────────
              Positioned(
                left: 24, right: 24,
                bottom: _showControls ? 80 : 24,
                child: AnimatedOpacity(
                  opacity: _appState!.showToast ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: _ChannelToast(message: _appState!.toastMessage),
                ),
              ),

              // ── Number input overlay ───────────────────────────────────────
              if (_typed.isNotEmpty)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppTheme.primary, width: 2.5),
                    ),
                    child: Text(
                      _typed,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),

              // ── Channel list side panel ────────────────────────────────────
              if (_showChannelList)
                Positioned(
                  right: 0, top: 0, bottom: 0,
                  child: _ChannelSidePanel(
                    channels: _appState!.channels,
                    currentIndex: _appState!.currentChannelIndex,
                    onSelect: (i) {
                      setState(() => _showChannelList = false);
                      _switchToIndex(i);
                    },
                    onClose: () =>
                        setState(() => _showChannelList = false),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({
    required this.hasError,
    required this.retryCount,
    required this.maxRetry,
    required this.channelName,
    required this.onRetry,
    required this.onNext,
  });
  final bool hasError;
  final int retryCount;
  final int maxRetry;
  final String channelName;
  final VoidCallback onRetry;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasError) ...[
              const Icon(Icons.signal_wifi_statusbar_connected_no_internet_4,
                  color: Colors.white38, size: 64),
              const SizedBox(height: 16),
              Text(
                '$channelName — চ্যানেল অফলাইন',
                style: const TextStyle(
                    color: Colors.white60, fontSize: 18),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _OverlayBtn(
                    icon: Icons.refresh_rounded,
                    label: 'রিট্রাই',
                    onTap: onRetry,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 16),
                  _OverlayBtn(
                    icon: Icons.skip_next_rounded,
                    label: 'পরের চ্যানেল',
                    onTap: onNext,
                    color: Colors.white24,
                  ),
                ],
              ),
            ] else ...[
              CircularProgressIndicator(
                  color: AppTheme.primary, strokeWidth: 3),
              const SizedBox(height: 16),
              if (retryCount > 0)
                Text(
                  'পুনরায় চেষ্টা করা হচ্ছে... ($retryCount/$maxRetry)',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 14),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OverlayBtn extends StatelessWidget {
  const _OverlayBtn(
      {required this.icon,
      required this.label,
      required this.onTap,
      required this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: color.withOpacity(0.15),
        foregroundColor: color,
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: color.withOpacity(0.4))),
      ),
      icon: Icon(icon),
      label: Text(label,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold)),
    );
  }
}

class _TopOverlay extends StatelessWidget {
  const _TopOverlay({
    required this.channel,
    required this.isAuthenticated,
    required this.userPlan,
    required this.onSettings,
    required this.onExit,
  });
  final dynamic channel;
  final bool isAuthenticated;
  final String? userPlan;
  final VoidCallback onSettings;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          // Exit
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white70, size: 20),
            onPressed: onExit,
          ),
          const SizedBox(width: 8),
          // Channel info
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('LIVE',
                    style: TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                const SizedBox(width: 12),
                Text(
                  channel.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    channel.quality,
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                if (channel.isPremium == 1) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAB308).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('PREMIUM',
                        style: TextStyle(
                            color: Color(0xFFEAB308),
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
          // Auth badge
          if (isAuthenticated && userPlan != null)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded,
                      color: Color(0xFFEAB308), size: 14),
                  const SizedBox(width: 4),
                  Text(userPlan!,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          // Channel list toggle hint
          Opacity(
            opacity: 0.6,
            child: Row(
              children: [
                const Text('চ্যানেল লিস্ট',
                    style:
                        TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    color: Colors.white38, size: 16),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings_rounded,
                color: Colors.white70, size: 22),
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}

class _BottomOverlay extends StatelessWidget {
  const _BottomOverlay({
    required this.ctrl,
    required this.isLive,
    required this.onPlayPause,
    required this.channelIndex,
    required this.totalChannels,
  });
  final VideoPlayerController ctrl;
  final bool isLive;
  final VoidCallback onPlayPause;
  final int channelIndex;
  final int totalChannels;

  String _fmt(Duration d) {
    if (d <= Duration.zero) return '00:00';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.85), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              ctrl.value.isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_filled_rounded,
              color: Colors.white,
              size: 36,
            ),
            onPressed: onPlayPause,
          ),
          const SizedBox(width: 4),
          // LIVE badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                CircleAvatar(radius: 3, backgroundColor: Colors.white),
                SizedBox(width: 5),
                Text('LIVE',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (!isLive) ...[
            Text(_fmt(ctrl.value.position),
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12)),
            Expanded(
              child: VideoProgressIndicator(
                ctrl,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: AppTheme.primary,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white12,
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
            Text(_fmt(ctrl.value.duration),
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12)),
          ] else
            const Expanded(child: SizedBox.shrink()),

          const SizedBox(width: 12),
          // Channel number indicator
          Text(
            'CH ${channelIndex + 1} / $totalChannels',
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          // Remote hints
          const _RemoteHint(keys: '▲▼ চ্যানেল  ◀ ব্যাক  OK প্লে  ► লিস্ট'),
        ],
      ),
    );
  }
}

class _RemoteHint extends StatelessWidget {
  const _RemoteHint({required this.keys});
  final String keys;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        keys,
        style: const TextStyle(color: Colors.white38, fontSize: 10),
      ),
    );
  }
}

class _ChannelToast extends StatelessWidget {
  const _ChannelToast({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.88),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppTheme.primary.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.2),
              blurRadius: 20,
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.live_tv_rounded,
                color: AppTheme.primary, size: 18),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelSidePanel extends StatelessWidget {
  const _ChannelSidePanel({
    required this.channels,
    required this.currentIndex,
    required this.onSelect,
    required this.onClose,
  });
  final List channels;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.92),
        border: Border(
            left: BorderSide(
                color: AppTheme.primary.withOpacity(0.3), width: 1)),
      ),
      child: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.list_rounded,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text('চ্যানেল লিস্ট',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white38, size: 18),
                    onPressed: onClose),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: channels.length,
              itemBuilder: (ctx, i) {
                final ch = channels[i];
                final active = i == currentIndex;
                return GestureDetector(
                  onTap: () => onSelect(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: active
                        ? AppTheme.primary.withOpacity(0.15)
                        : Colors.transparent,
                    child: Row(
                      children: [
                        Text(
                          '${i + 1}'.padLeft(3),
                          style: TextStyle(
                            color: active
                                ? AppTheme.primary
                                : Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ch.name,
                            style: TextStyle(
                              color: active
                                  ? Colors.white
                                  : Colors.white60,
                              fontSize: 14,
                              fontWeight: active
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (active)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
