// lib/presentation/screens/player_screen.dart

import 'dart:async'; // টাইমার ব্যবহারের জন্য জরুরি
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../providers/app_state.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'player-root');
  VideoPlayerController? _controller;
  VoidCallback? _controllerListener;
  String? _activeChannelId;
  bool _showControls = true;
  bool _isLoading = false;

  // ── টাইমার ও ইনপুট বাফারিং ভেরিয়েবল ──
  String _enteredDigits = ""; 
  bool _showNumberCard = false; // ডানদিকের নম্বর কার্ডটি দেখানোর জন্য ফ্ল্যাগ
  Timer? _inputTimer; // নাম্বার কিপ্যাডের জন্য টাইমার
  Timer? _controlsHideTimer; // কন্ট্রোলস অটো-হাইড করার জন্য টাইমার

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initController());
    
    // অ্যাপে ঢোকার পর প্রথমবার কন্ট্রোলস অটো-হাইড টাইমার রান করা
    _startControlsHideTimer();
  }

  // ── কন্ট্রোলস অটো-হাইড টাইমার মেথড ──
  void _startControlsHideTimer() {
    _controlsHideTimer?.cancel(); // আগের কোনো টাইমার চললে তা রিসেট করা
    
    _controlsHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _showControls && !_isLoading) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  // ── ইউজার অ্যাকশন বা স্ক্রিন ট্যাপে টাইমার রিসেট করার মেথড ──
  void _toggleControlsVisibility() {
    setState(() {
      _showControls = !_showControls;
    });
    
    if (_showControls) {
      _startControlsHideTimer();
    } else {
      _controlsHideTimer?.cancel();
    }
  }

  Future<void> _initController() async {
    if (!mounted) return;
    
    final appState = context.read<AppState>();
    final channel = appState.currentChannel;

    if (_activeChannelId == channel.id) return;

    setState(() {
      _isLoading = true;
      _activeChannelId = channel.id;
      _showControls = true; // নতুন চ্যানেল লোডের সময় কন্ট্রোল দেখাবে
    });
    _startControlsHideTimer();

    if (_controller != null) {
      final oldCtrl = _controller!;
      if (_controllerListener != null) {
        oldCtrl.removeListener(_controllerListener!);
        _controllerListener = null;
      }
      _controller = null;
      try {
        await oldCtrl.pause();
      } catch (_) {}
      await oldCtrl.dispose();
    }

    final newController = VideoPlayerController.networkUrl(Uri.parse(channel.streamUrl));

    try {
      await newController.initialize();
      
      if (!mounted) {
        await newController.dispose();
        return;
      }

      await newController.play();
      
      _controllerListener = () {
        if (mounted) setState(() {});
      };
      newController.addListener(_controllerListener!);

      setState(() {
        _controller = newController;
        _isLoading = false;
      });
      
      _startControlsHideTimer(); // প্লে সফল হলে ফ্রেশ কাউন্টডাউন শুরু
    } catch (e) {
      debugPrint("Video initialization failed: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _activeChannelId = null;
        });
        
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text(
              '${channel.name} চ্যানেলটি বর্তমানে অফলাইন আছে।',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _safeChannelSwitch(AppState appState, int direction) {
    setState(() {
      _isLoading = false;    
      _activeChannelId = null; 
    });
    appState.switchChannel(direction);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initController());
  }

  void _switchToSpecificChannelIndex(AppState appState, int index) {
    setState(() {
      _isLoading = false;
      _activeChannelId = null;
    });
    
    appState.jumpToChannel(index); 
    WidgetsBinding.instance.addPostFrameCallback((_) => _initController());
  }

  void _handleKey(KeyEvent event, AppState appState) {
    if (event is! KeyDownEvent) return;
    
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    _startControlsHideTimer(); // যেকোনো বাটন প্রেস করলে হাইড টাইম আরও ৩ সেকেন্ড বাড়বে

    final String keyLabel = event.logicalKey.keyLabel;
    if (RegExp(r'^[0-9]$').hasMatch(keyLabel)) {
      _handleNumberInput(keyLabel, appState);
      return; 
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _safeChannelSwitch(appState, -1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _safeChannelSwitch(appState, 1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.escape) {
      _exitPlayer();
    } else if (event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      _togglePlayPause();
    }
  }

  // ── কাস্টম নম্বর কার্ড হ্যান্ডলিং লজিক ──
  void _handleNumberInput(String digit, AppState appState) {
    _inputTimer?.cancel(); 

    setState(() {
      _enteredDigits += digit;
      _showNumberCard = true; // ইনপুট শুরু হলেই ডানদিকের কার্ডটি শো করবে
    });

    _inputTimer = Timer(const Duration(milliseconds: 1200), () {
      final int? targetedChannelNumber = int.tryParse(_enteredDigits);
      if (targetedChannelNumber != null && targetedChannelNumber > 0) {
        final int targetIndex = targetedChannelNumber - 1; 
        _switchToSpecificChannelIndex(appState, targetIndex);
      }
      
      setState(() {
        _enteredDigits = "";
        _showNumberCard = false; // চ্যানেল সুইচ হওয়ার পর কার্ড হাইড হবে
      });
    });
  }

  void _togglePlayPause() {
    if (_isLoading) return;
    final ctrl = _controller;
    if (ctrl == null) return;
    setState(() {
      ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
    });
    _startControlsHideTimer();
  }

  void _exitPlayer() {
    _inputTimer?.cancel(); 
    _controlsHideTimer?.cancel(); 
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  void dispose() {
    _inputTimer?.cancel();
    _controlsHideTimer?.cancel(); 
    if (_controller != null && _controllerListener != null) {
      _controller!.removeListener(_controllerListener!);
    }
    _controller?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (_activeChannelId != null && _activeChannelId != appState.currentChannel.id) {
      _activeChannelId = appState.currentChannel.id;
      WidgetsBinding.instance.addPostFrameCallback((_) => _initController());
    }

    final controller = _controller;
    final initialized = controller != null && controller.value.isInitialized;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (e) => _handleKey(e, appState),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControlsVisibility, 
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── ১. ভিডিও লেয়ার ──────────────────────
              if (initialized && !_isLoading)
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: SizedBox(
                      width: controller.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  ),
                )
              else
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
                    strokeWidth: 3,
                  ),
                ),

              // ── কন্ট্রোল ব্যাকগ্রাউন্ড শ্যাডো মাস্ক ────────────────────────
              if (_showControls)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.75),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.75),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── ২. টপ বার ────────────────────────
              if (_showControls)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _exitPlayer,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    appState.currentChannel.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF06B6D4).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      appState.currentChannel.quality.toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF06B6D4),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 26),
                            onPressed: _exitPlayer,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── ৩. সেন্টার কন্ট্রোলস ─────────────────
              if (_showControls)
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCenterActionBtn(
                        icon: Icons.skip_previous_rounded,
                        onTap: () {
                          _safeChannelSwitch(appState, -1);
                          _startControlsHideTimer();
                        },
                      ),
                      const SizedBox(width: 40),
                      GestureDetector(
                        onTap: _togglePlayPause,
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: const Color(0xFF06B6D4).withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.6), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF06B6D4).withOpacity(0.3),
                                blurRadius: 15,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                          child: Icon(
                            initialized && !_isLoading && controller.value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 42,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                      _buildCenterActionBtn(
                        icon: Icons.skip_next_rounded,
                        onTap: () {
                          _safeChannelSwitch(appState, 1);
                          _startControlsHideTimer();
                        },
                      ),
                    ],
                  ),
                ),

              // ── ৪. মোবাইল বটম কন্ট্রোল বার ──────────────
              if (_showControls && initialized && !_isLoading)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFEF4444).withOpacity(0.3),
                                  blurRadius: 6,
                                )
                              ],
                            ),
                            child: const Row(
                              children: [
                                CircleAvatar(radius: 3, backgroundColor: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            _formatDuration(controller.value.position),
                            style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: VideoProgressIndicator(
                                controller,
                                allowScrubbing: true,
                                colors: const VideoProgressColors(
                                  playedColor: Color(0xFF06B6D4),
                                  bufferedColor: Colors.white24,
                                  backgroundColor: Colors.white12,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(controller.value.duration),
                            style: const TextStyle(color: Colors.white38, fontSize: 13, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── ৫. প্রফেশনাল রাইট সাইড ডিজিটাল নম্বর কার্ড (New Feature) ──
              Positioned(
                right: 32,
                top: 32,
                child: AnimatedOpacity(
                  opacity: _showNumberCard ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withOpacity(0.85), // ডিপ স্লেট গ্লাস এফেক্ট
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF06B6D4).withOpacity(0.5), // সায়ান বর্ডার
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF06B6D4).withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.connected_tv_rounded, 
                          color: Color(0xFF06B6D4), 
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "CH  $_enteredDigits",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.black,
                            fontFamily: 'monospace',
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── ৬. বটম লেফট চ্যানেল সুইচ টোস্ট (স্ট্যান্ডার্ড অ্যাকশনের জন্য) ──
              Positioned(
                left: 32,
                bottom: _showControls ? 76 : 32,
                child: AnimatedOpacity(
                  opacity: appState.showToast ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt, color: Color(0xFF06B6D4), size: 20),
                        const SizedBox(width: 10),
                        Text(
                          appState.toastMessage,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
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

  Widget _buildCenterActionBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
