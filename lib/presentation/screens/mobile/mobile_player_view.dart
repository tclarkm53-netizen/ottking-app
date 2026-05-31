// lib/presentation/screens/mobile/mobile_player_view.dart


import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../providers/app_state.dart';

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

  // Volume / brightness drag
  double _dragStartY = 0;
  double _volume = 0.8;
  double _brightness = 0.8; // conceptual only — needs screen_brightness pkg
  bool _showVolume = false;
  bool _showBrightness = false;
  Timer? _overlayTimer;

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
    final newState = context.watch<AppState>();
    if (_appState != newState) {
      _appState = newState;
      // চ্যানেল পরিবর্তন হলে reload
      if (_appState!.currentChannel.id != _activeChannelId) {
        _initController();
      }
    }
  }

  void _enableWakelock() async {
    try {
      if (!await WakelockPlus.enabled) await WakelockPlus.enable();
    } catch (_) {}
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls) setState(() => _showControls = false);
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

    setState(() {
      _isLoading = true;
      _activeChannelId = channel.id;
    });

    // পুরনো controller dispose
    if (_controller != null) {
      final old = _controller!;
      _controller = null;
      if (_controllerListener != null) old.removeListener(_controllerListener!);
      try {
        await old.pause();
      } catch (_) {} finally {
        old.dispose();
      }
    }

    final ctrl = VideoPlayerController.networkUrl(
      Uri.parse(channel.streamUrl),
      videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: false),
      httpHeaders: const {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36',
        'Accept': '*/*',
        'Connection': 'keep-alive',
      },
    );

    try {
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      await ctrl.setVolume(_volume);
      await ctrl.play();
      _enableWakelock();

      _controllerListener = () {
        if (mounted) setState(() {});
      };
      ctrl.addListener(_controllerListener!);

      setState(() {
        _controller = ctrl;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _activeChannelId = null;
        });
        _showSnack('${channel.name} লোড হয়নি। পুনরায় চেষ্টা করুন।');
      }
    }
  }

  void _safeChannelSwitch(int direction) {
    if (_appState == null) return;
    setState(() {
      _showControls = true;
      _isLoading = true;
      _activeChannelId = null;
    });
    _startControlsTimer();
    _appState!.switchChannel(direction);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initController();
    });
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    setState(() {
      _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
      if (_controller!.value.isPlaying) _enableWakelock();
    });
    _startControlsTimer();
  }

  void _exitPlayer() {
    _controlsTimer?.cancel();
    _overlayTimer?.cancel();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // Volume drag (right half)
  void _onVerticalDragStart(DragStartDetails d) {
    _dragStartY = d.localPosition.dy;
    final screenW = MediaQuery.of(context).size.width;
    if (d.localPosition.dx > screenW / 2) {
      setState(() { _showVolume = true; _showBrightness = false; });
    } else {
      setState(() { _showBrightness = true; _showVolume = false; });
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    final delta = (_dragStartY - d.localPosition.dy) / 200;
    final screenW = MediaQuery.of(context).size.width;
    if (d.localPosition.dx > screenW / 2) {
      setState(() {
        _volume = (_volume + delta).clamp(0.0, 1.0);
        _controller?.setVolume(_volume);
        _dragStartY = d.localPosition.dy;
      });
    } else {
      setState(() {
        _brightness = (_brightness + delta).clamp(0.0, 1.0);
        _dragStartY = d.localPosition.dy;
      });
    }
  }

  void _onVerticalDragEnd(DragEndDetails _) {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() { _showVolume = false; _showBrightness = false; });
    });
  }

  String _fmt(Duration d) {
    if (d == Duration.zero || d.isNegative) return '00:00';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _overlayTimer?.cancel();
    WakelockPlus.disable();
    if (_controller != null && _controllerListener != null) {
      _controller!.removeListener(_controllerListener!);
    }
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_appState == null) return const Scaffold(backgroundColor: Colors.black);

    final ch = _appState!.currentChannel;
    final ctrl = _controller;
    final initialized = ctrl != null && ctrl.value.isInitialized;
    final isLive = ctrl?.value.duration == Duration.zero ||
        ctrl?.value.duration == null;
    final isPlaying = ctrl?.value.isPlaying == true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        // Swipe up = prev channel, swipe down = next channel
        onVerticalDragEnd: (d) {
          if (d.primaryVelocity == null) return;
          if (d.primaryVelocity! < -300) _safeChannelSwitch(-1); // swipe up
          if (d.primaryVelocity! > 300) _safeChannelSwitch(1);  // swipe down
        },
        // Volume / brightness via right/left edge drag
        onPanStart: _onVerticalDragStart,
        onPanUpdate: _onVerticalDragUpdate,
        onPanEnd: _onVerticalDragEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── ভিডিও ──
            if (initialized && !_isLoading)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: ctrl.value.size.width,
                    height: ctrl.value.size.height,
                    child: VideoPlayer(ctrl),
                  ),
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      ch.name,
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),

            // ── টপ গ্র্যাডিয়েন্ট + চ্যানেল নাম ──
            if (_showControls)
              Positioned(
                left: 0, right: 0, top: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 8, 12, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xCC000000), Colors.transparent],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 22),
                          onPressed: _exitPlayer,
                        ),
                        Expanded(
                          child: Text(
                            ch.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Quality badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.cyan.shade700,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ch.quality,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── সেন্টার play/pause + prev/next ──
            if (_showControls)
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CtrlBtn(
                      icon: Icons.skip_previous_rounded,
                      size: 36,
                      onTap: () => _safeChannelSwitch(-1),
                    ),
                    const SizedBox(width: 32),
                    GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.4), width: 2),
                        ),
                        child: Icon(
                          isPlaying && initialized && !_isLoading
                              ? Icons.pause
                              : Icons.play_arrow,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    _CtrlBtn(
                      icon: Icons.skip_next_rounded,
                      size: 36,
                      onTap: () => _safeChannelSwitch(1),
                    ),
                  ],
                ),
              ),

            // ── বটম বার ──
            if (_showControls && initialized && !_isLoading)
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 24, 12, 4),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xCC000000), Colors.transparent],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isLive)
                          Row(
                            children: [
                              Text(_fmt(ctrl.value.position),
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 11)),
                              Expanded(
                                child: VideoProgressIndicator(
                                  ctrl,
                                  allowScrubbing: true,
                                  colors: const VideoProgressColors(
                                    playedColor: Colors.red,
                                    bufferedColor: Colors.white24,
                                    backgroundColor: Colors.white12,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 10),
                                ),
                              ),
                              Text(_fmt(ctrl.value.duration),
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        Row(
                          children: [
                            if (isLive)
                              _LiveBadge()
                            else
                              IconButton(
                                icon: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                ),
                                onPressed: _togglePlayPause,
                              ),
                            const Spacer(),
                            // Swipe hint
                            const Icon(Icons.swap_vert,
                                color: Colors.white38, size: 16),
                            const SizedBox(width: 4),
                            const Text(
                              'Swipe চ্যানেল',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 10),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Volume overlay ──
            if (_showVolume)
              Positioned(
                right: 24,
                top: 0, bottom: 0,
                child: Center(
                  child: _VerticalSliderOverlay(
                    value: _volume,
                    icon: Icons.volume_up,
                    color: Colors.white,
                  ),
                ),
              ),

            // ── Brightness overlay ──
            if (_showBrightness)
              Positioned(
                left: 24,
                top: 0, bottom: 0,
                child: Center(
                  child: _VerticalSliderOverlay(
                    value: _brightness,
                    icon: Icons.brightness_6,
                    color: Colors.yellow,
                  ),
                ),
              ),

            // ── Toast ──
            if (_appState!.showToast)
              Positioned(
                left: 24, right: 24,
                bottom: _showControls ? 72 : 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.radar, color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _appState!.toastMessage,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Small helper widgets ──────────────────────────────────────────────────────

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  const _CtrlBtn(
      {required this.icon, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      );
}

class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 3, backgroundColor: Colors.white),
            SizedBox(width: 5),
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
      );
}

class _VerticalSliderOverlay extends StatelessWidget {
  final double value;
  final IconData icon;
  final Color color;
  const _VerticalSliderOverlay(
      {required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: RotatedBox(
                quarterTurns: 3,
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(value * 100).round()}%',
              style:
                  TextStyle(color: color, fontSize: 10),
            ),
          ],
        ),
      );
}
