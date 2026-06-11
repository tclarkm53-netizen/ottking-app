// lib/presentation/screens/home_screen_widgets/channel_grid.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../../presentation/widgets/tv_focus_card.dart';

class ChannelGrid extends StatelessWidget {
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
                '📺 $categoryName CHANNELS',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${channels.length}',
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
          child: channels.isEmpty
              ? const Center(
                  child: Text(
                    'কোনো চ্যানেল পাওয়া যায়নি',
                    style: TextStyle(color: Colors.white38, fontSize: 16),
                  ),
                )
              : GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                  ),
                  physics: const BouncingScrollPhysics(),
                  itemCount: channels.length,
                  itemBuilder: (context, i) {
                    final ch = channels[i];
                    final origIdx = appState.channels.indexOf(ch);
                    final playing =
                        appState.currentChannelIndex == origIdx;

                    return TvFocusCard(
                      focusNode: chNodes[i],
                      selected: playing,
                      padding: EdgeInsets.zero,
                      onTap: () {
                        appState.selectChannelByIndex(origIdx);
                        Navigator.pushNamed(context, '/player');
                      },
                      child: ChannelCard(
                        channel: ch,
                        isPlaying: playing,
                      ),
                    );
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
          // ── Logo — XY বরাবর ফিট ──────────────────────────────────────
          Container(
            color: AppTheme.card,
            child: channel.logoUrl.trim().isNotEmpty
                ? Image.network(
                    channel.logoUrl.trim(),
                    // fill করবে কিন্তু aspect ratio রাখবে
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    loadingBuilder: (ctx, child, prog) =>
                        prog == null ? child : _logoPlaceholder(),
                    errorBuilder: (_, __, ___) => _logoPlaceholder(),
                  )
                : _logoPlaceholder(),
          ),

          // ── Channel name bar ─────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.85),
                    Colors.transparent
                  ],
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

          // ── Badges top-left ──────────────────────────────────────────
          Positioned(
            top: 6,
            left: 6,
            child: Row(
              children: [
                if (channel.isPremium == 1)
                  _Badge(
                    label: 'PREMIUM',
                    bg: const Color(0xFFEAB308),
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

          // ── Now playing overlay ──────────────────────────────────────
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
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 8, fontWeight: FontWeight.w900)),
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
