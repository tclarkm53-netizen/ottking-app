// lib/presentation/screens/home_screen_widgets/channel_grid.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../../presentation/widgets/tv_focus_card.dart';

class ChannelGrid extends StatefulWidget {
  const ChannelGrid({
    super.key,
    required this.channels,
    required this.chNodes,
    required this.appState,
    required this.categoryName,
  });

  final List channels;
  final List<FocusNode> chNodes;
  final AppState appState;
  final String categoryName;

  @override
  State<ChannelGrid> createState() => _ChannelGridState();
}

class _ChannelGridState extends State<ChannelGrid> {
  // টিভি নেভিগেশনে অটো-স্ক্রোল ঠিক রাখার জন্য স্ক্রোল কন্ট্রোলার
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 8, left: 4),
          child: Row(
            children: [
              Text(
                '📺 ${widget.categoryName} CHANNELS',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${widget.channels.length}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Grid ─────────────────────────────────────────────────────────
        Expanded(
          child: widget.channels.isEmpty
              ? const Center(
                  child: Text(
                    'কোনো চ্যানেল পাওয়া যায়নি',
                    style: TextStyle(color: Colors.white38, fontSize: 16),
                  ),
                )
              : GridView.builder(
                  controller: _scrollController, // স্ক্রোল কন্ট্রোলার অ্যাসাইন করা হলো
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                  ),
                  physics: const BouncingScrollPhysics(),
                  itemCount: widget.channels.length,
                  itemBuilder: (context, i) {
                    final ch = widget.channels[i];
                    final origIdx = widget.appState.channels.indexOf(ch);
                    final playing = widget.appState.currentChannelIndex == origIdx;

                    // রিমোট দিয়ে নিচে নামার সময় যেন স্ক্রিন স্বয়ংক্রিয়ভাবে স্ক্রোল হয়
                    return widget.chNodes.length > i 
                    ? Focus(
                        onFocusChange: (hasFocus) {
                          if (hasFocus) {
                            // ফোকাসড আইটেমটি স্ক্রিনের বাইরে থাকলে তাকে স্ক্রিনে টেনে নিয়ে আসবে
                            Scrollable.ensureVisible(
                              context,
                              duration: const Duration(milliseconds: 200),
                              alignment: 0.5, // স্ক্রিনের মাঝ বরাবর স্ক্রোল করবে
                            );
                          }
                        },
                        child: TvFocusCard(
                          focusNode: widget.chNodes[i],
                          selected: playing,
                          padding: EdgeInsets.zero,
                          onTap: () {
                            widget.appState.selectChannelByIndex(origIdx);
                            Navigator.pushNamed(context, '/player');
                          },
                          child: ChannelCard(
                            channel: ch,
                            isPlaying: playing,
                          ),
                        ),
                      )
                    : const SizedBox.shrink();
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Channel Card ─────────────────────────────────────────────────────────────
class ChannelCard extends StatelessWidget {
  const ChannelCard({
    super.key,
    required this.channel,
    required this.isPlaying,
  });
  final dynamic channel;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: AppTheme.card,
            child: channel.logoUrl.trim().isNotEmpty
                ? Image.network(
                    channel.logoUrl.trim(),
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    loadingBuilder: (ctx, child, prog) =>
                        prog == null ? child : _logoPlaceholder(),
                    errorBuilder: (_, __, ___) => _logoPlaceholder(),
                  )
                : _logoPlaceholder(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              child: Text(
                channel.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Positioned(
            top: 6,
            left: 6,
            child: Row(
              children: [
                if (channel.isPremium == 1)
                  const _Badge(
                    label: 'PREMIUM',
                    bg: Color(0xFFEAB308),
                    fg: Colors.black,
                  ),
                const SizedBox(width: 3),
                _Badge(
                  label: channel.quality.toUpperCase(),
                  bg: Colors.black.withOpacity(0.7),
                  fg: AppTheme.primary,
                ),
              ],
            ),
          ),
          if (isPlaying)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primary, width: 2),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: _LiveDot(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _logoPlaceholder() => const Center(
        child: Icon(Icons.live_tv_rounded, color: Colors.white24, size: 32),
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: TextStyle(color: fg, fontSize: 8, fontWeight: FontWeight.w900)),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 3, backgroundColor: Colors.white),
          SizedBox(width: 4),
          Text('LIVE',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
