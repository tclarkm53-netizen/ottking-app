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
  VoidCallback? _controllerListener; // লিসেনার ট্র্যাক করার জন্য ভেরিয়েবল
  String? _activeChannelId;
  bool _showControls = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initController());
  }

  Future<void> _initController() async {
    if (!mounted) return;
    
    final appState = context.read<AppState>();
    final channel = appState.currentChannel;

    // একই চ্যানেল অলরেডি একটিভ থাকলে পুনরায় লোড করার প্রয়োজন নেই
    if (_activeChannelId == channel.id) return;

    setState(() {
      _isLoading = true;
      _activeChannelId = channel.id; // শুরুতেই আইডি ট্র্যাক করে লক করা হচ্ছে
    });

    // পুরনো কন্ট্রোলার এবং তার লিসেনার প্রফেশনাল উপায়ে রিমুভ ও ডিসপোজ করা
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
      // নেটওয়ার্ক টাইমআউট বা ইনিশিয়ালের জন্য সেফটি বাউন্ডারি
      await newController.initialize();
      
      if (!mounted) {
        await newController.dispose();
        return;
      }

      await newController.play();
      
      // লিসেনার রেফারেন্স সেভ করে রাখা যাতে পরে রিমুভ করা যায় (Prevent Memory Leak)
      _controllerListener = () {
        if (mounted) setState(() {});
      };
      newController.addListener(_controllerListener!);

      setState(() {
        _controller = newController;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Video initialization failed: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _activeChannelId = null; // অফলাইন লিংকের কারণে ফেইল করলে লক রিলিজ
        });
        
        // সেফ উপায়ে স্নাকবার শো করা
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text('${channel.name} চ্যানেলটি বর্তমানে অফলাইন আছে।'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // চ্যানেল অফলাইন বা লোডিং অবস্হায় থাকলেও নেক্সট/প্রিভিয়াস চ্যানেলে যাওয়া যাবে
  void _safeChannelSwitch(AppState appState, int direction) {
    setState(() {
      _isLoading = false;    // নতুন ইনপুট নেওয়া সচল করতে লোডিং রিলিজ
      _activeChannelId = null; // সোর্স আইডি ক্লিয়ার
    });
    appState.switchChannel(direction);
    
    // চ্যানেল চেঞ্জ হওয়ার সাথে সাথে নতুন কন্ট্রোলার ইনিশিয়েট করা
    WidgetsBinding.instance.addPostFrameCallback((_) => _initController());
  }

  void _handleKey(KeyEvent event, AppState appState) {
    if (event is! KeyDownEvent) return;
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

  void _togglePlayPause() {
    if (_isLoading) return;
    final ctrl = _controller;
    if (ctrl == null) return;
    setState(() {
      ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
    });
  }

  void _exitPlayer() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  void dispose() {
    // ডিসপোজের আগে লিসেনার রিমুভ নিশ্চিত করা
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
    // listen: true রাখা হয়েছে শুধু UI টেক্সট এবং টোস্ট মেসেজ আপডেটের জন্য
    final appState = context.watch<AppState>();

    // build মেথডের ভেতর ডিরেক্ট চেক না করে রিমোট রিকোয়েস্ট সিঙ্ক করার জন্য 
    // মেমোরি ভেরিয়েবলের সাথে রি-ভ্যালিডেশন করা হলো
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
          onTap: () => setState(() => _showControls = !_showControls),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── ১. ভিডিও লেয়ার (Full Stretch) ──────────────────────
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
                  child: CircularProgressIndicator(color: Colors.white),
                ),

              // ── ২. টপ বার (চ্যানেল ইনফো ও ক্লোজ বাটন) ────────────────────────
              if (_showControls)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(86),
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

              // ── ৩. সেন্টার কন্ট্রোলস (চ্যানেল সুইচ < > এবং প্লে-পজ) ─────────────────
              if (_showControls)
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 32),
                        onPressed: () => _safeChannelSwitch(appState, -1),
                      ),
                      const SizedBox(width: 40),
                      GestureDetector(
                        onTap: _togglePlayPause,
                        child: Container(
                          width: 65,
                          height: 65,
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            initialized && !_isLoading && controller.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 32),
                        onPressed: () => _safeChannelSwitch(appState, 1),
                      ),
                    ],
                  ),
                ),

              // ── ৪. মোবাইল বটম কন্ট্রোল বার (LIVE ব্যাজ + প্রোগ্রেস বার) ──────────────
              if (_showControls && initialized && !_isLoading)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: Colors.black54,
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                            ),
                            onPressed: _togglePlayPause,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                CircleAvatar(radius: 3, backgroundColor: Colors.white),
                                SizedBox(width: 5),
                                Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.white, 
                                    fontSize: 10, 
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatDuration(controller.value.position),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
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
                bottom: _showControls ? 70 : 24,
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
