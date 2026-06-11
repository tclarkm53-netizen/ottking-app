// lib/presentation/widgets/tv_focus_card.dart
// Reusable TV remote–focusable card with glow effect

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // LogicalKeyboardKey ব্যবহারের জন্য এটি প্রয়োজন
import '../../core/theme/app_theme.dart';

class TvFocusCard extends StatefulWidget {
  const TvFocusCard({
    super.key,
    required this.onTap,
    required this.child,
    this.focusNode,
    this.selected = false,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = 14.0,
  });

  final VoidCallback onTap;
  final Widget child;
  final FocusNode? focusNode;
  final bool selected;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  State<TvFocusCard> createState() => _TvFocusCardState();
}

class _TvFocusCardState extends State<TvFocusCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final active = _focused || widget.selected;
    
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (v) => setState(() => _focused = v),
      // ── টিভি রিমোটের OK / Center বাটন হ্যান্ডেল করার লজিক ──
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          // বিভিন্ন অ্যান্ড্রয়েড টিভি রিমোটের OK বাটন ডিটেকশন
          if (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.dpadCenter) {
            widget.onTap(); // চ্যানেল প্লে করার মেথড ট্রিগার করবে
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap, // মোবাইল বা টাচ টেস্টের জন্য ব্যাকআপ হিসেবে থাকলো
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: _focused
                ? AppTheme.cardLight
                : widget.selected
                    ? AppTheme.card
                    : AppTheme.card,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: active ? AppTheme.primary : AppTheme.border,
              width: active ? 2 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.35),
                      blurRadius: 18,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          // টিভি অ্যাপের প্রিমিয়াম ফিলের জন্য ফোকাসড অবস্থায় সামান্য স্কেল (বড়) হবে
          child: Transform.scale(
            scale: _focused ? 1.04 : 1.0,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
