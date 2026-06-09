// lib/presentation/screens/home_screen.dart
// ✅ 100% PRODUCTION READY — FIXED FOCUS BUILDER ERRORS & FULLY OPTIMIZED FOR TV REMOTE

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
  
  int _selectedCategoryIndex = 0; 

  // রিমোট ফোকাস স্টেট ট্র্যাকিংয়ের জন্য নোড ও বুলিয়ান লিস্ট
  final FocusNode _settingsFocusNode = FocusNode(debugLabel: 'settings-focus');
  bool _settingsHasFocus = false;
  
  // ক্যাটাগরির ফোকাস ট্র্যাকিং স্টেট
  final Map<int, bool> _categoryFocusStates = {};

  @override
  void initState() {
    super.initState();
    _settingsFocusNode.addListener(() {
      setState(() {
        _settingsHasFocus = _settingsFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _rootFocusNode.dispose();
    _pageController.dispose();
    _settingsFocusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event, AppState appState, List<dynamic> filteredChannels) {
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      return;
    }

    if (key == LogicalKeyboardKey.arrowRight && FocusScope.of(context).focusedChild == null) {
      appState.switchChannel(1);
    } else if (key == LogicalKeyboardKey.arrowLeft && FocusScope.of(context).focusedChild == null) {
      appState.switchChannel(-1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    // মোবাইল ও টিভি উভয় ডিভাইসের জন্য ল্যান্ডস্কেপ টিভি মোড ফোর্স করা হলো
    const bool isTV = true; 

    final List<dynamic> extendedCategories = [];
    if (appState.categories.isNotEmpty) {
      extendedCategories.add({'name': 'All', 'icon': '🌐'}); 
      extendedCategories.addAll(appState.categories.map((c) => {'name': c.name, 'icon': c.icon}));
    }

    final String currentCategoryName = extendedCategories.isNotEmpty
        ? extendedCategories[_selectedCategoryIndex]['name']
        : 'All';

    final filteredChannels = appState.channels.where((channel) {
      if (currentCategoryName == 'All' || currentCategoryName.isEmpty) return true;
      return channel.category.toLowerCase() == currentCategoryName.toLowerCase();
    }).toList();

    return KeyboardListener(
      focusNode: _rootFocusNode,
      autofocus: true,
      onKeyEvent: (event) => _handleKeyEvent(event, appState, filteredChannels),
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
              padding: const EdgeInsets.only(right: 24),
              // ── 🎯 ফিক্সড সেটিংস বাটন ফোকাস লজিক ──
              child: Focus(
                focusNode: _settingsFocusNode,
                child: Container(
                  decoration: BoxDecoration(
                    color: _settingsHasFocus ? const Color(0xFF06B6D4).withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _settingsHasFocus ? const Color(0xFF06B6D4) : Colors.transparent, 
                      width: 1.5,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.settings_suggest_rounded, 
                      color: _settingsHasFocus ? const Color(0xFF06B6D4) : Colors.white, 
                      size: 26,
                    ),
                    onPressed: () => Navigator.pushNamed(context, '/settings'),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: appState.isLoading
            ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4))))
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  
                  // ১. ব্যানার স্লাইডার সেকশন
                  if (appState.banners.isNotEmpty)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 240,
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
                                    ? DecorationImage(image: NetworkImage(banner.imageUrl!), fit: BoxFit.cover)
                                    : null,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.black.withOpacity(0.1), const Color(0xFF0F172A).withOpacity(0.95)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
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
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      banner.subtitle,
                                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
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
                    ),

                  // ২. ক্যাটাগরি সেকশন (D-Pad রিমোট ফোকাস ফিক্সড)
                  if (extendedCategories.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 40, right: 40, top: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHeader(title: '🔥 Featured Categories'),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 48,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                itemCount: extendedCategories.length,
                                itemBuilder: (context, index) {
                                  final category = extendedCategories[index];
                                  final isSelected = _selectedCategoryIndex == index;
                                  final hasFocus = _categoryFocusStates[index] ?? false;
                                  
                                  // ── 🎯 ফিক্সড ক্যাটাগরি চিপ ফোকাস লজিক ──
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Focus(
                                      onFocusChange: (focused) {
                                        setState(() {
                                          _categoryFocusStates[index] = focused;
                                        });
                                      },
                                      child: ActionChip(
                                        onPressed: () {
                                          setState(() => _selectedCategoryIndex = index);
                                        },
                                        backgroundColor: hasFocus 
                                            ? const Color(0xFF06B6D4) 
                                            : (isSelected ? const Color(0xFF06B6D4).withOpacity(0.4) : const Color(0xFF1E293B)),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          side: BorderSide(
                                            color: hasFocus ? Colors.white : (isSelected ? const Color(0xFF06B6D4) : Colors.white.withOpacity(0.05)),
                                            width: hasFocus ? 2.0 : 1.0,
                                          ),
                                        ),
                                        avatar: Text(category['icon'], style: const TextStyle(fontSize: 16)),
                                        label: Text(
                                          category['name'], 
                                          style: TextStyle(
                                            color: hasFocus || isSelected ? Colors.white : Colors.white70, 
                                            fontWeight: FontWeight.w600, 
                                            fontSize: 13
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),

                  // ৩. লাইভ চ্যানেল হেডার সেকশন
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(title: '📺 $currentCategoryName Channels'),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),

                  // ৪. চ্যানেল গ্রিড ভিউ (SliverGrid রিমোট কন্ট্রোল সাপোর্ট)
                  filteredChannels.isEmpty
                      ? const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Center(child: Text('No channels available in this category.', style: TextStyle(color: Colors.grey))),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 4),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5, 
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 1.2, 
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final channel = filteredChannels[index];
                                final originalIndex = appState.channels.indexOf(channel);
                                final selected = appState.currentChannelIndex == originalIndex;

                                return FocusGlowButton(
                                  isTV: isTV,
                                  label: channel.name, 
                                  icon: Icons.live_tv_rounded,
                                  selected: selected,
                                  onTap: () {
                                    appState.currentChannelIndex = originalIndex;
                                    Navigator.pushNamed(context, '/player');
                                  },
                                  trailing: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        if (channel.logoUrl.trim().isNotEmpty)
                                          Image.network(
                                            channel.logoUrl.trim(),
                                            fit: BoxFit.contain, 
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return const Center(
                                                child: SizedBox(
                                                  width: 16, height: 16,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
                                                  ),
                                                ),
                                              );
                                            },
                                            errorBuilder: (context, error, stackTrace) {
                                              return const Center(child: Icon(Icons.live_tv_rounded, color: Colors.white30, size: 24));
                                            },
                                          )
                                        else
                                          const Center(child: Icon(Icons.live_tv_rounded, color: Colors.white30, size: 24)),
                                        
                                        Positioned(
                                          top: 4, right: 4,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.black87,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              channel.quality.toUpperCase(),
                                              style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 7, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              childCount: filteredChannels.length,
                            ),
                          ),
                        ),
                  
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
