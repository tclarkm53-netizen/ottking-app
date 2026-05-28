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
  // ── ব্যানার ১০০% ফুল উইডথ করার জন্য viewportFraction ১.০ করা হলো ──
  final PageController _pageController = PageController(viewportFraction: 1.0);

  @override
  void dispose() {
    _rootFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event, AppState appState) {
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

    final isTV = MediaQuery.of(context).size.width > 800 && 
                 MediaQuery.of(context).orientation == Orientation.landscape;

    return KeyboardListener(
      focusNode: _rootFocusNode,
      autofocus: true,
      onKeyEvent: (event) => _handleKeyEvent(event, appState),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), 
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          elevation: 0,
          centerTitle: false,
          title: Text(
            AppConstants.appName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: 0.8,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: const Icon(Icons.settings_suggest_rounded, color: Colors.white, size: 26),
                onPressed: () => Navigator.pushNamed(context, '/settings'),
              ),
            ),
          ],
        ),
        body: appState.isLoading
            ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4))))
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24), // ব্যানার ফুল উইডথ করার জন্য হরাইজনটাল প্যাডিং রিমুভ করা হয়েছে
                children: [
                  
                  // ── ১. প্রিমিয়াম ১০০% ফুল উইডথ ব্যানার সেকশন ──
                  if (appState.banners.isNotEmpty) ...[
                    SizedBox(
                      height: isTV ? 280 : 180,
                      width: double.infinity,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: appState.banners.length,
                        itemBuilder: (context, index) {
                          final banner = appState.banners[index];
                          return Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              image: banner.imageUrl != null 
                                ? DecorationImage(
                                    image: NetworkImage(banner.imageUrl!), 
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            ),
                            child: Container(
                              // ব্যানারের লেখার উপর গ্রেডিয়েন্ট শ্যাডো যাতে টেক্সট ক্লিয়ার দেখা যায়
                              decoration: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.1),
                                  const Color(0xFF0F172A).withOpacity(0.95),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ).toDecoration(),
                              padding: EdgeInsets.symmetric(
                                horizontal: isTV ? 40 : 16, 
                                vertical: 20
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: const Color(0xFF06B6D4), borderRadius: BorderRadius.circular(6)),
                                    child: const Text('FEATURED', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    banner.title,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isTV ? 28 : 20,
                                      shadows: const [Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 2))],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    banner.subtitle,
                                    style: TextStyle(
                                      color: Colors.white90, 
                                      fontSize: isTV ? 15 : 13,
                                      shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1))],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── অন্যান্য সেকশনের জন্য নিরাপদ হরাইজনটাল প্যাডিং ──
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isTV ? 40 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        
                        // ── ২. ফিচার্ড ক্যাটাগরি সেকশন ──
                        if (appState.categories.isNotEmpty) ...[
                          const _SectionHeader(title: '🔥 Featured Categories'),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 46,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: appState.categories.length,
                              itemBuilder: (context, index) {
                                final category = appState.categories[index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: ActionChip(
                                    onPressed: () {},
                                    backgroundColor: const Color(0xFF1E293B),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: Colors.white.withOpacity(0.04)),
                                    ),
                                    avatar: Text(category.icon, style: const TextStyle(fontSize: 16)),
                                    label: Text(
                                      category.name, 
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],

                        // ── ৩. লাইভ টিভি চ্যানেল গ্রিড সেকশন (ইমেজ ফিক্সড) ──
                        const _SectionHeader(title: '📺 Live Channels'),
                        const SizedBox(height: 14),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isTV ? 5 : 3, // সুন্দর রেশিওর জন্য মোবাইলে কলাম ৩ টি করা হয়েছে
                            mainAxisSpacing: isTV ? 16 : 12,
                            crossAxisSpacing: isTV ? 16 : 12,
                            childAspectRatio: isTV ? 1.2 : 0.95, 
                          ),
                          itemCount: appState.channels.length,
                          itemBuilder: (context, index) {
                            final channel = appState.channels[index];
                            final selected = appState.currentChannelIndex == index;

                            // চাইল্ড হিসেবে কাস্টম ওটিটি কার্ড পাঠানো হলো যেখানে ইমেজ ও নাম দুটোই থাকবে
                            return FocusGlowButton(
                              isTV: isTV,
                              label: "", // লেবেল ফাঁকা রাখা হলো কারণ আমরা নিচে কাস্টম চাইল্ড দিচ্ছি
                              selected: selected,
                              onTap: () {
                                appState.currentChannelIndex = index;
                                Navigator.pushNamed(context, '/player');
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // চ্যানেলের মূল ইমেজ/লোগো বক্স
                                  Expanded(
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: selected ? const Color(0xFF06B6D4) : Colors.white.withOpacity(0.05),
                                          width: selected ? 2 : 1,
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          // নেটওয়ার্ক ইমেজ উইজেট
                                          if (channel.logoUrl.isNotEmpty)
                                            Image.network(
                                              channel.logoUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                // ইমেজ লোড হতে ফেইল করলে প্লে হোল্ডার আইকন দেখাবে
                                                return const Center(child: Icon(Icons.live_tv_rounded, color: Colors.white30, size: 30));
                                              },
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24)));
                                              },
                                            )
                                          else
                                            const Center(child: Icon(Icons.live_tv_rounded, color: Colors.white30, size: 30)),
                                          
                                          // ভিডিও কোয়ালিটি ট্যাগ (HD/SD)
                                          Positioned(
                                            top: 6, right: 6,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.black70,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                channel.quality.toUpperCase(),
                                                style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 8, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // চ্যানেলের নাম
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(
                                      channel.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: selected ? const Color(0xFF06B6D4) : Colors.white,
                                        fontSize: isTV ? 14 : 12,
                                        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
    );
  }
}

// এক্সটেনশন মেথড যা লিনিয়ার গ্রেডিয়েন্টকে ডেকোরেশনে কনভার্ট করে
extension on LinearGradient {
  Decoration toDecoration() => BoxDecoration(gradient: this);
}
