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
  final PageController _pageController = PageController(viewportFraction: 1.0); // ব্যানার 100% উইডথ করার জন্য 1.0 করা হয়েছে

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
    
    // টিভি স্ক্রিন নাকি মোবাইল স্ক্রিন তা চেক করার জন্য রেসপনসিভ কন্ডিশন
    final isTV = MediaQuery.of(context).size.width > 800 && 
                 MediaQuery.of(context).orientation == Orientation.landscape;

    return KeyboardListener(
      focusNode: _rootFocusNode,
      onKeyEvent: (event) => _handleKey(event, appState, context),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            AppConstants.appName,
            style: TextStyle(fontSize: isTV ? 28 : 20), // টিভির জন্য বড় ফন্ট
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.settings_outlined, size: isTV ? 32 : 24),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
        body: appState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : appState.errorMessage.isNotEmpty && appState.channels.isEmpty
                ? _ErrorView(
                    message: appState.errorMessage,
                    onRetry: appState.loadCatalog,
                  )
                : _HomeBody(
                    appState: appState,
                    theme: theme,
                    pageController: _pageController,
                    isTV: isTV, // রেসপনসিভ ফ্ল্যাগ পাস করা হলো
                  ),
      ),
    );
  }
}

// ── Body (Sliver ও Responsive Layout) ──────────────────────────────────────────

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
          // ── ১. ব্যানার সেকশন (সম্পূর্ণ ফুল উইডথ, নো মার্জিন) ──────────────────────
          if (appState.banners.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: isTV ? 320 : 200, // টিভির জন্য ব্যানারের হাইট বেশি হবে
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

          // ── ২. ক্যাটাগরি ও হেডার সেকশন (সাইড প্যাডিং সহ) ─────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (appState.categories.isNotEmpty) ...[
                  _SectionHeader(title: 'Featured Categories', isTV: isTV),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: appState.categories.map((cat) {
                      return Chip(
                        label: Text(cat.name, style: TextStyle(fontSize: isTV ? 16 : 14)),
                        avatar: Text(cat.icon, style: TextStyle(fontSize: isTV ? 18 : 14)),
                        padding: isTV ? const EdgeInsets.all(12) : const EdgeInsets.all(8),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],
                _SectionHeader(title: 'Live Channels', isTV: isTV),
                const SizedBox(height: 12),
              ]),
            ),
          ),

          // ── ৩. চ্যানেল গ্রিড সেকশন (মোবাইলে ২টি, টিভিতে ৪টি কলাম) ─────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: appState.channels.isEmpty
                ? const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No channels available'),
                      ),
                    ),
                  )
                : SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isTV ? 4 : 2, // টিভি ভিউ হলে ৪টি কলাম দেখাবে
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: isTV ? 1.3 : 1.1, // টিভি স্ক্রিনের এ্যাসপেক্ট রেশিও এডজাস্টমেন্ট
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final channel = appState.channels[index];
                        final selected = appState.currentChannelIndex == index;
                        return FocusGlowButton(
                          label: channel.name,
                          // চ্যানেল অবজেক্টে লোগো থাকলে তা ইমেজ উইজেট দিয়ে রেন্ডার করা হচ্ছে
                          icon: channel.logoUrl != null ? null : Icons.play_circle_outline,
                          imageWidget: channel.logoUrl != null
                              ? Image.network(
                                  channel.logoUrl,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                  },
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.tv, size: 40, color: Colors.grey),
                                )
                              : null,
                          selected: selected,
                          trailing: Text(
                            channel.quality,
                            style: TextStyle(
                              fontSize: isTV ? 14 : 11,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
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

// ── Banner card (সম্পূর্ণ 100% ফুল স্ক্রিন উইডথ এবং নেটওয়ার্ক ইমেজ সহ) ──────────────

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner, required this.theme, required this.isTV});

  final dynamic banner;
  final ThemeData theme;
  final bool isTV;

  @override
  Widget build(BuildContext context) {
    // ব্যানার অবজেক্ট থেকে লোগো/ব্যাকগ্রাউন্ড ইমেজের URL নেওয়া (আপনার API কী অনুযায়ী পরিবর্তন করে নিতে পারেন)
    final String? imageUrl = banner.imageUrl ?? banner.logoUrl;

    return Container(
      width: double.infinity, // ফুল উইডথ নিশ্চিত করার জন্য
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        // যদি ইমেজ থাকে তবে ব্যাকগ্রাউন্ড ইমেজ হিসেবে লোড হবে, না থাকলে গ্রেডিয়েন্ট কালার দেখাবে
        image: imageUrl != null
            ? DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Container(
        // ইমেজের ওপর টেক্সট সহজে পড়ার জন্য কালো ডার্ক শ্যাডো/Overlay গ্রেডিয়েন্ট
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        padding: EdgeInsets.all(isTV ? 32 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              (banner.title ?? '').toString(),
              style: (isTV ? theme.textTheme.headlineMedium : theme.textTheme.titleLarge)?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              (banner.subtitle ?? '').toString(),
              style: (isTV ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)?.copyWith(
                color: Colors.white70,
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
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: isTV ? 22 : 16, // টিভির জন্য বড় হেডার
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
            Text(
              'Could not load channels',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
