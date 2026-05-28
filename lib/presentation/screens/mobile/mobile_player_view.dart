
// lib/presentation/screens/mobile_player_view.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../providers/app_state.dart';

class MobilePlayerView extends StatefulWidget {
  const MobilePlayerView({super.key});

  @override
  State<MobilePlayerView> createState() => _MobilePlayerViewState();
}

class _MobilePlayerViewState extends State<MobilePlayerView> {
  VideoPlayerController? _controller;
  VoidCallback? _controllerListener;
  String? _activeChannelId;
  bool _showControls = true;
  bool _isLoading = false;
  AppState? _appState; 
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _enableWakelock();

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

  void _enableWakelock() async {
    try {
      bool isEnabled = await WakelockPlus.enabled;
      if (!isEnabled) await WakelockPlus.enable();
    } catch (_) {}
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _showControls) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startControlsTimer();
  }

  Future<void> _initController() async {
    if (!mounted || _appState == null) return;
    final channel = _appState!.currentChannel;
    if (_activeChannelId == channel.id && _controller != null) return;

    setState(() { _isLoading = true; _activeChannelId = channel.id; });

    if (_controller != null) {
      final oldCtrl = _controller!;
      _controller = null;
      if (_controllerListener != null) oldCtrl.removeListener(_controllerListener!);
      try { await oldCtrl.pause(); } catch (_) {} finally { oldCtrl.dispose(); }
    }

    final newController = VideoPlayerController.networkUrl(
      Uri.parse(channel.streamUrl),
    );

    try {
      await newController.initialize();
      if (!mounted) { await newController.dispose(); return; }
      await newController.play();
      _enableWakelock();
      
      _controllerListener = () { if (mounted) setState(() {}); };
      newController.addListener(_controllerListener!);

      setState(() { _controller = newController; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _exitPlayer() {
    _controlsTimer?.cancel();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    WakelockPlus.disable();
    if (_controller != null && _controllerListener != null) _controller!.removeListener(_controllerListener!);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_appState == null) return const Scaffold(backgroundColor: Colors.black);
    final currentChannel = _appState!.currentChannel;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_controller != null && _controller!.value.isInitialized && !_isLoading)
              SizedBox.expand(
                child: VideoPlayer(_controller!),
              )
            else
              const Center(child: CircularProgressIndicator(color: Colors.red)),

            if (_showControls) ...[
              // মোবাইল ডিজাইন টপ বার (ব্যাক বাটন সহ)
              Positioned(
                left: 0, right: 0, top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: Colors.black45,
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: _exitPlayer),
                      const SizedBox(width: 8),
                      Text(currentChannel.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              // মোবাইল প্লে/পজ বাটন স্ক্রিনের মাঝখানে
              Center(
                child: IconButton(
                  icon: Icon(_controller?.value.isPlaying == true ? Icons.pause_circle : Icons.play_circle, color: Colors.white, size: 54),
                  onPressed: () {
                    if (_controller != null) {
                      setState(() {
                        _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                        if (_controller!.value.isPlaying) _enableWakelock();
                      });
                      _startControlsTimer();
                    }
                  },
                ),
              ),
              // মোবাইলের জন্য রেড লাইভ ডট বটম ইন্ডিকেটর
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.black54,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                        child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      Text(currentChannel.quality, style: const TextStyle(color: Colors.cyan, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}
