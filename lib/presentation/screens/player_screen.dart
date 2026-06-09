// lib/presentation/screens/player_screen.dart
// ✅ ULTRA SPEED OPTIMIZED VERSION — টাচ সোয়াইপ (Swipe Left/Right) + রিমোট কি-প্যাড (১০ নম্বর চ্যানেল) ফিক্সড

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
        _initController();
        _startControlsTimer();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    _controlsTimer = Timer(const Duration(seconds: 4), () {
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
    if (!mounted) return;

    final appState = Provider.of<AppState>(context, listen: false);
    final channel = appState.currentChannel;

    if (_activeChannelId == channel.id &&
        _controller != null &&
        _controller!.value.isInitialized &&
        !_controller!.value.hasError) {
      setState(() => _isLoading = false);
      return;
    }

    _retryTimer?.cancel();

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
      Uri.parse(channel.streamUrl.trim()),
      videoPlayerOptions: VideoPlayerOptions(
        allowBackgroundPlayback: false,
        mixWithOthers: false,
      ),
      httpHeaders: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Accept': '*/*',
        'Connection': 'keep-alive',
      },
    );

    try {
      await newController.initialize().timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw TimeoutException('Stream timeout: ${channel.name}');
        },
      );

      if (!mounted || _activeChannelId != channel.id) {
        newController.dispose();
        return;
      }

      await newController.play();
      _enforceWakelock();

      _controllerListener = _onControllerUpdate;
      newController.addListener(_controllerListener!);

      _retryCount = 0;

      setState(() {
        _controller = newController;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Init Error caught: $e");
      newController.dispose();
      if (_activeChannelId == channel.id) {
        _handleLoadError(channel.name);
      }
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final ctrl = _controller;
    if (ctrl == null) return;

    if (ctrl.value.hasError) {
      debugPrint("Player controller internal error: ${ctrl.value.errorDescription}");
      _controller?.removeListener(_onControllerUpdate);
      _scheduleRetry();
      return;
    }

    setState(() {}); 
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    if (!mounted) return;

    if (_retryCount >= _maxRetry) {
      setState(() => _isLoading = false);
      _showErrorSnackbar('স্ট্রিম লোড ব্যর্থ। পরের চ্যানেলে যান।');
      return;
    }

    _retryCount++;
    setState(() => _isLoading = true);

    _retryTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        _activeChannelId = null; 
        _initController();
      }
    });
  }

  void _handleLoadError(String channelName) {
    if (!mounted) return;
    if (_retryCount < _maxRetry) {
      _scheduleRetry();
    } else {
      setState(() => _isLoading = false);
      _showErrorSnackbar('$channelName লোড হতে ব্যর্থ হয়েছে।');
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  void _safeChannelSwitch(int direction) {
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

    final appState = Provider.of<AppState>(context, listen: false);
    appState.switchChannel(direction);

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _initController();
    });
  }

  void _switchToSpecificChannelNumber(int targetNumber) {
    final appState = Provider.of<AppState>(context, listen: false);
    final allChannels = appState.channels;
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

      appState.selectChannelByIndex(targetIndex);

      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _initController();
      });
    } else {
      _showErrorSnackbar('$targetNumber নম্বরে কোনো চ্যানেল পাওয়া যায়নি।');
    }
  }

  void _handleNumberInput(String number) {
    _numberInputTimer?.cancel();
    
    setState(() {
      _showControls = true;
      _typedChannelNumber += number;
    });

    _numberInputTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted && _typedChannelNumber.isNotEmpty) {
        final targetNum = int.tryParse(_typedChannelNumber);
        if (targetNum != null) {
          _switchToSpecificChannelNumber(targetNum);
        }
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
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.select) {
      _togglePlayPause();
    }
  }

  void _togglePlayPause() {
    if (_isLoading) return;
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    setState(() {
      if (ctrl.value.isPlaying) {
        ctrl.pause();
      } else {
        ctrl.play();
        _enforceWakelock();
      }
    });
    _startControlsTimer();
  }

  void _exitPlayer() async {
    _controlsTimer?.cancel();
    _numberInputTimer?.cancel();
    _retryTimer?.cancel();

    try {
      await WakelockPlus.disable();
    } catch (_) {}

    try {
      await _controller?.pause();
    } catch (_) {}

    if (!mounted) return;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlsTimer?.cancel();
    _numberInputTimer?.cancel();
    _retryTimer?.cancel();

    try {
      WakelockPlus.disable();
    } catch (_) {}

    if (_controller != null && _controllerListener != null) {
      _controller!.removeListener(_controllerListener!);
    }
    _controller?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero || duration.isNegative) return "00:00";
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    final currentChannel = appState.currentChannel;
    
    final controller = _controller;
    final initialized = controller != null && controller.value.isInitialized;
    final isLive = controller?.value.duration == Duration.zero || controller?.value.duration == null;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        // ── 🎯 ফিক্স: GestureDetector এর অন-সোয়াইপ লজিক যুক্ত করা হয়েছে ──
        body: GestureDetector(
          onTap: _toggleControlsVisibility,
          onHorizontalDragEnd: (details) {
            // Sensitivity থ্রেশহোল্ড সেট করা হয়েছে যাতে হালকা ছোঁয়াতেই চ্যানেল ওলটপালট না হয়
            if (details.primaryVelocity == null) return;
            
            if (details.primaryVelocity! < -300) {
              // ডান থেকে বামে সোয়াইপ (Swipe Left) -> পরবর্তী চ্যানেল
              _safeChannelSwitch(1);
            } else if (details.primaryVelocity! > 300) {
              // বাম থেকে ডানে সোয়াইপ (Swipe Right) -> পূর্ববর্তী চ্যানেল
              _safeChannelSwitch(-1);
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              
              // ভিডিও লেয়ার (BoxFit.cover জুম ফিট)
              if (initialized && !_isLoading)
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover, 
                    child: SizedBox(
                      width: controller.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  ),
                )
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 16),
                      if (_retryCount > 0)
                        Text(
                          'পুনরায় চেষ্টা করা হচ্ছে... ($_retryCount/$_maxRetry)',
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),

              // টপ বার
              if (_showControls)
                Positioned(
                  left: 0, right: 0, top: 0,
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.live_tv, color: Colors.red, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  '${currentChannel.name}  •  ${currentChannel.quality}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 28),
                            onPressed: _exitPlayer,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 🚫 ফিক্স: মাঝের পুরনো অ্যারো (< >) এবং প্লে/পজ বাটন কন্টেইনার সম্পূর্ণ রিমুভ করা হয়েছে

              // বটম কন্ট্রোল বার
              if (_showControls && initialized && !_isLoading)
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                            onPressed: _togglePlayPause,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                            child: const Row(
                              children: [
                                CircleAvatar(radius: 3, backgroundColor: Colors.white),
                                SizedBox(width: 5),
                                Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          if (!isLive) ...[
                            Text(_formatDuration(controller.value.position), style: const TextStyle(color: Colors.white, fontSize: 12)),
                            Expanded(
                              child: VideoProgressIndicator(
                                controller,
                                allowScrubbing: true,
                                colors: const VideoProgressColors(
                                  playedColor: Colors.red,
                                  bufferedColor: Colors.white24,
                                  backgroundColor: Colors.white12,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                            Text(_formatDuration(controller.value.duration), style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ] else
                            const Expanded(child: SizedBox.shrink()),
                        ],
                      ),
                    ),
                  ),
                ),

              // চ্যানেল সুইচ টোস্ট লেয়ার
              Positioned(
                left: 24, right: 24,
                bottom: _showControls ? 70 : 24,
                child: Consumer<AppState>(
                  builder: (context, state, child) {
                    return AnimatedOpacity(
                      opacity: state.showToast ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(18)),
                        child: Row(
                          children: [
                            const Icon(Icons.radar, color: Colors.white),
                            const SizedBox(width: 12),
                            Expanded(child: Text(state.toastMessage, style: const TextStyle(color: Colors.white))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // নম্বর ইনপুট ওভারলে
              if (_typedChannelNumber.isNotEmpty)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red, width: 2.5),
                    ),
                    child: Text(
                      _typedChannelNumber,
                      style: const TextStyle(color: Colors.white, fontSize: 54, fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
