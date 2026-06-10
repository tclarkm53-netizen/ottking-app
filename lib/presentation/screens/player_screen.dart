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

  void _showAppInfo() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.info_rounded, color: AppTheme.primary),
            SizedBox(width: 10),
            Text('অ্যাপ তথ্য',
                style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Live TV Player',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Version 1.0.0',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ডেভেলপার:',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Anirban Sumon',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('বন্ধ',
                style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    ).then((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
    });
  }

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

      if (confirmed == true && mounted) {
        await _exit();
      }
    } else {
      await _goToHome();
    }
  }

  Future<void> _goToHome() async {
    _controlsTimer?.cancel();
    _numberTimer?.cancel();
    _retryTimer?.cancel();
    _blinkTimer?.cancel();
    try {
      await WakelockPlus.disable();
    } catch (_) {}
    try {
      await _ctrl?.pause();
    } catch (_) {}
    if (!mounted) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _exit() async {
    _controlsTimer?.cancel();
    _numberTimer?.cancel();
    _retryTimer?.cancel();
    _blinkTimer?.cancel();
    try {
      await WakelockPlus.disable();
    } catch (_) {}
    try {
      await _ctrl?.pause();
    } catch (_) {}
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

  void _handleKey(KeyEvent event) {
    final label = event.logicalKey.keyLabel;

    if (event is KeyDownEvent) {
      // সংখ্যা ইনপুট (0-9)
      if (RegExp(r'^[0-9]$').hasMatch(label)) {
        _handleNumberInput(label);
        return;
      }

      // ↑↓ - চ্যানেল সুইচ
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

      // → - সেটিংস খুলুন
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _openSettings();
        return;
      }

      // ← - অ্যাপ তথ্য দেখান
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _showAppInfo();
        return;
      }

      // OK বোতাম - লং প্রেস চেক শুরু করুন
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.space) {
        _okDown ??= DateTime.now();
        _longHandled = false;
      }

      // যেকোনো কী তে কন্ট্রোল দেখান
      if (!_showControls) {
        setState(() => _showControls = true);
        _startControlsTimer();
        return;
      }
      _startControlsTimer();

      // ESC - এক্সিট
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.goBack) {
        _handleExit();
      }
    }

    if (event is KeyUpEvent) {
      // OK বোতাম আপ ইভেন্ট
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.space) {
        final held = _okDown != null
            ? DateTime.now().difference(_okDown!)
            : Duration.zero;
        _okDown = null;

        // লং প্রেস (০.৮s) - চ্যানেল লিস্ট টগেল
        if (!_longHandled && held.inMilliseconds >= 800) {
          _longHandled = true;
          setState(() => _showChannelList = !_showChannelList);
        } 
        // শর্ট প্রেস - প্লে/পজ টগেল
        else if (!_longHandled) {
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
    try {
      WakelockPlus.disable();
    } catch (_) {}
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
              // ========== ভিডিও প্লেয়ার ==========
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

              // ========== টপ রাইট প্যানেল ==========
              if (_showControls)
                Positioned(
                  top: 20,
                  right: 20,
                  child: _TopRightPanel(
                    channel: ch,
                    currentIndex: _appState!.currentChannelIndex,
                    totalChannels: _appState!.channels.length,
                    typedNumber: _typed,
                    onSettings: _openSettings,
                  ),
                ),

              // ========== বটম কন্ট্রোল বার ==========
              if (_showControls && initialized)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _BottomControlBar(
                    ctrl: _ctrl!,
                    isLive: isLive,
                    liveBlink: _liveBlink,
                    onPlayPause: _togglePlayPause,
                    onExit: _handleExit,
                  ),
                ),

              // ========== চ্যানেল লিস্ট সাইড প্যানেল ==========
              if (_showChannelList)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
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

// ========== টপ রাইট প্যানেল উইজেট ==========
class _TopRightPanel extends StatelessWidget {
  const _TopRightPanel({
    required this.channel,
    required this.currentIndex,
    required this.totalChannels,
    required this.typedNumber,
    required this.onSettings,
  });

  final dynamic channel;
  final int currentIndex;
  final int totalChannels;
  final String typedNumber;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // চ্যানেল নম্বার এবং নাম
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'CH ${currentIndex + 1}',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                channel.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // সেটিংস বোতাম
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: const Icon(Icons.settings_rounded,
                color: Colors.white70, size: 28),
            onPressed: onSettings,
            tooltip: 'সেটিংস',
          ),
        ),
      ],
    );
  }
}

// ========== বটম কন্ট্রোল বার উইজেট ==========
class _BottomControlBar extends StatelessWidget {
  const _BottomControlBar({
    required this.ctrl,
    required this.isLive,
    required this.liveBlink,
    required this.onPlayPause,
    required this.onExit,
  });

  final VideoPlayerController ctrl;
  final bool isLive;
  final bool liveBlink;
  final VoidCallback onPlayPause;
  final VoidCallback onExit;

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
          // প্লে/পজ বোতাম
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
          const SizedBox(width: 12),

          // LIVE ব্লিংকিং ব্যাজ
          if (isLive)
            AnimatedOpacity(
              opacity: liveBlink ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: Colors.white),
                    SizedBox(width: 6),
                    Text('LIVE',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5)),
                  ],
                ),
              ),
            ),

          const Spacer(),

          // এক্সিট বোতাম
          IconButton(
            icon: const Icon(Icons.exit_to_app_rounded,
                color: Colors.white70, size: 24),
            onPressed: onExit,
            tooltip: 'এক্সিট',
          ),
        ],
      ),
    );
  }
}

// ========== লোডিং ওভারলে উইজেট ==========
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

// ========== ওভারলে বোতাম উইজেট ==========
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

// ========== চ্যানেল সাইড প্যানেল উইজেট ==========
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
