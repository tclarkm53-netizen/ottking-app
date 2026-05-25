// lib/presentation/widgets/focus_glow_button.dart

import 'package:flutter/material.dart';

class FocusGlowButton extends StatefulWidget {
  const FocusGlowButton({
    super.key,
    required this.label,
    required this.icon, // এটি এখন IconData অথবা Widget দুটাই নিতে পারবে
    required this.onTap,
    this.trailing,
    this.selected = false,
  });

  final String label;
  final dynamic icon; // IconData এবং Widget দুইটাই হ্যান্ডেল করার জন্য dynamic করা হলো
  final VoidCallback onTap;
  final Widget? trailing;
  final bool selected;

  @override
  State<FocusGlowButton> createState() => _FocusGlowButtonState();
}

class _FocusGlowButtonState extends State<FocusGlowButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = widget.selected || _focused;

    // আইকন নাকি কাস্টম ইমেজ উইজেট পাঠানো হয়েছে তা চেক করার লজিক
    Widget iconWidget;
    if (widget.icon is IconData) {
      iconWidget = Icon(widget.icon as IconData, color: theme.colorScheme.primary);
    } else if (widget.icon is Widget) {
      iconWidget = SizedBox(
        width: 40, // লোগোর জন্য পারফেক্ট সাইজ
        height: 40,
        child: widget.icon as Widget,
      );
    } else {
      iconWidget = Icon(Icons.play_circle_outline, color: theme.colorScheme.primary);
    }

    return Focus(
      onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: active
                ? theme.colorScheme.primary.withAlpha(26)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? theme.colorScheme.primary
                  : Colors.white.withAlpha(26),
              width: active ? 2 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withAlpha(89),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 18,
                ),
                child: Row(
                  children: [
                    // এখানে আমাদের প্রিপেয়ার্ড আইকন/লোগো উইজেটটি বসানো হলো
                    iconWidget,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (widget.trailing != null) widget.trailing!,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
