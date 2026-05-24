// lib/presentation/screens/player_screen.dart

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
  String? _activeChannelId;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    // মোবাইল ডিভাইসে ফুলস্ক্রিন এবং ল্যান্ডস্কেপ মোড অন করার জন্য
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initController());
  }

  Future<void> _initController() async {
    final appState = context.read<AppState>();
    final channel = appState.currentChannel;

    if (_activeChannelId == channel.id) return;

    final oldController = _controller;
    final newController =
        VideoPlayerController.networkUrl(Uri.parse(channel.streamUrl));

    try {
      await newController.initialize();
      await newController.play();
      
      // ভিডিও প্লে হওয়া অবস্থায় প্রোগ্রেস বার আপডেট রাখার জন্য লিসেনার
      newController.addListener(() {
        if (mounted) setState(() {});
      });

      if (!mounted) {
        newController.dispose();
        return;
      }

      setState(() {
        _controller = newController;
        _activeChannelId = channel.id;
      });

      oldController?.dispose();
    } catch (e) {
      debugPrint("Video initialization failed: $e");
    }
  }

  void _handleKey(KeyEvent event, AppState appState) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      appState.switchChannel(-1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      appState.switchChannel(1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.escape) {
      _exitPlayer();
    } else if (event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      _togglePlayPause();
    }
  }

  void _togglePlayPause() {
    final ctrl = _controller;
    if (ctrl == null) return;
    setState(() {
      ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
    });
  }

  void _exitPlayer() {
    // প্লেয়ার থেকে বের হওয়ার সময় ওরিয়েন্টেশন আগের অবস্থায় ফিরিয়ে নেওয়া
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  void dispose() {
    _controller?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // টাইম ফরম্যাট করার ইউটিলিটি ফাংশন (00:00)
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (_activeChannelId != null &&
        _activeChannelId != appState.currentChannel.id) {
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
          onTap: () => setState(() => _showControls = !_showControls),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── ১. ভিডিও লেয়ার ─────────────────────────────────────────────
              if (initialized)
                Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                )
              else
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),

              // ── ২. টপ বার (চ্যানেল নেম ও ক্লোজ বাটন) ──────────────────────────
              if (_showControls)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      backgroundBlendMode: BlendMode.darken,
                      color: Colors.black34,
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
                                  '${appState.currentChannel.name}  •  ${appState.currentChannel.quality}',
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

              // ── ৩. মেন্টাল/সেন্টার প্লে-পজ বাটন ও মোবাইল কন্ট্রোলার ──────────────────
              if (_showControls)
                Center(
                  child: GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      width: 65,
                      height: 65,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        initialized && controller.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),

              // ── ৪. মোবাইল স্পেসিফিক বটম কন্ট্রোল বার (প্রোগ্রেস বার সহ) ─────────────
              if (_showControls && initialized)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10, top: 10),
                    color: Colors.black54,
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          // প্লে/পজ বাটন
                          IconButton(
                            icon: Icon(
                              controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                            ),
                            onPressed: _togglePlayPause,
                          ),
                          
                          // কারেন্ট টাইম
                          Text(
                            _formatDuration(controller.value.position),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          
                          // ভিডিও প্রোগ্রেস বার (সিক বার)
                          Expanded(
                            child: VideoProgressIndicator(
                              controller,
                              allowScrubbing: true, // টেনে আগে পিছে নেওয়ার অপশন
                              colors: const VideoProgressColors(
                                playedColor: Colors.red,
                                bufferedColor: Colors.white24,
                                backgroundColor: Colors.white12,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          
                          // টোটাল টাইম
                          Text(
                            _formatDuration(controller.value.duration),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── ৫. চ্যানেল সুইচ টোস্ট ───────────────────────────────────────
              Positioned(
                left: 24,
                right: 24,
                bottom: _showControls ? 70 : 24, // কন্ট্রোলার থাকলে একটু ওপরে উঠবে
                child: AnimatedOpacity(
                  opacity: appState.showToast ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(199),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.radar, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            appState.toastMessage,
                            style: const TextStyle(color: Colors.white),
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
}
