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

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startControlsTimer();
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

  void _showAppInfo() {
    showDialog(
      context: context,
      builder: (_) => AppInfoDialog(),
    ).then((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
    });
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
        } else if (!_longHandled) {
          // শর্ট প্রেস - প্লে/পজ টগেল
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

              // ========== টপ রাইট প্যানেল ==========
              if (_showControls)
                PlayerTopPanel(
                  channel: ch,
                  currentIndex: _appState!.currentChannelIndex,
                  totalChannels: _appState!.channels.length,
                  onSettings: _openSettings,
                ),

              // ========== বটম কন্ট্রোল বার ==========
              if (_showControls && initialized)
                PlayerBottomBar(
                  ctrl: _ctrl!,
                  isLive: isLive,
                  liveBlink: _liveBlink,
                  onPlayPause: _togglePlayPause,
                  onExit: _handleExit,
                ),

              // ========== চ্যানেল লিস্ট সাইড প্যানেল ==========
              if (_showChannelList)
                ChannelListPanel(
                  channels: _appState!.channels,
                  currentIndex: _appState!.currentChannelIndex,
                  onSelect: (i) {
                    setState(() => _showChannelList = false);
                    _switchToIndex(i);
                  },
                  onClose: () =>
                      setState(() => _showChannelList = false),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
