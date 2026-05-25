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
  final PageController _pageController = PageController(viewportFraction: 0.92);

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
    final theme = Theme.of(context);

    // রেসপনসিভ স্ক্রিন কন্টিনিউয়াম চেক
    final isTV = MediaQuery.of(context).size.width > 800 && 
                 MediaQuery.of(context).orientation == Orientation.landscape;

    return KeyboardListener(
      focusNode: _rootFocusNode,
      onKeyEvent: (event) => _handleKeyEvent(event, appState),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // ওটিটি প্রিমিয়াম ব্যাকগ্রাউন্ড
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
                padding: EdgeInsets.symmetric(
                  horizontal: isTV ? 40 : 16, 
                  vertical: 12,
                ),
                children: [
                  // ── প্রিমিয়াম স্লাইডিং ব্যানার সেকশন ──
                  if (appState.banners.isNotEmpty) ...[
                    SizedBox(
                      height: isTV ? 240 : 160,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: appState.banners.length,
                        itemBuilder: (context, index) {
                          final banner = appState.banners[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                image: banner.imageUrl != null 
                                  ? DecorationImage(image: NetworkImage(banner.imageUrl!), fit: BoxFit.cover)
                                  : null,
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF06B6D4).withOpacity(0.8),
                                    const Color(0xFF0F172A).withOpacity(0.95),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 6)),
                                ],
                              ),
                              padding: const EdgeInsets.all(24),
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
                                      fontSize: isTV ? 26 : 18,
                                      shadows: [Shadow(color: Colors.black45, blurRadius: 4, offset: const Offset(0, 2))],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    banner.subtitle,
                                    style: TextStyle(color: Colors.white70, fontSize: isTV ? 14 : 12),
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
                    const SizedBox(height: 28),
                  ],

                  // ── ফিসার্ড ক্যাটাগরি সেকশন ──
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
                              elevation: 0,
                              pressElevation: 4,
                              backgroundColor: const Color(0xFF1E293B),
                              shadowColor: Colors.transparent,
                              surfaceTintColor: Colors.transparent,
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
                    const SizedBox(height: 32),
                  ],

                  // ── লাইভ টিভি চ্যানেল গ্রিড সেকশন ──
                  const _SectionHeader(title: '📺 Live Channels'),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isTV ? 4 : 2, // টিভিতে ৪ কলাম, মোবাইলে ২ কলাম
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: isTV ? 1.3 : 1.15,
                    ),
                    itemCount: appState.channels.length,
                    itemBuilder: (context, index) {
                      final channel = appState.channels[index];
                      final selected = appState.currentChannelIndex == index;

                      return FocusGlowButton(
                        isTV: isTV,
                        label: channel.name,
                        icon: Icons.play_arrow_rounded,
                        selected: selected,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF06B6D4).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            channel.quality.toUpperCase(),
                            style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        onTap: () {
                          appState.currentChannelIndex = index;
                          Navigator.pushNamed(context, '/player');
                        },
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }
}

// ── সেকশন হেডার কম্পোনেন্ট ──
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
