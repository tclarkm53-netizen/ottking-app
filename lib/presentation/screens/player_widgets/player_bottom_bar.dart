// lib/presentation/screens/player_widgets/player_bottom_bar.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_theme.dart';

class PlayerBottomBar extends StatelessWidget {
  const PlayerBottomBar({
    required this.ctrl,
    required this.isLive,
    required this.liveBlink,
    required this.onPlayPause,
    required this.onExit,
  });

  final VideoPlayerController ctrl;
  final bool isLive;
  final bool liveBlink;
  final VoidCallback onPlayPause;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.85), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            // প্লে/পজ বোতাম
            IconButton(
              icon: Icon(
                ctrl.value.isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                color: Colors.white,
                size: 36,
              ),
              onPressed: onPlayPause,
            ),
            const SizedBox(width: 12),

            // LIVE ব্লিংকিং ব্যাজ
            if (isLive)
              AnimatedOpacity(
                opacity: liveBlink ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(radius: 3, backgroundColor: Colors.white),
                      SizedBox(width: 6),
                      Text('LIVE',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),

            const Spacer(),

            // এক্সিট বোতাম
            IconButton(
              icon: const Icon(Icons.exit_to_app_rounded,
                  color: Colors.white70, size: 24),
              onPressed: onExit,
              tooltip: 'এক্সিট',
            ),
          ],
        ),
      ),
    );
  }
}
