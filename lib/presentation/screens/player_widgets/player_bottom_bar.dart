// lib/presentation/screens/player_widgets/player_bottom_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_theme.dart';

/// কন্ট্রোলারের ফোকাসযোগ্য আইটেম
enum _BarItem { playPause, exit }

class PlayerBottomBar extends StatefulWidget {
  const PlayerBottomBar({
    super.key,
    required this.ctrl,
    required this.isLive,
    required this.liveBlink,
    required this.onPlayPause,
    required this.onExit,
    required this.onChannelUp,
    required this.onChannelDown,
  });

  final VideoPlayerController ctrl;
  final bool isLive;
  final bool liveBlink;
  final VoidCallback onPlayPause;
  final VoidCallback onExit;
  final VoidCallback onChannelUp;   // p- / চ্যানেল আগে
  final VoidCallback onChannelDown; // p+ / চ্যানেল পরে

  @override
  State<PlayerBottomBar> createState() => _PlayerBottomBarState();
}

class _PlayerBottomBarState extends State<PlayerBottomBar> {
  _BarItem _focused = _BarItem.playPause;
  final Map<_BarItem, FocusNode> _nodes = {
    _BarItem.playPause: FocusNode(debugLabel: 'bar-playpause'),
    _BarItem.exit: FocusNode(debugLabel: 'bar-exit'),
  };

  @override
  void initState() {
    super.initState();
    // ডিফল্ট ফোকাস playPause এ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nodes[_BarItem.playPause]?.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _moveFocus(int dir) {
    final items = _BarItem.values;
    final idx = items.indexOf(_focused);
    final next = items[(idx + dir).clamp(0, items.length - 1)];
    setState(() => _focused = next);
    _nodes[next]?.requestFocus();
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // ← → দিয়ে ফোকাস নেভিগেশন
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _moveFocus(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _moveFocus(1);
      return KeyEventResult.handled;
    }

    // p+ p- দিয়ে চ্যানেল চেঞ্জ (কন্ট্রোলার খোলা থাকলেও)
    // MediaKey: channel up/down, page up/down
    if (event.logicalKey == LogicalKeyboardKey.channelUp ||
        event.logicalKey == LogicalKeyboardKey.pageUp) {
      widget.onChannelUp();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.channelDown ||
        event.logicalKey == LogicalKeyboardKey.pageDown) {
      widget.onChannelDown();
      return KeyEventResult.handled;
    }

    // Enter/OK — ফোকাসড আইটেম অ্যাক্টিভেট
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.space) {
      switch (_focused) {
        case _BarItem.playPause:
          widget.onPlayPause();
          break;
        case _BarItem.exit:
          widget.onExit();
          break;
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Widget _focusableBtn({
    required _BarItem item,
    required Widget child,
    required VoidCallback onTap,
  }) {
    final isFocused = _focused == item;
    return Focus(
      focusNode: _nodes[item],
      onFocusChange: (v) {
        if (v) setState(() => _focused = item);
      },
      onKeyEvent: (_, event) => _handleKey(event),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isFocused
                ? AppTheme.primary.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFocused
                  ? AppTheme.primary
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.85),
              Colors.transparent
            ],
          ),
        ),
        child: Row(
          children: [
            // ===== Play/Pause বোতাম (focusable) =====
            _focusableBtn(
              item: _BarItem.playPause,
              onTap: widget.onPlayPause,
              child: Icon(
                widget.ctrl.value.isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(width: 12),

            // ===== LIVE ব্লিংকিং ব্যাজ =====
            if (widget.isLive && widget.ctrl.value.isPlaying)
              AnimatedOpacity(
                opacity: widget.liveBlink ? 1.0 : 0.3,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                          radius: 3,
                          backgroundColor: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const Spacer(),

            // ===== Exit বোতাম (focusable) =====
            _focusableBtn(
              item: _BarItem.exit,
              onTap: widget.onExit,
              child: const Icon(
                Icons.exit_to_app_rounded,
                color: Colors.white70,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
