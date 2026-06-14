// lib/presentation/widgets/tv_focus_card.dart
// Reusable TV remote–focusable card with glow effect

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class TvFocusCard extends StatefulWidget {
  const TvFocusCard({
    super.key,
    required this.onTap,
    required this.child,
    this.focusNode,
    this.onFocusChange, // ChannelGrid থেকে পাঠানো স্ক্রোল লজিক রিসিভ করার জন্য
    this.selected = false,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = 14.0,
  });

  final VoidCallback onTap;
  final Widget child;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChange; // যুক্ত করা হলো
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
    
    // প্রিমিয়াম অ্যানিমেশন ইফেক্টের জন্য পুরো উইজেটকে স্কেল করা হলো
    return AnimatedScale(
      scale: _focused ? 1.05 : 1.0, // ফোকাস হলে পুরো কার্ড ৫% বড় হবে
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      child: InkWell(
        focusNode: widget.focusNode,
        autofocus: false,
        // টিভিতে ফোকাস চেঞ্জ হলে আমাদের লোকাল স্টেট এবং প্যারামিটারের স্টেট দুটাই আপডেট হবে
        onFocusChange: (v) {
          setState(() => _focused = v);
          if (widget.onFocusChange != null) {
            widget.onFocusChange!(v); // এটি ChannelGrid এর অটো-স্ক্রোল চালু রাখবে
          }
        },
        // InkWell ব্যবহার করায় টিভির রিমোটের OK বাটন চাপলে এটি ১০০% কাজ করবে
        onTap: widget.onTap, 
        borderRadius: BorderRadius.circular(widget.borderRadius),
        splashColor: AppTheme.primary.withOpacity(0.1),
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
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
              width: active ? 2.5 : 1, // ফোকাস আসলে বর্ডার একটু মোটা হবে যেন টিভিতে স্পষ্ট দেখা যায়
            ),
            boxShadow: _focused // শুধুমাত্র আসলেই রিমোট ফোকাসে থাকলে গ্লো ইফেক্ট দেখাবে
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
