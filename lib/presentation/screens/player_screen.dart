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
    WidgetsBinding.instance.addPostFrameCallback((_) => _initController());
  }

  Future<void> _initController() async {
    final appState = context.read<AppState>();
    final channel = appState.currentChannel;

    if (_activeChannelId == channel.id) return;

    final oldController = _controller;
    final newController =
        VideoPlayerController.networkUrl(Uri.parse(channel.streamUrl));

    await newController.initialize();
    await newController.play();

    if (!mounted) {
      newController.dispose();
      return;
    }

    setState(() {
      _controller = newController;
      _activeChannelId = channel.id;
    });

    oldController?.dispose();
  }

  void _handleKey(KeyEvent event, AppState appState) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      appState.switchChannel(-1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      appState.switchChannel(1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pushReplacementNamed(context, '/home');
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

  @override
  void dispose() {
    _controller?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    // If the channel changed externally (e.g. TV remote), reload.
    if (_activeChannelId != null &&
        _activeChannelId != appState.currentChannel.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initController());
    }

    final controller = _controller;
    final initialized =
        controller != null && controller.value.isInitialized;

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
              // ── Video ─────────────────────────────────────────────────────
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

              // ── Top bar: channel name + quality ───────────────────────────
              AnimatedOpacity(
                opacity: _showControls ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SafeArea(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.live_tv,
                                color: Colors.red, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              '${appState.currentChannel.name}  •  ${appState.currentChannel.quality}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Play / pause overlay ──────────────────────────────────────
              AnimatedOpacity(
                opacity: _showControls ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: Center(
                  child: GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        initialized && controller.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Back button ───────────────────────────────────────────────
              AnimatedOpacity(
                opacity: _showControls ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: Positioned(
                  right: 16,
                  top: 0,
                  child: SafeArea(
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/home'),
                    ),
                  ),
                ),
              ),

              // ── Channel-switch toast ───────────────────────────────────────
              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
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
