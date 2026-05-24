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
  bool _isLoading = false;
  bool _showChannelListPanel = false; 

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
    
    // read ব্যবহার করা হয়েছে বিল্ড এরর এড়াতে
    final appState = context.read<AppState>();
    final channel = appState.currentChannel;

    if (_activeChannelId == channel.id) return;

    setState(() {
      _isLoading = true;
      _activeChannelId = channel.id;
    });

    if (_controller != null) {
      final oldCtrl = _controller!;
      _controller = null;
      try {
        await oldCtrl.pause();
      } catch (_) {}
      await oldCtrl.dispose();
    }

    final newController =
        VideoPlayerController.networkUrl(Uri.parse(channel.streamUrl));

    try {
      await newController.initialize();
      
      if (!mounted) {
        await newController.dispose();
        return;
      }

      await newController.play();
      
      newController.addListener(() {
        if (mounted) setState(() {});
      });

      setState(() {
        _controller = newController;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Video initialization failed: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _activeChannelId = null;
        });
        
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${channel.name} অফলাইন। অন্য চ্যানেল চেষ্টা করুন।'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // প্রোভাইডার সেটার অ্যাকশনকে মাইক্রোপ্রসেস বা মাইক্রোটাাস্ক সেফ জোনে নেওয়া হয়েছে
  void _onChannelSelected(AppState appState, int index) {
    setState(() {
      _isLoading = true;
      _activeChannelId = null;
      _showChannelListPanel = false; // ওটিটি ইউজার এক্সপেরিয়েন্সের জন্য চ্যানেল সিলেক্ট হলে প্যানেল হাইড হবে
    });
    
    // WidgetsBinding বা Microtask দিয়ে মেইন থ্রেড ফ্রী করে প্রোভাইডার আপডেট করা হলো
    Future.microtask(() {
      appState.switchChannelTo(index); // AppState-এ switchChannelTo(int index) মেথডটি ব্যবহার করা বেস্ট প্র্যাকটিস
    });
  }

  void _safeChannelSwitch(AppState appState, int direction) {
    setState(() {
      _isLoading = false;
      _activeChannelId = null;
    });
    appState.switchChannel(direction);
  }

  void _handleKey(KeyEvent event, AppState appState) {
    if (event is! KeyDownEvent) return;
    
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      setState(() => _showChannelListPanel = true);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      setState(() => _showChannelListPanel = false);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _safeChannelSwitch(appState, -1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _safeChannelSwitch(appState, 1);
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_showChannelListPanel) {
        setState(() => _showChannelListPanel = false);
      } else {
        _exitPlayer();
      }
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

    // ফাস্ট চ্যানেল জেনারেট ট্র্যাকিং এরর হ্যান্ডলিং
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
          onTap: () {
            setState(() {
              _showControls = !_showControls;
              if (!_showControls) _showChannelListPanel = false;
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── ১. ফুল স্ক্রিন ভিডিও লেয়ার ────────────────────────────────
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

              // ── ২. ওটিটি টপ কন্ট্রোল বার ──────────────────────────────────
              if (_showControls)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black87, Colors.transparent],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: _exitPlayer,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                appState.currentChannel.name,
                                style: const TextStyle(
                                  color: Colors.white, 
                                  fontSize: 18, 
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(
                              _showChannelListPanel ? Icons.featured_play_list : Icons.featured_play_list_outlined, 
                              color: Colors.white
                            ),
                            onPressed: () {
                              setState(() => _showChannelListPanel = !_showChannelListPanel);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── ৩. বটম প্লে বার (LIVE ইন্ডিকেটর + টাইম ট্র্যাকিং) ──────────────
              if (_showControls && initialized && !_isLoading)
                Positioned(
                  left: 0,
                  right: _showChannelListPanel ? 320 : 0, 
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withAlpha(242)], 
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                              color: Colors.white,
                              size: 36,
                            ),
                            onPressed: _togglePlayPause,
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _formatDuration(controller.value.position),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Expanded(
                            child: VideoProgressIndicator(
                              controller,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(
                                playedColor: Colors.red,
                                bufferedColor: Colors.white30,
                                backgroundColor: Colors.white12,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white30),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              appState.currentChannel.quality,
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── ৪. প্রিমিয়াম সার্ভার সাইড চ্যানেল লিস্ট প্যানেল ───────
              if (_showChannelListPanel)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 300,
                    color: Colors.black.withAlpha(225), 
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Text(
                              'চ্যানেল লিস্ট (${appState.channels.length})',
                              style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const Divider(color: Colors.white10),
                        Expanded(
                          child: ListView.builder(
                            itemCount: appState.channels.length,
                            itemBuilder: (context, index) {
                              final ch = appState.channels[index];
                              final isCurrent = appState.currentChannelIndex == index;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: InkWell(
                                  onTap: () => _onChannelSelected(appState, index), // ফিক্সড মেথড কল
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isCurrent ? Colors.red.withAlpha(50) : Colors.white.withAlpha(10),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isCurrent ? Colors.red : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 45,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: Colors.black45,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: Image.network(
                                              ch.logoUrl ?? '', 
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) {
                                                return const Icon(Icons.live_tv, color: Colors.white38, size: 18);
                                              },
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            ch.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                        if (isCurrent)
                                          const Icon(Icons.play_arrow_rounded, color: Colors.red, size: 20),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── ৫. INFO TOAST ──
              if (appState.showToast)
                Positioned(
                  left: 24,
                  bottom: 80,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      appState.toastMessage,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}                              Text(
                                appState.currentChannel.name,
                                style: const TextStyle(
                                  color: Colors.white, 
                                  fontSize: 18, 
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ],
                          ),
                          // সাইড লিস্ট ওপেন করার কুইক বাটন ইন্ডিকেটর
                          IconButton(
                            icon: Icon(
                              _showChannelListPanel ? Icons.featured_play_list : Icons.featured_play_list_outlined, 
                              color: Colors.white
                            ),
                            onPressed: () {
                              setState(() => _showChannelListPanel = !_showChannelListPanel);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── ৩. বটম প্লে বার (LIVE ইন্ডিকেটর + টাইম ট্র্যাকিং) ──────────────
              if (_showControls && initialized && !_isLoading)
                Positioned(
                  left: 0,
                  right: _showChannelListPanel ? 320 : 0, // সাইড প্যানেল অন থাকলে বটম বার ছোট হবে
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withAlpha(242)], // ফিক্সড: Colors.black95 পরিবর্তন করে আলফা দেওয়া হয়েছে
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                              color: Colors.white,
                              size: 36,
                            ),
                            onPressed: _togglePlayPause,
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _formatDuration(controller.value.position),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Expanded(
                            child: VideoProgressIndicator(
                              controller,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(
                                playedColor: Colors.red,
                                bufferedColor: Colors.white30,
                                backgroundColor: Colors.white12,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white30),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              appState.currentChannel.quality,
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── ৪. প্রিমিয়াম সার্ভার সাইড চ্যানেল লিস্ট প্যানেল (ডান পাশে আসবে) ───────
              if (_showChannelListPanel)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 300,
                    color: Colors.black.withAlpha(225), // ট্রান্সপারেন্ট ব্ল্যাক ব্যাকগ্রাউন্ড
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Text(
                              'চ্যানেল লিস্ট (${appState.channels.length})',
                              style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const Divider(color: Colors.white10),
                        Expanded(
                          child: ListView.builder(
                            itemCount: appState.channels.length,
                            itemBuilder: (context, index) {
                              final ch = appState.channels[index];
                              final isCurrent = appState.currentChannelIndex == index;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      // প্রোভাইডার মেথড বা স্টেট হ্যান্ডলিং সেফ জোনে রাখা হয়েছে
                                      appState.currentChannelIndex = index;
                                      _isLoading = true;
                                      _activeChannelId = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isCurrent ? Colors.red.withAlpha(50) : Colors.white.withAlpha(10),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isCurrent ? Colors.red : Colors.transparent,
                                        width: 1.5
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // ── সার্ভার চ্যানেল লোগো নেটওয়ার্ক ইমেজ ──
                                        Container(
                                          width: 45,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: Colors.black45,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: Image.network(
                                              ch.logoUrl ?? '', 
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) {
                                                return const Icon(Icons.live_tv, color: Colors.white38, size: 18);
                                              },
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // ── চ্যানেলের নাম ──
                                        Expanded(
                                          child: Text(
                                            ch.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                        if (isCurrent)
                                          const Icon(Icons.play_arrow_rounded, color: Colors.red, size: 20),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── ৫. INFO TOAST ──
              if (appState.showToast)
                Positioned(
                  left: 24,
                  bottom: 80,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      appState.toastMessage,
                      style: const TextStyle(color: Colors.white),
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
