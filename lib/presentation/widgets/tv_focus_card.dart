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
      child: GestureDetector(
        onTap: widget.onTap,
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
          child: widget.child,
        ),
      ),
    );
  }
}
