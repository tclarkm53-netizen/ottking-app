// lib/presentation/screens/player_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart'; // ◄ ১. ওয়েভলক প্লাস ইম্পোর্ট

import '../providers/app_state.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final FocusNode _mainPlayerFocusNode = FocusNode(debugLabel: 'player-root');
  VideoPlayerController? _controller;
  String? _activeChannelId;
  bool _isInitializing = false;
  bool _showControls = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _initController();
    _startControlsTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_mainPlayerFocusNode);
      }
    });
  }

  Future<void> _initController() async {
    if (_isInitializing) return;

    final appState = context.read<AppState>();
    final url = appState.currentChannel.streamUrl;

    setState(() {
      _isInitializing = true;
      _activeChannelId = appState.currentChannel.id;
    });

    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }

    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await _controller!.initialize();
      await _controller!.play();
      _controller!.setLooping(true);

      // ◄ ২. ভিডিও সফলভাবে প্লে হলে স্ক্রিন স্লিপ মোড অফ করে দেওয়া
      WakelockPlus.enable(); 
      
    } catch (e) {
      debugPrint("OTT-KING Engine Player Crash Alert: $e");
    }

    if (!mounted) return;

    setState(() {
      _isInitializing = false;
    });
  }

  void _syncControllerIfNeeded(AppState appState) {
    if (_activeChannelId == appState.currentChannel.id) return;
    _activeChannelId = appState.currentChannel.id;
    Future.microtask(() => _initController());
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startControlsTimer();
  }

  @override
  void dispose() {
    // ◄ ৩. প্লেয়ার থেকে বের হয়ে গেলে স্ক্রিন লক রিলিজ করে দেওয়া
    WakelockPlus.disable(); 

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _controlsTimer?.cancel();
    _controller?.dispose();
    _mainPlayerFocusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event, AppState appState) {
    if (event is! KeyDownEvent) return;

    if (!_showControls) {
      setState(() => _showControls = true);
      _startControlsTimer();
      if (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter) {
        return; 
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      appState.switchChannel(-1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      appState.switchChannel(1);
    } else if (event.logicalKey == LogicalKeyboardKey.select || 
               event.logicalKey == LogicalKeyboardKey.enter || 
               event.logicalKey == LogicalKeyboardKey.space) {
      if (_controller != null && _controller!.value.isInitialized) {
        if (_controller!.value.isPlaying) {
          _controller!.pause();
          WakelockPlus.disable(); // ভিডিও পজ করলে স্ক্রিন অফ হতে পারবে
        } else {
          _controller!.play();
          WakelockPlus.enable(); // ভিডিও আবার প্লে করলে স্ক্রিন অন থাকবে
        }
        setState(() {}); 
        _startControlsTimer();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft || 
               event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    _syncControllerIfNeeded(appState);
    final controller = _controller;
    final isBuffer = _isInitializing || (controller != null && controller.value.isBuffering);

    return KeyboardListener(
      focusNode: _mainPlayerFocusNode,
      onKeyEvent: (event) => _handleKeyEvent(event, appState),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            children: [
              if (controller != null && controller.value.isInitialized)
                Positioned.fill(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ),

              if (_showControls)
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.85),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),

              if (isBuffer)
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 4,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Optimizing Stream...',
                        style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5),
                      )
                    ],
                  ),
                ),

              if (_showControls)
                Positioned(
                  top: 28,
                  left: 28,
                  right: 28,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appState.currentChannel.name,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Streaming Quality: ${appState.currentChannel.quality.toUpperCase()}',
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444), 
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.radar_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),

              if (_showControls)
                Positioned(
                  bottom: 28,
                  left: 28,
                  right: 28,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: const LinearProgressIndicator(
                          value: 1.0, 
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
                          minHeight: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  (controller != null && controller.value.isPlaying) 
                                      ? Icons.pause_circle_filled_rounded 
                                      : Icons.play_circle_filled_rounded,
                                  color: const Color(0xFF06B6D4),
                                  size: 42,
                                ),
                                onPressed: () {
                                  if (controller != null && controller.value.isInitialized) {
                                    if (controller.value.isPlaying) {
                                      controller.pause();
                                      WakelockPlus.disable();
                                    } else {
                                      controller.play();
                                      WakelockPlus.enable();
                                    }
                                    setState(() {});
                                    _startControlsTimer();
                                  }
                                },
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Zapping System Active (Press ▲ ▼ to change channels)',
                                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.hd_rounded, color: Colors.white60, size: 22),
                              const SizedBox(width: 16),
                              Icon(Icons.fullscreen_rounded, color: Colors.white.withOpacity(0.8), size: 26),
                            ],
                          )
                        ],
                      ),
                    ],
                  ),
                ),

              Positioned(
                bottom: _showControls ? 100 : 28,
                left: 28,
                right: 28,
                child: AnimatedOpacity(
                  opacity: appState.showToast ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withOpacity(0.95),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.4)),
                        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, color: Color(0xFF06B6D4), size: 20),
                          const SizedBox(width: 10),
                          Text(
                            appState.toastMessage,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
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
}
