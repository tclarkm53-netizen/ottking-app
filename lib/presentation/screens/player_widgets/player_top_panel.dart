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
  final String typedNumber;

  @override
  State<PlayerTopPanel> createState() => _PlayerTopPanelState();
}

class _PlayerTopPanelState extends State<PlayerTopPanel> {
  final FocusNode _settingsFocus = FocusNode(debugLabel: 'settings-btn');
  bool _isSettingsFocused = false; // সেটিংস বাটনের ফোকাস ট্র্যাক করার জন্য

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
        // ========== TOP-LEFT: একক চ্যানেল কার্ড (নম্বর + নাম) ==========
        Positioned(
          top: 20,
          left: 20,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isTyping 
                    ? Colors.yellow.withOpacity(0.8) // টাইপ করার সময় বর্ডার হলুদ হবে
                    : AppTheme.primary.withOpacity(0.6),
                width: isTyping ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // "CH " টেক্সট
                Text(
                  'CH ',
                  style: TextStyle(
                    color: isTyping ? Colors.yellow.withOpacity(0.7) : Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                
                // চ্যানেল নম্বর (টাইপ করলে টাইপ করা সংখ্যা, নাহলে কারেন্ট ইনডেক্স)
                Text(
                  isTyping ? widget.typedNumber : '${widget.currentIndex + 1}',
                  style: TextStyle(
                    color: isTyping ? Colors.yellow : AppTheme.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),

                // চ্যানেল নাম (শুধুমাত্র টাইপ না করলে এই অংশটুকু কার্ডের ভেতর ঢুকবে)
                if (!isTyping) ...[
                  const SizedBox(width: 12),
                  // একটি ছোট ভার্টিক্যাল ডিভাইডার লাইন (দেখতে সুন্দর লাগবে)
                  Container(
                    height: 18,
                    width: 1,
                    color: Colors.white24,
                  ),
                  const SizedBox(width: 12),
                  
                  // মূল চ্যানেলের নাম
                  Text(
                    widget.channel.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),

        // ========== TOP-RIGHT: সেটিংস আইকন (focusable) ==========
        Positioned(
          top: 20,
          right: 20,
          child: Focus(
            focusNode: _settingsFocus,
            onFocusChange: (hasFocus) {
              setState(() {
                _isSettingsFocused = hasFocus;
              });
            },
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
            child: GestureDetector(
              onTap: widget.onSettings,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isSettingsFocused
                      ? AppTheme.primary.withOpacity(0.25)
                      : Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isSettingsFocused
                        ? AppTheme.primary
                        : Colors.white.withOpacity(0.15),
                    width: _isSettingsFocused ? 2 : 1,
                  ),
                ),
                child: Icon(
                  Icons.settings_rounded,
                  color: _isSettingsFocused ? AppTheme.primary : Colors.white70,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
