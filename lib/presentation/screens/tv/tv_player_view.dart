// lib/presentation/screens/tv/tv_player_view.dart


import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../providers/app_state.dart';

class TvPlayerView extends StatefulWidget {
  const TvPlayerView({super.key});

  @override
  State<TvPlayerView> createState() => _TvPlayerViewState();
}

class _TvPlayerViewState extends State<TvPlayerView> {
  final FocusNode _rootFocus = FocusNode(debugLabel: 'tv-root');

  VideoPlayerController? _controller;
  VoidCallback? _controllerListener;
  String? _activeChannelId;

  bool _showControls = true;
  bool _isLoading = false;

  AppState? _appState;

  Timer? _controlsTimer;
  String _typedNumber = '';
  Timer? _numberTimer;

  // Channel strip scroll
  final ScrollController _stripScroll = ScrollController();

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
      if (_appState!.currentChannel.id != _activeChannelId) {
        _initController();
      }
    }
  }

  void _enableWakelock() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      if (!await WakelockPlus.enabled) await WakelockPlus.enable();
    } catch (_) {}
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _showControls && _typedNumber.isEmpty) {
        setState(() => _showControls = false);
      }
    });
  }

  void _showControlsNow() {
    setState(() => _showControls = true);
    _startControlsTimer();
  }

  Future<void> _initController() async {
    if (!mounted || _appState == null) return;
    final channel = _appState!.currentChannel;
    if (_activeChannelId == channel.id && _controller != null) return;

    setState(() {
      _isLoading = true;
      _activeChannelId = channel.id;
    });

    if (_controller != null) {
      final old = _controller!;
      _controller = null;
      if (_controllerListener != null) old.removeListener(_controllerListener!);
      try {
        await old.setVolume(0);
        if (old.value.isPlaying) await old.pause();
      } catch (_) {} finally {
        old.dispose();
      }
    }

    final ctrl = VideoPlayerController.networkUrl(
      Uri.parse(channel.streamUrl),
      videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: false),
      httpHeaders: const {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
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

      // channel strip scroll to current
      _scrollStripToCurrent();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _activeChannelId = null;
        });
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

  void _scrollStripToCurrent() {
    if (_appState == null) return;
    final idx = _appState!.currentChannelIndex;
    final offset = idx * 110.0 - 200;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_stripScroll.hasClients) {
        _stripScroll.animateTo(
          offset.clamp(0, _stripScroll.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Remote key handler ────────────────────────────────────────────────────
  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    _showControlsNow();

    final key = event.logicalKey;

    // ── Number keys: direct channel jump ──
    final label = key.keyLabel;
    if (RegExp(r'^[0-9]$').hasMatch(label)) {
      _numberTimer?.cancel();
      setState(() { _typedNumber += label; });
      _numberTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted && _typedNumber.isNotEmpty) {
          final num = int.tryParse(_typedNumber);
          if (num != null &&
              num > 0 &&
              num <= (_appState?.channels.length ?? 0)) {
            _appState!.selectChannelByIndex(num - 1);
            _initController();
          }
          setState(() => _typedNumber = '');
          _startControlsTimer();
        }
      });
      return;
    }

    // ── Navigation ──
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.channelUp) {
      _safeChannelSwitch(-1);
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.channelDown) {
      _safeChannelSwitch(1);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      // Left → show controls only (or exit if already showing)
      if (!_showControls) {
        _showControlsNow();
      } else {
        _exitPlayer();
      }
    } else if (key == LogicalKeyboardKey.arrowRight) {
      // Right → info / next channel
      _safeChannelSwitch(1);
    }

    // ── Confirm / Play-Pause ──
    else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlay ||
        key == LogicalKeyboardKey.mediaPause ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      _togglePlayPause();
    }

    // ── Media fast keys ──
    else if (key == LogicalKeyboardKey.mediaFastForward ||
        key == LogicalKeyboardKey.mediaTrackNext) {
      _safeChannelSwitch(1);
    } else if (key == LogicalKeyboardKey.mediaRewind ||
        key == LogicalKeyboardKey.mediaTrackPrevious) {
      _safeChannelSwitch(-1);
    }

    // ── Back / Exit ──
    else if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      _exitPlayer();
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    setState(() {
      _controller!.value.isPlaying
          ? _controller!.pause()
          : _controller!.play();
      if (_controller!.value.isPlaying) _enableWakelock();
    });
    _startControlsTimer();
  }

  void _exitPlayer() {
    _controlsTimer?.cancel();
    _numberTimer?.cancel();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _numberTimer?.cancel();
    WakelockPlus.disable();
    if (_controller != null && _controllerListener != null) {
      _controller!.removeListener(_controllerListener!);
    }
    _controller?.dispose();
    _rootFocus.dispose();
    _stripScroll.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_appState == null) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final ch = _appState!.currentChannel;
    final ctrl = _controller;
    final initialized = ctrl != null && ctrl.value.isInitialized;
    final isPlaying = ctrl?.value.isPlaying == true;

    return KeyboardListener(
      focusNode: _rootFocus,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () => _showControls
              ? setState(() => _showControls = false)
              : _showControlsNow(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── ১. ভিডিও ──
              if (initialized && !_isLoading)
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.fill,
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
                      const SizedBox(
                        width: 64,
                        height: 64,
                        child: CircularProgressIndicator(
                          color: Colors.cyan,
                          strokeWidth: 5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        ch.name,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'লোড হচ্ছে...',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 14),
                      ),
                    ],
                  ),
                ),

              // ── ২. টপ OSD বার ──
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: Positioned(
                  left: 0, right: 0, top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 18),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xDD000000), Colors.transparent],
                      ),
                    ),
                    child: Row(
                      children: [
                        // Channel number + name
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.cyan.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.cyan.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.live_tv,
                                  color: Colors.cyan, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                '${_appState!.currentChannelIndex + 1}  •  ${ch.name}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Quality badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.cyan.shade800,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            ch.quality,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Exit button
                        _TvFocusButton(
                          onPressed: _exitPlayer,
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 28),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── ৩. সেন্টার কন্ট্রোল (prev / play-pause / next) ──
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TvFocusButton(
                        onPressed: () => _safeChannelSwitch(-1),
                        tooltip: 'আগের চ্যানেল (↑)',
                        child: const Icon(Icons.skip_previous,
                            color: Colors.white, size: 44),
                      ),
                      const SizedBox(width: 48),
                      _TvFocusButton(
                        onPressed: _togglePlayPause,
                        large: true,
                        tooltip: 'Play / Pause (OK)',
                        child: Icon(
                          isPlaying && initialized && !_isLoading
                              ? Icons.pause
                              : Icons.play_arrow,
                          color: Colors.white,
                          size: 54,
                        ),
                      ),
                      const SizedBox(width: 48),
                      _TvFocusButton(
                        onPressed: () => _safeChannelSwitch(1),
                        tooltip: 'পরের চ্যানেল (↓)',
                        child: const Icon(Icons.skip_next,
                            color: Colors.white, size: 44),
                      ),
                    ],
                  ),
                ),
              ),

              // ── ৪. বটম চ্যানেল স্ট্রিপ ──
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xEE000000), Colors.transparent],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Remote hint
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                          child: Row(
                            children: [
                              _RemoteHint(
                                  icon: Icons.keyboard_arrow_up,
                                  label: 'আগের'),
                              const SizedBox(width: 20),
                              _RemoteHint(
                                  icon: Icons.keyboard_arrow_down,
                                  label: 'পরের'),
                              const SizedBox(width: 20),
                              _RemoteHint(
                                  icon: Icons.adjust, label: 'OK = Play'),
                              const SizedBox(width: 20),
                              _RemoteHint(
                                  icon: Icons.arrow_back, label: 'Back'),
                              const Spacer(),
                              const Text(
                                '🔢 সরাসরি নম্বর টাইপ করুন',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 11),
                              ),
                              const SizedBox(width: 16),
                            ],
                          ),
                        ),

                        // Channel strip
                        SizedBox(
                          height: 72,
                          child: ListView.builder(
                            controller: _stripScroll,
                            scrollDirection: Axis.horizontal,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _appState!.channels.length,
                            itemBuilder: (ctx, i) {
                              final c = _appState!.channels[i];
                              final isCurrent =
                                  i == _appState!.currentChannelIndex;
                              return GestureDetector(
                                onTap: () {
                                  _appState!.selectChannelByIndex(i);
                                  _initController();
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 100,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? Colors.cyan.withOpacity(0.25)
                                        : Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isCurrent
                                          ? Colors.cyan
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${i + 1}',
                                        style: TextStyle(
                                          color: isCurrent
                                              ? Colors.cyan
                                              : Colors.white38,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        c.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isCurrent
                                              ? Colors.white
                                              : Colors.white70,
                                          fontSize: 11,
                                          fontWeight: isCurrent
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),

              // ── ৫. Number OSD overlay ──
              if (_typedNumber.isNotEmpty)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.88),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: Colors.cyan, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyan.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _typedNumber,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 80,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _typedNumber.isNotEmpty &&
                                  int.tryParse(_typedNumber) != null &&
                                  int.parse(_typedNumber) > 0 &&
                                  int.parse(_typedNumber) <=
                                      (_appState?.channels.length ?? 0)
                              ? _appState!.channels[
                                      int.parse(_typedNumber) - 1]
                                  .name
                              : 'চ্যানেল নেই',
                          style: const TextStyle(
                            color: Colors.cyan,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── ৬. Toast ──
              if (_appState!.showToast)
                Positioned(
                  left: 40, right: 40,
                  bottom: _showControls ? 100 : 32,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.radar,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _appState!.toastMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
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

// ── TV Focus Button ───────────────────────────────────────────────────────────

class _TvFocusButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final bool large;
  final String? tooltip;

  const _TvFocusButton({
    required this.onPressed,
    required this.child,
    this.large = false,
    this.tooltip,
  });

  @override
  State<_TvFocusButton> createState() => _TvFocusButtonState();
}

class _TvFocusButtonState extends State<_TvFocusButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.large ? 88.0 : 68.0;
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Tooltip(
          message: widget.tooltip ?? '',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _focused
                  ? Colors.cyan.withOpacity(0.3)
                  : Colors.black.withOpacity(0.45),
              border: Border.all(
                color: _focused ? Colors.cyan : Colors.white24,
                width: _focused ? 3 : 1.5,
              ),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: Colors.cyan.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// ── Remote hint chip ─────────────────────────────────────────────────────────

class _RemoteHint extends StatelessWidget {
  final IconData icon;
  final String label;
  const _RemoteHint({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white38, size: 14),
          const SizedBox(width: 3),
          Text(label,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      );
}
