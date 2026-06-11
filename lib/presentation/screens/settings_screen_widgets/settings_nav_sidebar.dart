// lib/presentation/screens/settings_screen_widgets/settings_nav_sidebar.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

class SettingsNavSidebar extends StatefulWidget {
  const SettingsNavSidebar({
    super.key,
    required this.activeSection,
    required this.onSelect,
    required this.onBack,
  });

  final int activeSection;
  final ValueChanged<int> onSelect;
  final VoidCallback onBack;

  @override
  State<SettingsNavSidebar> createState() => _SettingsNavSidebarState();
}

class _SettingsNavSidebarState extends State<SettingsNavSidebar> {
  final List<FocusNode> _nodes = List.generate(4, (_) => FocusNode());

  static const _items = [
    _NavMeta(
      icon: Icons.account_circle_rounded,
      label: 'অ্যাকাউন্ট',
      hint: 'লগইন / সাবস্ক্রিপশন',
    ),
    _NavMeta(
      icon: Icons.tv_rounded,
      label: 'TV সেটিংস',
      hint: 'Boot Player ও আরও',
    ),
    _NavMeta(
      icon: Icons.settings_applications_rounded,
      label: 'সিস্টেম',
      hint: 'ক্যাটালগ / অ্যাপ তথ্য',
    ),
  ];

  @override
  void dispose() {
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            // ── Header ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Focus(
                    focusNode: _nodes[3],
                    onKeyEvent: (_, e) {
                      if (e is KeyDownEvent &&
                          (e.logicalKey == LogicalKeyboardKey.enter ||
                              e.logicalKey == LogicalKeyboardKey.select)) {
                        widget.onBack();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: GestureDetector(
                      onTap: widget.onBack,
                      child: Builder(builder: (ctx) {
                        final focused = Focus.of(ctx).hasFocus;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: focused
                                ? AppTheme.primary.withOpacity(0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: focused
                                  ? AppTheme.primary
                                  : Colors.transparent,
                            ),
                          ),
                          child: Icon(Icons.arrow_back_ios_new_rounded,
                              color: focused
                                  ? AppTheme.primary
                                  : Colors.white70,
                              size: 18),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'সেটিংস',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Nav items ───────────────────────────────────────────────
            ...List.generate(_items.length, (i) {
              final item = _items[i];
              final isActive = widget.activeSection == i;
              return _NavItem(
                focusNode: _nodes[i],
                icon: item.icon,
                label: item.label,
                hint: item.hint,
                isActive: isActive,
                onTap: () => widget.onSelect(i),
              );
            }),

            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'v1.0.0  |  Smart TV',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.2), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavMeta {
  const _NavMeta(
      {required this.icon, required this.label, required this.hint});
  final IconData icon;
  final String label;
  final String hint;
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    super.key,
    required this.focusNode,
    required this.icon,
    required this.label,
    required this.hint,
    required this.isActive,
    required this.onTap,
  });
  final FocusNode focusNode;
  final IconData icon;
  final String label;
  final String hint;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final active = _focused || widget.isActive;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (v) {
          setState(() => _focused = v);
          if (v) widget.onTap(); // focus হলেই section সুইচ
        },
        onKeyEvent: (_, e) {
          if (e is KeyDownEvent &&
              (e.logicalKey == LogicalKeyboardKey.enter ||
                  e.logicalKey == LogicalKeyboardKey.select ||
                  e.logicalKey == LogicalKeyboardKey.arrowRight)) {
            widget.onTap();
            if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
              FocusScope.of(context).nextFocus();
            }
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _focused
                  ? AppTheme.primary.withOpacity(0.2)
                  : widget.isActive
                      ? AppTheme.primary.withOpacity(0.1)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? AppTheme.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(widget.icon,
                    color: active ? AppTheme.primary : Colors.white38,
                    size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: active ? Colors.white : Colors.white54,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.hint,
                        style: const TextStyle(
                            color: Colors.white30, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: active ? AppTheme.primary : Colors.white12,
                    size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
