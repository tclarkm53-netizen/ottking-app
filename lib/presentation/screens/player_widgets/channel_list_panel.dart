// lib/presentation/screens/player_widgets/channel_list_panel.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ChannelListPanel extends StatelessWidget {
  const ChannelListPanel({
    required this.channels,
    required this.currentIndex,
    required this.onSelect,
    required this.onClose,
  });

  final List channels;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.92),
          border: Border(
              left: BorderSide(
                  color: AppTheme.primary.withOpacity(0.3), width: 1)),
        ),
        child: Column(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.list_rounded,
                      color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  const Text('চ্যানেল লিস্ট',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white38, size: 18),
                      onPressed: onClose),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: channels.length,
                itemBuilder: (ctx, i) {
                  final ch = channels[i];
                  final active = i == currentIndex;
                  return GestureDetector(
                    onTap: () => onSelect(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      color: active
                          ? AppTheme.primary.withOpacity(0.15)
                          : Colors.transparent,
                      child: Row(
                        children: [
                          Text(
                            '${i + 1}'.padLeft(3),
                            style: TextStyle(
                              color: active
                                  ? AppTheme.primary
                                  : Colors.white38,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              ch.name,
                              style: TextStyle(
                                color: active
                                    ? Colors.white
                                    : Colors.white60,
                                fontSize: 14,
                                fontWeight: active
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (active)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
