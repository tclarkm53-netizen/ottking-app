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
  });

  final String label;
  final IconData icon;
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
                    Icon(widget.icon, color: theme.colorScheme.primary),
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
