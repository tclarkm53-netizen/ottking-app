// lib/presentation/screens/player_widgets/player_top_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

class PlayerTopPanel extends StatefulWidget {
  const PlayerTopPanel({
    super.key,
    required this.channel,
    required this.currentIndex,
    required this.totalChannels,
    required this.onSettings,
    this.typedNumber = '',
  });

  final dynamic channel;
  final int currentIndex;
  final int totalChannels;
  final VoidCallback onSettings;
  final String typedNumber; // নম্বর টাইপ হচ্ছে কিনা

  @override
  State<PlayerTopPanel> createState() => _PlayerTopPanelState();
}

class _PlayerTopPanelState extends State<PlayerTopPanel> {
  final FocusNode _settingsFocus = FocusNode(debugLabel: 'settings-btn');

  @override
  void dispose() {
    _settingsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isTyping = widget.typedNumber.isNotEmpty;

    return Stack(
      children: [
        // ========== TOP-LEFT: চ্যানেল নম্বার + নাম ==========
        Positioned(
          top: 20,
          left: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // চ্যানেল নম্বার বক্স (সবসময় দেখায়)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppTheme.primary.withOpacity(0.6)),
                ),
                child: Row(
                  children: [
                    Text(
                      'CH ',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      isTyping
                          ? widget.typedNumber
                          : '${widget.currentIndex + 1}',
                      style: TextStyle(
                        color: isTyping ? Colors.yellow : AppTheme.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // চ্যানেল নাম বক্স — শুধু typing না হলে দেখায়
              AnimatedOpacity(
                opacity: isTyping ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: isTyping,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 220),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Text(
                      widget.channel.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ========== TOP-RIGHT: সেটিংস আইকন (focusable) ==========
        Positioned(
          top: 20,
          right: 20,
          child: Focus(
            focusNode: _settingsFocus,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.select ||
                      event.logicalKey == LogicalKeyboardKey.space)) {
                widget.onSettings();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Builder(
              builder: (ctx) {
                final focused = Focus.of(ctx).hasFocus;
                return GestureDetector(
                  onTap: widget.onSettings,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: focused
                          ? AppTheme.primary.withOpacity(0.25)
                          : Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: focused
                            ? AppTheme.primary
                            : Colors.white.withOpacity(0.15),
                        width: focused ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      Icons.settings_rounded,
                      color:
                          focused ? AppTheme.primary : Colors.white70,
                      size: 28,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
