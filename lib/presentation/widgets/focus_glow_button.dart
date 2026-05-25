// lib/presentation/widgets/focus_glow_button.dart

import 'package:flutter/material.dart';

class FocusGlowButton extends StatefulWidget {
  const FocusGlowButton({
    super.key,
    required this.label,
    required this.icon, 
    required this.onTap,
    this.trailing,
    this.selected = false,
    this.isTV = false, // টিভি নাকি মোবাইল তা নির্ধারণ করার ফ্ল্যাগ
  });

  final String label;
  final dynamic icon; 
  final VoidCallback onTap;
  final Widget? trailing;
  final bool selected;
  final bool isTV;

  @override
  State<FocusGlowButton> createState() => _FocusGlowButtonState();
}

class _FocusGlowButtonState extends State<FocusGlowButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = widget.selected || _focused;

    // লোগো ইমেজ বা আইকন সাইজিং এবং শেপ (ইমেজের মতো গোল করার জন্য ClipRRect ব্যবহার করা হয়েছে)
    Widget logoWidget;
    if (widget.icon is Widget) {
      logoWidget = Container(
        width: widget.isTV ? 48 : 56,
        height: widget.isTV ? 48 : 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white, // লোগোর ব্যাকগ্রাউন্ড সাদা
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
            )
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: widget.icon as Widget,
        ),
      );
    } else {
      logoWidget = Icon(
        widget.icon is IconData ? widget.icon as IconData : Icons.play_circle_outline, 
        color: theme.colorScheme.primary,
        size: widget.isTV ? 32 : 40,
      );
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
                : const Color(0xFF1E293B), // ইমেজের মতো ডার্ক কার্ড কালার
            borderRadius: BorderRadius.circular(24), // ইমেজের মতো সুন্দর রাউন্ডেড কর্নার
            border: Border.all(
              color: active
                  ? const Color(0xFF06B6D4) // ইমেজের মতো উজ্জ্বল সায়ান/ব্লু গ্লো বর্ডার
                  : Colors.white.withAlpha(15),
              width: active ? 2.5 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFF06B6D4).withAlpha(100), // সায়ান গ্লো ইফেক্ট
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(16),
                // ── হুবহু ইমেজ UI কন্ডিশন ──────────────────────────────────────────
                child: widget.isTV
                    ? Row(
                        // টিভি মোড: বামে লোগো, ডানে লেখা
                        children: [
                          logoWidget,
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  widget.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.trailing != null) widget.trailing!,
                        ],
                      )
                    : Column(
                        // মোবাইল মোড: উপরে লোগো, নিচে লেখা
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          logoWidget,
                          const SizedBox(height: 12),
                          Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
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
