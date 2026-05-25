// lib/presentation/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../providers/app_state.dart';
import '../widgets/focus_glow_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FocusNode _rootFocusNode = FocusNode(debugLabel: 'home-root');
  final PageController _pageController = PageController(viewportFraction: 1.0); 

  @override
  void dispose() {
    _rootFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handleKey(KeyEvent event, AppState appState, BuildContext context) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      FocusScope.of(context).nextFocus();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      FocusScope.of(context).previousFocus();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      appState.switchChannel(1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      appState.switchChannel(-1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    
    final isTV = MediaQuery.of(context).size.width > 800 && 
                 MediaQuery.of(context).orientation == Orientation.landscape;

    return KeyboardListener(
      focusNode: _rootFocusNode,
      onKeyEvent: (event) => _handleKey(event, appState, context),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // ইমেজের মতো ডার্ক ব্যাকগ্রাউন্ড কালার
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          elevation: 0,
          title: Text(
            AppConstants.appName,
            style: TextStyle(fontSize: isTV ? 26 : 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.settings_outlined, size: isTV ? 30 : 24, color: Colors.white),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
        body: appState.isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
                ),
              )
            : appState.errorMessage.isNotEmpty && appState.channels.isEmpty
                ? _ErrorView(
                    message: appState.errorMessage,
                    onRetry: appState.loadCatalog,
                  )
                : _HomeBody(
                    appState: appState,
                    theme: theme,
                    pageController: _pageController,
                    isTV: isTV,
                  ),
      ),
    );
  }
}

// ── Body (Sliver Layout) ───────────────────────────────────────────────────────

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.appState,
    required this.theme,
    required this.pageController,
    required this.isTV,
  });

  final AppState appState;
  final ThemeData theme;
  final PageController pageController;
  final bool isTV;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: appState.loadCatalog,
      child: CustomScrollView(
        slivers: [
          // ── ১. ব্যানার সেকশন (১০০% ফুল উইডথ) ──────────────────────────────────
          if (appState.banners.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: isTV ? 340 : 210, // ইমেজের এ্যাসপেক্ট রেশিওর সাথে মিল রেখে হাইট
                child: PageView.builder(
                  controller: pageController,
                  itemCount: appState.banners.length,
                  itemBuilder: (context, index) {
                    final banner = appState.banners[index];
                    return _BannerCard(banner: banner, theme: theme, isTV: isTV);
                  },
                ),
              ),
            ),

          // ── ২. হেডার সেকশন ──────────────────────────────────
          SliverPadding(
            padding: EdgeInsets.fromLTRB(isTV ? 32 : 16, 24, isTV ? 32 : 16, 12),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SectionHeader(title: isTV ? 'এখন চলছে:' : 'লাইভ চ্যানেল', isTV: isTV),
                const SizedBox(height: 8),
              ]),
            ),
          ),

          // ── ৩. চ্যানেল গ্রিড সেকশন (৫:২ রেশিও এবং ওরিয়েন্টেশন মার্জিন সহ আপডেট) ───────────
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: isTV ? 32 : 16),
            sliver: appState.channels.isEmpty
                ? const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No channels available', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  )
                : SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isTV ? 4 : 2, // টিভিতে ৪ কলাম, মোবাইলে ২ কলাম
                      mainAxisSpacing: isTV ? 18 : 14,
                      crossAxisSpacing: isTV ? 18 : 14,
                      // ── আপনার দেওয়া ৫:২ রেশিও অনুযায়ী childAspectRatio আপডেট (৫/২ = ২.৫) ──
                      childAspectRatio: isTV ? 2.5 : 0.95, 
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final channel = appState.channels[index];
                        final selected = appState.currentChannelIndex == index;
                        
                        return FocusGlowButton(
                          isTV: isTV, // বাটনকে জানানো হলো এটি কোন মোডে আছে
                          label: channel.name,
                          icon: channel.logoUrl != null && channel.logoUrl.isNotEmpty
                              ? Image.network(
                                  channel.logoUrl,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.tv, size: 24, color: Colors.white30),
                                )
                              : Icons.play_circle_outline,
                          selected: selected,
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white24),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              channel.quality.isNotEmpty ? channel.quality : 'HD',
                              style: const TextStyle(fontSize: 10, color: Colors.white60),
                            ),
                          ),
                          onTap: () {
                            appState.currentChannelIndex = index;
                            Navigator.pushNamed(context, '/player');
                          },
                        );
                      },
                      childCount: appState.channels.length,
                    ),
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Banner card ───────────────────────────────────────────────────────────────

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner, required this.theme, required this.isTV});

  final dynamic banner;
  final ThemeData theme;
  final bool isTV;

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = banner.imageUrl ?? banner.logoUrl;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        image: imageUrl != null
            ? DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black.withOpacity(0.85), Colors.transparent],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        padding: EdgeInsets.all(isTV ? 32 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                (banner.title ?? '').toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isTV ? 20 : 14,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              (banner.subtitle ?? '').toString(),
              style: TextStyle(
                color: Colors.white70,
                fontSize: isTV ? 15 : 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.isTV});

  final String title;
  final bool isTV;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.white,
        fontSize: isTV ? 20 : 16,
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Could not load channels', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            Text('No Internet Access or api mismass', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
