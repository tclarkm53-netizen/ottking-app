// lib/presentation/screens/player_screen.dart
// ✅ UPDATED VERSION — REMOVED ALL STREAM DETAILS MENU + ADDED FREE/PREMIUM TAG IN CONTROLLER + LONG PRESS OK

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
  bool _isBootPlayerEnabled = true;

  Timer? _controlsTimer;
  Timer? _numberInputTimer;
  Timer? _retryTimer;
  
  // লং প্রেস ট্র্যাক করার জন্য ভ্যারিয়েবল
  DateTime? _okKeyDownTime;
  bool _isOkKeyPressed = false;

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
        const Duration(seconds: 8),
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
      _showErrorSnackbar('Failed to load stream. Please switch to the next channel.');
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
      _showErrorSnackbar('$channelName Offline or failed to load.');
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
    _controlsTimer?.cancel();
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

    Future.delayed(const Duration(milliseconds: 50), () {
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

      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) _initController();
      });
    } else {
      _showErrorSnackbar('$targetNumber No channel found at this number.');
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
        if (targetNum != null) {
          _switchToSpecificChannelNumber(targetNum);
        }
        setState(() => _typedChannelNumber = "");
        _startControlsTimer();
      }
    });
  }

  void _handleKey(KeyEvent event) {
    final key = event.logicalKeyboardKey;
    final isOkKey = key == LogicalKeyboardKey.enter || 
                     key == LogicalKeyboardKey.select || 
                     key == LogicalKeyboardKey.space;

    if (event is KeyDownEvent) {
      final keyLabel = event.logicalKey.keyLabel;
      if (RegExp(r'^[0-9]$').hasMatch(keyLabel)) {
        _handleNumberInput(keyLabel);
        return;
      }

      if (key == LogicalKeyboardKey.arrowUp) {
        _safeChannelSwitch(-1);
        return;
      } else if (key == LogicalKeyboardKey.arrowDown) {
        _safeChannelSwitch(1);
        return;
      }

      if (isOkKey) {
        if (!_isOkKeyPressed) {
          _isOkKeyPressed = true;
          _okKeyDownTime = DateTime.now();
        }
      }

      if (!_showControls) {
        setState(() => _showControls = true);
        _startControlsTimer();
        return;
      }

      _startControlsTimer();

      if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.escape ||
          key == LogicalKeyboardKey.goBack) {
        _exitPlayer();
      }
    } 
    
    else if (event is KeyUpEvent) {
      if (isOkKey && _isOkKeyPressed) {
        _isOkKeyPressed = false;
        if (_okKeyDownTime != null) {
          final duration = DateTime.now().difference(_okKeyDownTime!);
          if (duration.inMilliseconds >= 800) {
            _showTVRemoteSettingsDialog(); // লং প্রেস সেটিংস ওপেন
          } else {
            _togglePlayPause();
          }
        }
      }
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

  // রিমোট সেটিংস ডায়ালগ (এখানে স্ট্রিম ডিটেইলস এর কিছুই নেই)
  void _showTVRemoteSettingsDialog() {
    _controlsTimer?.cancel();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[950],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const Border.all(color: Colors.white10, width: 1),
              ),
              title: const Row(
                children: [
                  Icon(Icons.tv_settings_rounded, color: Colors.redAccent, size: 28),
                  SizedBox(width: 12),
                  Text('প্লেয়ার সেটিংস', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    activeColor: Colors.green,
                    title: const Text('Enable Boot Player', style: TextStyle(color: Colors.white, fontSize: 16)),
                    subtitle: const Text('When the app is launched, it will open directly in the player.', style: TextStyle(color: Colors.white60, fontSize: 12)),
                    value: _isBootPlayerEnabled,
                    onChanged: (bool value) {
                      setDialogState(() {
                        _isBootPlayerEnabled = value;
                      });
                      setState(() {});
                      _showErrorSnackbar(_isBootPlayerEnabled ? 'Boot Player has been enabled.' : 'Boot Player has been disabled.');
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  autofocus: true,
                  onPressed: () {
                    Navigator.pop(context);
                    _startControlsTimer();
                  },
                  child: const Text('Close', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                )
              ],
            );
          },
        );
      },
    );
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

    // ── 🎯 নোট: আপনার AppState এ চ্যানেলটি প্রিমিয়াম কি না তা চেক করার লজিক (isPremium ট্রু বা ফলস অনুসারে) ──
    // যদি আপনার ভ্যারিয়েবলের নাম অন্য হয়, শুধু 'currentChannel.isPremium' এর জায়গায় সেটি বসিয়ে দিন।
    final bool isPremiumChannel = currentChannel.isPremium ?? false; 

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControlsVisibility,
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity == null) return;
            if (details.primaryVelocity! < -300) {
              _safeChannelSwitch(1); 
            } else if (details.primaryVelocity! > 300) {
              _safeChannelSwitch(-1); 
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              
              // XY FIT লেয়ার
              if (initialized && !_isLoading)
                Positioned.fill(
                  child: SizedBox.expand(
                    child: VideoPlayer(controller),
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
                          'Retrying... ($_retryCount/$_maxRetry)',
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                        )
                      else if (_isLoading)
                        const Text(
                          'Establishing connection...',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                                const SizedBox(width: 10),
                                
                                // ── 🎯 ফিক্সড: কন্ট্রোলারে সরাসরি ফ্রি / প্রিমিয়াম ট্যাগ প্রদর্শন ──
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isPremiumChannel ? Colors.amber[800] : Colors.green[700],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isPremiumChannel ? 'PREMIUM' : 'FREE',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // টপ সেটিংস গিয়ার বাটন (পপআপ থেকে স্ট্রিম ডিটেইলস পুরোপুরি আউট, শুধু বুট অপশন রয়েছে)
                          Theme(
                            data: Theme.of(context).copyWith(cardColor: Colors.grey[900]),
                            child: PopupMenuButton<String>(
                              icon: const Icon(Icons.settings, color: Colors.white, size: 26),
                              onOpened: () => _controlsTimer?.cancel(), 
                              onCanceled: () => _startControlsTimer(),
                              onSelected: (value) {
                                _startControlsTimer();
                                if (value == 'boot_player') {
                                  setState(() {
                                    _isBootPlayerEnabled = !_isBootPlayerEnabled;
                                  });
                                  _showErrorSnackbar(_isBootPlayerEnabled ? 'Boot Player has been enabled.' : 'Boot Player has been disabled');
                                }
                              },
                              itemBuilder: (BuildContext context) => [
                                PopupMenuItem<String>(
                                  value: 'boot_player',
                                  child: Row(
                                    children: [
                                      Icon(
                                        _isBootPlayerEnabled ? Icons.check_box : Icons.check_box_outline_blank,
                                        color: _isBootPlayerEnabled ? Colors.green : Colors.white60,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      const Text('Enable Boot Player', style: TextStyle(color: Colors.white, fontSize: 14)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

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
