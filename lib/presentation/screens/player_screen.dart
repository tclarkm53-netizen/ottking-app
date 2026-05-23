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

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    final appState = context.read<AppState>();
    final url = appState.currentChannel.streamUrl;

    _controller?.dispose();
    _controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await _controller!.initialize();
    await _controller!.play();

    if (!mounted) {
      return;
    }

    _activeChannelId = appState.currentChannel.id;
    setState(() {});
  }

  void _syncControllerIfNeeded(AppState appState) {
    if (_activeChannelId == appState.currentChannel.id) {
      return;
    }

    _activeChannelId = appState.currentChannel.id;
    _initController();
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
    _syncControllerIfNeeded(appState);
    final controller = _controller;

    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: (event) {
        if (event is! RawKeyDownEvent) {
          return;
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          appState.switchChannel(-1);
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          appState.switchChannel(1);
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          Navigator.pushNamed(context, '/home');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (controller != null && controller.value.isInitialized)
              Positioned.fill(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
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
                    color: Colors.black.withOpacity(0.78),
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
            Positioned(
              left: 24,
              top: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${appState.currentChannel.name} • ${appState.currentChannel.quality}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
