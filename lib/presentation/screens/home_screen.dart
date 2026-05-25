// lib/presentation/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../providers/app_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FocusNode _rootFocusNode = FocusNode(debugLabel: 'home-root');
  final PageController _pageController = PageController(viewportFraction: 0.93);

  @override
  void dispose() {
    _rootFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handleKey(KeyEvent event, AppState appState) {
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

    // প্রিমিয়াম ডার্ক ব্যাকগ্রাউন্ড (ডিজাইন অনুযায়ী গভীর নেভি/ডার্ক গ্রে মিক্স)
    const scaffoldBgColor = Color(0xFF13131A); 

    return KeyboardListener(
      focusNode: _rootFocusNode,
      onKeyEvent: (event) => _handleKey(event, appState),
      child: Theme(
        // লোকাললি ডার্ক থিম এনফোর্স করা হচ্ছে ডিজাইনের সাথে মিল রাখার জন্য
        data: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: scaffoldBgColor,
          appBarTheme: const AppBarTheme(
            backgroundColor: scaffoldBgColor,
            elevation: 0,
            titleTextStyle: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        child: Scaffold(
          appBar: AppBar(
            title: const Text(AppConstants.appName), // "Live BD"
            centerTitle: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white, size: 28),
                onPressed: () => Navigator.pushNamed(context, '/settings'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: appState.isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : appState.errorMessage.isNotEmpty && appState.channels.isEmpty
                  ? _ErrorView(
                      message: appState.errorMessage,
                      onRetry: appState.loadCatalog,
                    )
                  : _HomeBody(
                      appState: appState,
                      pageController: _pageController,
                    ),
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.appState,
    required this.pageController,
  });

  final AppState appState;
  final PageController pageController;

  @override
  Widget build(BuildContext context) {
    // রেসপন্সিভ ব্রেকপয়েন্ট ডিটেকশন
    final screenWidth = MediaQuery.of(context).size.width;
    final isTv = screenWidth > 800; 

    return RefreshIndicator(
      onRefresh: appState.loadCatalog,
      color: Colors.redAccent,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          // ── Banners (ডিজাইনের বড় ব্যানার সেকশন) ──────────────────────────────
          if (appState.banners.isNotEmpty) ...[
            if (isTv)
              // টিভি লেআউটের জন্য দুই কলামের ব্যানার (বাম পাশে বড়, ডান পাশে ছোট)
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _BannerCard(banner: appState.banners[0], isMain: true),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: appState.banners.length > 1
                        ? _BannerCard(banner: appState.banners[1], isMain: false)
                        : const SizedBox(),
                  ),
                ],
              )
            else
              // মোবাইলের জন্য স্লাইডার ব্যানার
              SizedBox(
                height: 200,
                child: PageView.builder(
                  controller: pageController,
                  itemCount: appState.banners.length,
                  itemBuilder: (context, index) {
                    final banner = appState.banners[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _BannerCard(banner: banner, isMain: true),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
          ],

          // ── Channels Grid (চ্যানেলগুলোর প্রিমিয়াম ডার্ক গ্রিড) ───────────────
          if (appState.channels.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No channels available', style: TextStyle(color: Colors.white60)),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isTv ? 5 : 3, // টিভিতে ৫ কলাম, মোবাইলে ৩ কলাম (ডিজাইন অনুযায়ী)
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.0, // স্কয়ার বক্স শেপ রাখার জন্য
              ),
              itemCount: appState.channels.length,
              itemBuilder: (context, index) {
                final channel = appState.channels[index];
                final selected = appState.currentChannelIndex == index;

                return _ChannelGridItem(
                  channel: channel,
                  isSelected: selected,
                  onTap: () {
                    appState.currentChannelIndex = index;
                    Navigator.pushNamed(context, '/player');
                  },
                );
              },
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Banner Card ───────────────────────────────────────────────────────────────

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner, required this.isMain});

  final dynamic banner;
  final bool isMain;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: const DecorationImage(
          image: NetworkImage('https://via.placeholder.com/600x350'), // এখানে banner.imageUrl দিতে পারেন
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.black.withOpacity(0.85),
              Colors.black.withOpacity(0.1),
            ],
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            // লাইভ লাল ব্যাজ
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // ব্যানারের টাইটেল ও সাবটাইটেল
            Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    banner.title as String,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMain ? 20 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!isMain) ...[
                    const SizedBox(height: 2),
                    Text(
                      banner.subtitle as String,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Channel Grid Item ─────────────────────────────────────────────────────────

class _ChannelGridItem extends StatelessWidget {
  const _ChannelGridItem({
    required this.channel,
    required this.isSelected,
    required this.onTap,
  });

  final dynamic channel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // ডিজাইন অনুযায়ী কার্ডের ব্যাকগ্রাউন্ড কালার
    const cardBgColor = Color(0xFF1E1E28); 
    const focusBorderColor = Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? focusBorderColor : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Stack(
          children: [
            // রাইট-টপ কর্নারে ছোট "LIVE" টেক্সট ব্যাজ
            Positioned(
              top: 6,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // লোগো এবং নাম
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Center(
                      child: Icon(
                        Icons.tv, // এখানে আপনার লোগো উইজেট (যেমন Image.network(channel.logo)) বসাবেন
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    channel.name as String,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error View ────────────────────────────────────────────────────────────────

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
            const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.white38),
            const SizedBox(height: 16),
            const Text(
              'Could not load channels',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
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
