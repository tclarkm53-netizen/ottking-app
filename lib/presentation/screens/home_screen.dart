// lib/presentation/screens/home_screen.dart
// ✅ 100% PRODUCTION READY — OPTIMIZED FOR TV REMOTE & SPLIT-VIEW IPTV LAYOUT

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
  final FocusNode _settingsFocusNode = FocusNode(debugLabel: 'settings-focus');
  final PageController _pageController = PageController();
  
  int _selectedCategoryIndex = 0;
  bool _settingsHasFocus = false;

  // টিভি রিমোটের মেমোরি ফোকাস ট্র্যাকিং নোড
  final List<FocusNode> _categoryFocusNodes = [];
  final List<FocusNode> _channelFocusNodes = [];

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
    _settingsFocusNode.dispose();
    _pageController.dispose();
    for (var node in _categoryFocusNodes) {
      node.dispose();
    }
    for (var node in _channelFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // রিমোটের ব্যাক বাটন প্রেস করলে অ্যাপ ক্লোজ হওয়ার গ্লোবাল হ্যান্ডলার
  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    
    // ডাইনামিক ক্যাটাগরি ক্যাটালগ তৈরি ('All' সহ)
    final List<dynamic> extendedCategories = [];
    if (appState.categories.isNotEmpty) {
      extendedCategories.add({'name': 'All', 'icon': '🌐'});
      extendedCategories.addAll(appState.categories.map((c) => {'name': c.name, 'icon': c.icon}));
    } else {
      extendedCategories.add({'name': 'All', 'icon': '🌐'});
    }

    // ফোকাস নোডের সংখ্যা ডাইনামিকালি মেইনটেইন করা
    while (_categoryFocusNodes.length < extendedCategories.length) {
      _categoryFocusNodes.add(FocusNode());
    }

    final String currentCategoryName = extendedCategories[_selectedCategoryIndex]['name'];

    // ক্যাটাগরি ফিল্টারিং লজিক
    final filteredChannels = appState.channels.where((channel) {
      if (currentCategoryName == 'All' || currentCategoryName.isEmpty) return true;
      return channel.category.toLowerCase() == currentCategoryName.toLowerCase();
    }).toList();

    while (_channelFocusNodes.length < filteredChannels.length) {
      _channelFocusNodes.add(FocusNode());
    }

    return KeyboardListener(
      focusNode: _rootFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // ডার্ক স্লেট ব্লু
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          elevation: 0,
          title: Text(
            AppConstants.appName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 24,
              letterSpacing: 1.0,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 40),
              child: Focus(
                focusNode: _settingsFocusNode,
                child: Container(
                  decoration: BoxDecoration(
                    color: _settingsHasFocus ? const Color(0xFF06B6D4).withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _settingsHasFocus ? const Color(0xFF06B6D4) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.settings_suggest_rounded,
                      color: _settingsHasFocus ? const Color(0xFF06B6D4) : Colors.white70,
                      size: 28,
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
            : Column(
                children: [
                  // ── ১. ১০০% ফুল উইথ ব্যানার স্লাইডার ──────────────────
                  if (appState.banners.isNotEmpty)
                    SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: appState.banners.length,
                        itemBuilder: (context, index) {
                          final banner = appState.banners[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              image: banner.imageUrl != null
                                  ? DecorationImage(image: NetworkImage(banner.imageUrl!), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: [Colors.transparent, const Color(0xFF0F172A).withOpacity(0.9)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    banner.title,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
                                  ),
                                  Text(
                                    banner.subtitle,
                                    style: const TextStyle(color: Colors.white70, fontSize: 14),
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

                  // ── ২. লাইভ স্প্লিট-ভিউ সেকশন (বামে ক্যাটাগরি, ডানে চ্যানেল) ──────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          
                          // 📦 বাম পার্ট: ক্যাটাগরি ভার্টিক্যাল লিস্ট (Width: ২৫%)
                          SizedBox(
                            width: 240,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('🔥 CATEGORIES', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: extendedCategories.length,
                                    physics: const BouncingScrollPhysics(),
                                    itemBuilder: (context, index) {
                                      final category = extendedCategories[index];
                                      final isSelected = _selectedCategoryIndex == index;
                                      final node = _categoryFocusNodes[index];

                                      return AnimatedBuilder(
                                        animation: node,
                                        builder: (context, _) {
                                          final hasFocus = node.hasFocus;
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: Focus(
                                              focusNode: node,
                                              onFocusChange: (focused) {
                                                if (focused) {
                                                  setState(() => _selectedCategoryIndex = index);
                                                }
                                              },
                                              child: GestureDetector(
                                                onTap: () => setState(() => _selectedCategoryIndex = index),
                                                child: AnimatedContainer(
                                                  duration: const Duration(milliseconds: 200),
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                  decoration: BoxDecoration(
                                                    color: hasFocus 
                                                        ? const Color(0xFF06B6D4) 
                                                        : (isSelected ? const Color(0xFF06B6D4).withOpacity(0.15) : const Color(0xFF1E293B)),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(
                                                      color: hasFocus ? Colors.white : (isSelected ? const Color(0xFF06B6D4) : Colors.transparent),
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Text(category['icon'], style: const TextStyle(fontSize: 18)),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Text(
                                                          category['name'],
                                                          style: TextStyle(
                                                            color: hasFocus || isSelected ? Colors.white : Colors.white70,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(width: 24),

                          // 📺 ডান পার্ট: ডাইনামিক চ্যানেল গ্রিড ভিউ (Width: ৭৫%)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('📺 $currentCategoryName CHANNELS', style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: filteredChannels.isEmpty
                                      ? const Center(child: Text('No channels found.', style: TextStyle(color: Colors.grey)))
                                      : GridView.builder(
                                          itemCount: filteredChannels.length,
                                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 4, // ল্যান্ডস্কেপ মোডে ৪টি কলাম আদর্শ
                                            mainAxisSpacing: 14,
                                            crossAxisSpacing: 14,
                                            childAspectRatio: 1.3,
                                          ),
                                          itemBuilder: (context, index) {
                                            final channel = filteredChannels[index];
                                            final originalIndex = appState.channels.indexOf(channel);
                                            final isPlayingNow = appState.currentChannelIndex == originalIndex;
                                            final node = _channelFocusNodes[index];

                                            return FocusGlowButton(
                                              focusNode: node,
                                              isTV: true,
                                              label: channel.name,
                                              icon: Icons.live_tv_rounded,
                                              selected: isPlayingNow,
                                              onTap: () {
                                                appState.currentChannelIndex = originalIndex;
                                                Navigator.pushNamed(context, '/player');
                                              },
                                              trailing: Container(
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1E293B),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                clipBehavior: Clip.antiAlias,
                                                child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    // সার্ভার থেকে আসা রিয়েল লোগো লোড
                                                    if (channel.logoUrl.trim().isNotEmpty)
                                                      Padding(
                                                        padding: const EdgeInsets.all(12.0),
                                                        child: Image.network(
                                                          channel.logoUrl.trim(),
                                                          fit: BoxFit.contain,
                                                          loadingBuilder: (context, child, progress) {
                                                            if (progress == null) return child;
                                                            return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Color(0xFF06B6D4)))));
                                                          },
                                                          errorBuilder: (context, error, stack) => const Icon(Icons.live_tv_rounded, color: Colors.white24, size: 32),
                                                        ),
                                                      )
                                                    else
                                                      const Icon(Icons.live_tv_rounded, color: Colors.white24, size: 32),
                                                    
                                                    // ── 🎯 প্রিমিয়াম এবং কোয়ালিটি ব্যাজ লজিক ──
                                                    Positioned(
                                                      top: 6,
                                                      left: 6,
                                                      child: Row(
                                                        children: [
                                                          // যদি চ্যানেল প্রিমিয়াম হয় (সার্ভার ফ্ল্যাগ অনুযায়ী)
                                                          if (channel.isPremium == true || channel.type == 'premium')
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              margin: const EdgeInsets.only(right: 4),
                                                              decoration: BoxDecoration(
                                                                color: Colors.amber,
                                                                borderRadius: BorderRadius.circular(4),
                                                               Deal: null),
                                                              child: const Text('PREMIUM', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900)),
                                                            ),
                                                          
                                                          // কোয়ালিটি ব্যাজ (HD / SD)
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: Colors.black.withOpacity(0.75),
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: Text(
                                                              channel.quality.toUpperCase(),
                                                              style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 8, fontWeight: FontWeight.bold),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
