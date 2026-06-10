// ✅ FULL PRODUCTION READY PLAYER SCREEN — MATCHING YOUR LATEST DESIGN
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../providers/app_state.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  final FocusNode _focusNode = FocusNode(debugLabel: 'player-root');

  VideoPlayerController? _controller;
  VoidCallback? _controllerListener;
  String? _activeChannelId;

  bool _showControls = true;
  bool _isLoading = false;

  AppState? _appState;

  Timer? _controlsTimer;
  Timer? _numberInputTimer;
  Timer? _retryTimer;

  String _typedChannelNumber = "";
  int _retryCount = 0;
  static const int _maxRetry = 3;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enforceWakelock();
      if (_controller?.value.hasError == true) {
        _retryCount = 0;
        _initController();
      }
    } else if (state == AppLifecycleState.paused) {
      _controller?.pause();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _enforceWakelock();

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

  Future<void> _enforceWakelock() async {
    try {
      await WakelockPlus.enable();
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (e) {
      debugPrint("Wakelock error: $e");
    }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _showControls && _typedChannelNumber.isEmpty) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControlsVisibility() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startControlsTimer();
  }

  void _disposeControllerInBackground(VideoPlayerController old, VoidCallback? listener) {
    Future(() async {
      try {
        if (listener != null) old.removeListener(listener);
        await old.setVolume(0.0);
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
        _controller != null &&
        _controller!.value.isInitialized &&
        !_controller!.value.hasError) {
      return;
    }

    setState(() {
      _isLoading = true;
      _activeChannelId = channel.id;
    });

    if (_controller != null) {
      final oldCtrl = _controller!;
      final oldListener = _controllerListener;
      _controller = null;
      _controllerListener = null;
      _disposeControllerInBackground(oldCtrl, oldListener);
    }

    final newController = VideoPlayerController.networkUrl(
      Uri.parse(channel.streamUrl),
      videoPlayerOptions: const VideoPlayerOptions(
        allowBackgroundPlayback: false,
        mixWithOthers: false,
      ),
      httpHeaders: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
        'Accept': '*/*',
      },
    );

    try {
      await newController.initialize().timeout(const Duration(seconds: 20));
      if (!mounted) {
        newController.dispose();
        return;
      }

      await newController.play();
      _enforceWakelock();

      _controllerListener = _onControllerUpdate;
      newController.addListener(_controllerListener!);

      _retryCount = 0;

      if (mounted) {
        setState(() {
          _controller = newController;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Player init error: $e");
      newController.dispose();
      _handleLoadError(channel.name);
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final ctrl = _controller;
    if (ctrl == null) return;

    if (ctrl.value.hasError) {
      _scheduleRetry();
      return;
    }
    setState(() {});
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    if (_retryCount >= _maxRetry) {
      if (mounted) setState(() => _isLoading = false);
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

  void _handleLoadError(String channelName) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _activeChannelId = null;
    });

    if (_retryCount < _maxRetry) {
      _scheduleRetry();
    }
  }

  void _safeChannelSwitch(int direction) {
    if (_appState == null) return;

    _retryTimer?.cancel();
    _retryCount = 0;

    setState(() {
      _showControls = true;
      _isLoading = true;
      _activeChannelId = null;
    });
    _startControlsTimer();

    if (_controller != null) {
      final oldCtrl = _controller!;
      final oldListener = _controllerListener;
      _controller = null;
      _controllerListener = null;
      _disposeControllerInBackground(oldCtrl, oldListener);
    }

    _appState!.switchChannel(direction);

    Future.microtask(() {
      if (mounted) _initController();
    });
  }

  void _switchToSpecificChannelNumber(int targetNumber) {
    if (_appState == null) return;

    final allChannels = _appState!.channels;
    final targetIndex = targetNumber - 1;

    if (targetIndex >= 0 && targetIndex < allChannels.length) {
      _retryTimer?.cancel();
      _retryCount = 0;

      setState(() {
        _showControls = true;
        _isLoading = true;
        _activeChannelId = null;
      });

      if (_controller != null) {
        final oldCtrl = _controller!;
        final oldListener = _controllerListener;
        _controller = null;
        _controllerListener = null;
        _disposeControllerInBackground(oldCtrl, oldListener);
      }

      _appState!.selectChannelByIndex(targetIndex);

      Future.microtask(() {
        if (mounted) _initController();
      });
    }
  }

  void _handleNumberInput(String number) {
    _numberInputTimer?.cancel();
    setState(() {
      _showControls = true;
      _typedChannelNumber += number;
    });

    _numberInputTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && _typedChannelNumber.isNotEmpty) {
        final targetNum = int.tryParse(_typedChannelNumber);
        if (targetNum != null) _switchToSpecificChannelNumber(targetNum);
        setState(() => _typedChannelNumber = "");
        _startControlsTimer();
      }
    });
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final keyLabel = event.logicalKey.keyLabel;

    if (RegExp(r'^[0-9]$').hasMatch(keyLabel)) {
      _handleNumberInput(keyLabel);
      return;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _safeChannelSwitch(-1);
      return;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _safeChannelSwitch(1);
      return;
    }

    if (!_showControls) {
      setState(() => _showControls = true);
      _startControlsTimer();
      return;
    }

    _startControlsTimer();

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack) {
      _exitPlayer();
    } else if (event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      _togglePlayPause();
    }
  }

  void _togglePlayPause() {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _isLoading) return;

    setState(() {
      if (ctrl.value.isPlaying) {
        ctrl.pause();
      } else {
        ctrl.play();
        _enforceWakelock();
      }
    });
  }

  void _exitPlayer() async {
    _controlsTimer?.cancel();
    _numberInputTimer?.cancel();
    _retryTimer?.cancel();

    try {
      await WakelockPlus.disable();
      await _controller?.pause();
    } catch (_) {}

    if (!mounted) return;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    if (_appState == null) return const Scaffold(backgroundColor: Colors.black);

    final currentChannel = _appState!.currentChannel;
    final controller = _controller;
    final initialized = controller != null && controller.value.isInitialized;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControlsVisibility,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ভিডিও লেয়ার
              if (initialized && !_isLoading)
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: controller.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  ),
                )
              else
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),

              // টপ বার (চ্যানেল নাম + সেটিংস)
              if (_showControls)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // বামে চ্যানেল নাম কার্ড
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentChannel.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      currentChannel.quality.toUpperCase(),
                                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // ডানে সেটিংস আইকন
                          IconButton(
                            icon: const Icon(Icons.settings, color: Colors.white, size: 28),
                            onPressed: () => Navigator.pushNamed(context, '/settings'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // নাম্বার ইনপুট ওভারলে (টপ লেফটের কাছে)
              if (_typedChannelNumber.isNotEmpty)
                Positioned(
                  top: 110,
                  left: 40,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.redAccent, width: 3),
                    ),
                    child: Text(
                      _typedChannelNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 68,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                      ),
                    ),
                  ),
                ),

              // বটম চ্যানেল ডিটেইলস বার (টিভি রিসিভার স্টাইল)
              if (_showControls)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black.withOpacity(0.95), Colors.transparent],
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          // চ্যানেল লোগো
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: currentChannel.logoUrl.trim().isNotEmpty
                                ? Image.network(
                                    currentChannel.logoUrl,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.live_tv_rounded, color: Colors.white54, size: 52),
                                  )
                                : const Icon(Icons.live_tv_rounded, color: Colors.white54, size: 52),
                          ),

                          const SizedBox(width: 20),

                          // ডিটেইলস
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentChannel.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${currentChannel.category} • ${currentChannel.quality.toUpperCase()}",
                                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                              ],
                            ),
                          ),

                          // সময়
                          Text(
                            TimeOfDay.now().format(context),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _numberInputTimer?.cancel();
    _retryTimer?.cancel();
    WakelockPlus.disable();
    if (_controller != null && _controllerListener != null) {
      _controller!.removeListener(_controllerListener!);
    }
    _controller?.dispose();
    _focusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
