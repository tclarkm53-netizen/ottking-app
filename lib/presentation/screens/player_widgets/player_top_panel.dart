// lib/presentation/screens/player_widgets/player_top_panel.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class PlayerTopPanel extends StatelessWidget {
  const PlayerTopPanel({
    required this.channel,
    required this.currentIndex,
    required this.totalChannels,
    required this.onSettings,
  });

  final dynamic channel;
  final int currentIndex;
  final int totalChannels;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 20,
      right: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // চ্যানেল নম্বার এবং নাম
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'CH ${currentIndex + 1}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  channel.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // সেটিংস বোতাম
          IconButton(
            icon: const Icon(Icons.settings_rounded,
                color: Colors.white70, size: 28),
            onPressed: onSettings,
            tooltip: 'সেটিংস',
          ),
        ],
      ),
    );
  }
}
