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
  
  // ── ০ ইনডেক্স মানে ডিফল্টভাবে "All" সিলেক্টেড থাকবে ──
  int _selectedCategoryIndex = 0; 
  int _currentBottomNavIndex = 0; 

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

    // ── 🎯 অল চ্যানেল এবং ক্যাটাগরি ফিল্টারিং লজিক ──
    // ডিফল্টভাবে ক্যাটাগরি লিস্টের শুরুতে "All" অপশন যোগ করা হচ্ছে
    final List<dynamic> extendedCategories = [];
    if (appState.categories.isNotEmpty) {
      extendedCategories.add({'name': 'All', 'icon': '🌐'}); // কাস্টম অল অপশন
      extendedCategories.addAll(appState.categories.map((c) => {'name': c.name, 'icon': c.icon}));
    }

    // কারেন্ট সিলেক্টেড ক্যাটাগরির নাম বের করা
    final String currentCategoryName = extendedCategories.isNotEmpty
        ? extendedCategories[_selectedCategoryIndex]['name']
        : 'All';

    // যদি "All" সিলেক্ট থাকে তবে সব চ্যানেল আসবে, অন্যথায় ক্যাটাগরি অনুযায়ী ফিল্টার হবে
    final filteredChannels = appState.channels.where((channel) {
      if (currentCategoryName == 'All' || currentCategoryName.isEmpty) return true;
      return channel.category.toLowerCase() == currentCategoryName.toLowerCase();
    }).toList();

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
                padding: const EdgeInsets.only(bottom: 24), 
                children: [
                  
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
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withOpacity(0.1),
                                    const Color(0xFF0F172A).withOpacity(0.95),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
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
                                      color: Colors.white.withOpacity(0.9), 
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

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isTV ? 40 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        
                        // ── ২. ক্যাটাগরি সেকশন ("All" অপশন সহ) ──
                        if (extendedCategories.isNotEmpty) ...[
                          const _SectionHeader(title: '🔥 Featured Categories'),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 46,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: extendedCategories.length,
                              itemBuilder: (context, index) {
                                final category = extendedCategories[index];
                                final isSelected = _selectedCategoryIndex == index;
                                
                                return Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: ActionChip(
                                    onPressed: () {
                                      setState(() {
                                        _selectedCategoryIndex = index;
                                      });
                                    },
                                    backgroundColor: isSelected ? const Color(0xFF06B6D4) : const Color(0xFF1E293B),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.04),
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                    ),
                                    avatar: Text(category['icon'], style: const TextStyle(fontSize: 16)),
                                    label: Text(
                                      category['name'], 
                                      style: TextStyle(
                                        color: isSelected ? Colors.black : Colors.white, 
                                        fontWeight: FontWeight.w600, 
                                        fontSize: 13
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],

                        // ── ৩. লাইভ টিভি চ্যানেল গ্রিড সেকশন ──
                        _SectionHeader(title: '📺 $currentCategoryName Channels'),
                        const SizedBox(height: 14),
                        
                        filteredChannels.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Center(child: Text('No channels available in this category.', style: TextStyle(color: Colors.grey))),
                              )
                            : GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: isTV ? 5 : 3, 
                                  mainAxisSpacing: isTV ? 16 : 12,
                                  crossAxisSpacing: isTV ? 16 : 12,
                                  childAspectRatio: isTV ? 1.2 : 0.95, 
                                ),
                                itemCount: filteredChannels.length,
                                itemBuilder: (context, index) {
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
                                          if (channel.logoUrl.isNotEmpty)
                                            Image.network(
                                              channel.logoUrl,
                                              fit: BoxFit.contain, 
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
                              ),
                      ],
                    ),
                  ),
                ],
              ),
        
        bottomNavigationBar: isTV 
            ? null 
            : BottomNavigationBar(
                currentIndex: _currentBottomNavIndex,
                backgroundColor: const Color(0xFF0F172A),
                selectedItemColor: const Color(0xFF06B6D4), 
                unselectedItemColor: Colors.grey.shade500,
                type: BottomNavigationBarType.fixed,
                onTap: (index) {
                  setState(() {
                    _currentBottomNavIndex = index;
                  });
                  if (index == 3) {
                    Navigator.pushNamed(context, '/settings');
                  }
                },
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.live_tv_rounded), label: 'Live TV'),
                  BottomNavigationBarItem(icon: Icon(Icons.movie_creation_rounded), label: 'Movies'),
                  BottomNavigationBarItem(icon: Icon(Icons.video_library_rounded), label: 'Series'),
                  BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
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
