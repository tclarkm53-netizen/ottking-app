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
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    _initController();

    // স্ক্রিন ওপেন হওয়ার সাথে সাথে অ্যান্ড্রয়েড টিভি রিমোটের ফোকাস একটিভ করার জন্য
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_focusNode);
      }
    });
  }

  Future<void> _initController() async {
    if (_isInitializing) return;
    
    final appState = context.read<AppState>();
    final url = appState.currentChannel.streamUrl;

    setState(() {
      _isInitializing = true;
    });

    // মেমোরি লিক এবং ব্যাকগ্রাউন্ড ক্র্যাশ আটকাতে আগের কন্ট্রোলার সম্পূর্ণ ডিসপোজ করা
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }

    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await _controller!.initialize();
      await _controller!.play();
    } catch (e) {
      debugPrint("OTT-KING Video Player Error: $e");
    }

    if (!mounted) return;

    _activeChannelId = appState.currentChannel.id;
    setState(() {
      _isInitializing = false;
    });
  }

  void _syncControllerIfNeeded(AppState appState) {
    if (_activeChannelId == appState.currentChannel.id) {
      return;
    }

    _activeChannelId = appState.currentChannel.id;
    // Build ফেজের বাইরে সেফলি চ্যানেল রি-ইনিশিয়ালের জন্য microtask ব্যবহার করা হয়েছে
    Future.microtask(() => _initController());
  }

  @override
  void dispose() {
    _controller?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event, AppState appState) {
    if (event is! KeyDownEvent) return;

    // রিমোটের আপ/ডাউন বাটন দিয়ে লাইভ চ্যানেল পরিবর্তন (Zapping)
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      appState.switchChannel(-1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      appState.switchChannel(1);
    } 
    // রিমোটের ব্যাক বা লেফট বাটন প্রেস করলে মেমোরি ফ্রি করে হোমে ফিরে যাওয়া
    else if (event.logicalKey == LogicalKeyboardKey.arrowLeft || 
             event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context); 
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    _syncControllerIfNeeded(appState);
    final controller = _controller;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (event) => _handleKeyEvent(event, appState),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── ১. ফুলস্ক্রীন লাইভ ভিডিও প্লেয়ার ──
            if (controller != null && controller.value.isInitialized && !_isInitializing)
              Positioned.fill(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                ),
              )
            else
              // চ্যানেল লোডিং বা বাফারিং ইন্ডিকেটর
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)), // ওটিটি প্রিমিয়াম সায়ান থিম
                ),
              ),

            // ── ২. ওএসডি (On-Screen Display): লাইভ চ্যানেল ইনফো বার ──
            Positioned(
              left: 24,
              top: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E), // লাইভ স্ট্রিমিং গ্রিন ডট
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${appState.currentChannel.name} • ${appState.currentChannel.quality.toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── ৩. বটম ওএসডি: চ্যানেল সুইচের প্রিমিয়াম নোটিফিকেশন Overlay ──
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: AnimatedOpacity(
                opacity: appState.showToast ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withOpacity(0.9), // ওটিটি ডার্ক ব্যাকগ্রাউন্ড
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: Color(0xFF06B6D4), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          appState.toastMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
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
    );
  }
}
