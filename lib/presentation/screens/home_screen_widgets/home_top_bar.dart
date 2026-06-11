// lib/presentation/screens/home_screen_widgets/home_top_bar.dart

import 'package:flutter/material.dart';
// কীবোর্ড এবং রিমোটের কি হ্যান্ডেল করার জন্য এই ইমপোর্টটি দরকার ছিল
import 'package:flutter/services.dart'; 

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/app_state.dart';

class HomeTopBar extends StatelessWidget {
  final AppState appState;
  final FocusNode settingsFocusNode; //HomeScreen থেকে পাঠানো নোডটি রিসিভ করার ভ্যারিয়েবল

  const HomeTopBar({
    super.key, 
    required this.appState,
    required this.settingsFocusNode, // কনস্ট্রাক্টরে রিকোয়ার্ড করা হলো
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Row(
        children: [
          // ── App Logo ─────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'OTT',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                AppConstants.appName,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),

          const Spacer(),

          // ── User badge ───────────────────────────────────────────────
          if (appState.isAuthenticated && appState.userProfile != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded,
                      color: Color(0xFFEAB308), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${appState.userProfile!.email.split('@').first}  •  ${appState.userProfile!.plan}',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],

          // ── Channel count ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.live_tv_rounded,
                    color: AppTheme.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${appState.channels.length} চ্যানেল',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Settings button (focusable) ──────────────────────────────
          _TvIconButton(
            focusNode: settingsFocusNode, // এখানে HomeScreen থেকে আসা ফোকাস নোডটি পাস করা হলো
            icon: Icons.settings_rounded,
            tooltip: 'সেটিংস',
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
    );
  }
}

/// Focusable icon button — TV remote friendly
class _TvIconButton extends StatefulWidget {
  const _TvIconButton({
    required this.icon,
    required this.onTap,
    required this.focusNode, // ফোকাস নোড প্যারামিটার যুক্ত করা হলো
    this.tooltip = '',
  });

  final IconData icon;
  final VoidCallback onTap;
  final FocusNode focusNode; // রিসিভার ভ্যারিয়েবল
  final String tooltip;

  @override
  State<_TvIconButton> createState() => _TvIconButtonState();
}

class _TvIconButtonState extends State<_TvIconButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Focus(
        focusNode: widget.focusNode, // কাস্টম ফোকাস নোডটি এখানে অ্যাসাইন করা হলো
        onFocusChange: (v) => setState(() => _focused = v),
        onKeyEvent: (_, e) {
          if (e is KeyDownEvent &&
              (e.logicalKey == LogicalKeyboardKey.enter ||
                  e.logicalKey == LogicalKeyboardKey.select)) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _focused
                  ? AppTheme.primary.withOpacity(0.2)
                  : AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _focused ? AppTheme.primary : AppTheme.border,
              ),
            ),
            child: Icon(
              widget.icon,
              color: _focused ? AppTheme.primary : Colors.white70,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
