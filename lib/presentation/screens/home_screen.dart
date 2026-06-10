// lib/presentation/screens/home_screen.dart
// Professional TV landscape home — sidebar categories + channel grid

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../providers/app_state.dart';
import '../widgets/tv_focus_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FocusNode _rootFocusNode = FocusNode(debugLabel: 'home-root');
  int _selectedCategoryIndex = 0;

  final List<FocusNode> _catNodes = [];
  final List<FocusNode> _chNodes = [];

  @override
  void initState() {
    super.initState();
    // Ensure landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _rootFocusNode.dispose();
    for (final n in _catNodes) n.dispose();
    for (final n in _chNodes) n.dispose();
    super.dispose();
  }

  // কাস্টম টিভি এক্সিট কনফার্মেশন ডায়ালগ
  Future<bool> _showExitConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            title: const Row(
              children: [
                Icon(Icons.exit_to_app_rounded, color: AppTheme.primary),
                SizedBox(width: 10),
                Text('অ্যাপ বন্ধ করুন', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              'আপনি কি নিশ্চিতভাবে অ্যাপ্লিকেশনটি থেকে বের হয়ে যেতে চান?',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(0, 0, 16, 12),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('না', style: TextStyle(color: Colors.white60, fontSize: 14)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('হ্যাঁ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _handleKey(KeyEvent event) async {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack) {
      // এক্সিট কনফার্মেশন ডায়ালগ দেখানো হচ্ছে
      final shouldExit = await _showExitConfirmation(context);
      if (shouldExit) {
        SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      }
    }
  }

  void _changeCategory(int index) {
    if (_selectedCategoryIndex == index) return;
    setState(() {
      _selectedCategoryIndex = index;
      // ক্যাটাগরি পরিবর্তনের সময় আগের চ্যানেল নোডগুলো পরিষ্কার করে দেওয়া হচ্ছে যাতে ফিল্টারিং স্মুথ হয়
      for (final node in _chNodes) {
        node.dispose();
      }
      _chNodes.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final size = MediaQuery.of(context).size;

    // Categories with "All" prepended
    final cats = <Map<String, String>>[
      {'name': 'All', 'icon': '🌐'},
      ...appState.categories.map((c) => {'name': c.name, 'icon': c.icon}),
    ];

    while (_catNodes.length < cats.length) _catNodes.add(FocusNode());

    final currentCat = cats[_selectedCategoryIndex]['name']!;
    final filtered = appState.channels.where((ch) {
      if (currentCat == 'All') return true;
      return ch.category.toLowerCase() == currentCat.toLowerCase();
    }).toList();

    while (_chNodes.length < filtered.length) _chNodes.add(FocusNode());

    return KeyboardListener(
      focusNode: _rootFocusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              // ── Top bar ─────────────────────────────────────────────────────
              _TopBar(appState: appState),

              // ── Main split view ─────────────────────────────────────────────
              Expanded(
                child: appState.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primary,
                          strokeWidth: 3,
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Sidebar — categories
                            SizedBox(
                              width: size.width * 0.18,
                              child: _CategorySidebar(
                                cats: cats,
                                catNodes: _catNodes,
                                selectedIndex: _selectedCategoryIndex,
                                onSelect: _changeCategory,
                              ),
                            ),

                            const SizedBox(width: 20),

                            // Channel grid
                            Expanded(
                              child: _ChannelGrid(
                                channels: filtered,
                                chNodes: _chNodes,
                                appState: appState,
                                categoryName: currentCat,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Top Bar ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Logo
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

          // Auth info
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

          // Channel count
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

          // Settings button
          _TvIconButton(
            icon: Icons.settings_rounded,
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
    );
  }
}

class _TvIconButton extends StatefulWidget {
  const _TvIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_TvIconButton> createState() => _TvIconButtonState();
}

class _TvIconButtonState extends State<_TvIconButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
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
    );
  }
}

// ─── Category Sidebar ─────────────────────────────────────────────────────────

class _CategorySidebar extends StatelessWidget {
  const _CategorySidebar({
    required this.cats,
    required this.catNodes,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<Map<String, String>> cats;
  final List<FocusNode> catNodes;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12, top: 8),
          child: Text(
            '🔥 CATEGORIES',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: cats.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, i) {
              final cat = cats[i];
              final selected = selectedIndex == i;
              return _CatItem(
                focusNode: catNodes[i],
                icon: cat['icon']!,
                name: cat['name']!,
                selected: selected,
                onTap: () => onSelect(i),
                onFocus: () => onSelect(i),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CatItem extends StatefulWidget {
  const _CatItem({
    required this.focusNode,
    required this.icon,
    required this.name,
    required this.selected,
    required this.onTap,
    required this.onFocus,
  });

  final FocusNode focusNode;
  final String icon;
  final String name;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onFocus;

  @override
  State<_CatItem> createState() => _CatItemState();
}

class _CatItemState extends State<_CatItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final active = _focused || widget.selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (v) {
          setState(() => _focused = v);
          if (v) widget.onFocus();
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _focused
                  ? AppTheme.primary
                  : widget.selected
                      ? AppTheme.primary.withOpacity(0.15)
                      : AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? AppTheme.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Text(widget.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.name,
                    style: TextStyle(
                      color: active ? Colors.white : Colors.white60,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Channel Grid ─────────────────────────────────────────────────────────────

class _ChannelGrid extends StatelessWidget {
  const _ChannelGrid({
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
                    childAspectRatio: 1.3, // অ্যাসপেক্ট রেশিও কার্ড টাইপ করা হয়েছে
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
                        appState.currentChannelIndex = origIdx;
                        Navigator.pushNamed(context, '/player');
                      },
                      child: _ChannelCard(channel: ch, isPlaying: playing),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.channel, required this.isPlaying});
  final dynamic channel;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Logo Area - কার্ড স্কয়্যার স্কেলে ইমেজ রেন্ডারিং করা হয়েছে
          Container(
            color: AppTheme.card,
            padding: const EdgeInsets.all(14),
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0, // স্কয়ার বক্স প্রপোরশন বাধ্য করা হলো
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: channel.logoUrl.trim().isNotEmpty
                      ? Image.network(
                          channel.logoUrl.trim(),
                          fit: BoxFit.contain,
                          loadingBuilder: (ctx, child, prog) =>
                              prog == null ? child : _logoPlaceholder(),
                          errorBuilder: (_, __, ___) => _logoPlaceholder(),
                        )
                      : _logoPlaceholder(),
                ),
              ),
            ),
          ),

          // Channel name bottom bar
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

          // Badges top-left
          Positioned(
            top: 6,
            left: 6,
            child: Row(
              children: [
                if (channel.isPremium == 1)
                  const _Badge(
                      label: 'PREMIUM',
                      bg: Color(0xFFEAB308),
                      fg: Colors.black),
                const SizedBox(width: 3),
                _Badge(
                  label: channel.quality.toUpperCase(),
                  bg: Colors.black.withOpacity(0.7),
                  fg: AppTheme.primary,
                ),
              ],
            ),
          ),

          // Now playing glow overlay
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

  Widget _logoPlaceholder() => const Icon(
        Icons.live_tv_rounded,
        color: Colors.white24,
        size: 28,
      );
}

class _Badge extends StatelessWidget {
  const _Badge(
      {required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(4)),
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
