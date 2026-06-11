// lib/presentation/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../providers/app_state.dart';
import 'home_screen_widgets/home_top_bar.dart';
import 'home_screen_widgets/category_sidebar.dart';
import 'home_screen_widgets/channel_grid.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FocusNode _rootFocusNode = FocusNode(debugLabel: 'home-root');
  
  // সেটিংস বাটনের জন্য একটি ডেডিকেটেড ফোকাস নোড
  final FocusNode _settingsFocusNode = FocusNode(debugLabel: 'home-settings');
  
  int _selectedCategoryIndex = 0;

  final List<FocusNode> _catNodes = [];
  final List<FocusNode> _chNodes = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // প্রথম ফ্রেমে 'All' ক্যাটাগরিতে ফোকাস সেট করার জন্য
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_catNodes.isNotEmpty && mounted) {
        _catNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _rootFocusNode.dispose();
    _settingsFocusNode.dispose();
    for (final n in _catNodes) n.dispose();
    for (final n in _chNodes) n.dispose();
    super.dispose();
  }

  // রুট কি-বোর্ড ইভেন্ট হ্যান্ডলার (Back বাটন এক্সিট)
  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack) {
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    }
  }

  // ক্যাটাগরি চেঞ্জ করার মেথড
  void _changeCategory(int index) {
    if (_selectedCategoryIndex == index) return;
    setState(() {
      _selectedCategoryIndex = index;
      
      // নতুন ক্যাটাগরি সিলেক্ট হলে চ্যানেলের ফোকাস নোডগুলো রিসেট করতে হবে 
      // যাতে ওল্ড ইনডেক্সের নোড নিয়ে ক্র্যাশ না করে
      for (final n in _chNodes) n.dispose();
      _chNodes.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final size = MediaQuery.of(context).size;

    // ১. ক্যাটাগরি লিস্ট প্রিপেয়ার করা
    final cats = <Map<String, String>>[
      {'name': 'All', 'icon': '🌐'},
      ...appState.categories.map((c) => {'name': c.name, 'icon': c.icon}),
    ];

    // ক্যাটাগরি অনুযায়ী ফোকাস নোড ম্যানেজমেন্ট
    while (_catNodes.length < cats.length) {
      _catNodes.add(FocusNode(debugLabel: 'cat-${_catNodes.length}'));
    }

    // ২. রিয়েল-টাইম চ্যানেল ফিল্টারিং (ফিক্সড লজিক)
    final currentCat = cats[_selectedCategoryIndex]['name']!;
    final filtered = appState.channels.where((ch) {
      if (currentCat == 'All') return true;
      // category name এর স্পেস এবং কেইস সেন্সিটিভিটি হ্যান্ডেল করা হয়েছে
      return ch.category.trim().toLowerCase() == currentCat.trim().toLowerCase();
    }).toList();

    // ফিল্টারড চ্যানেলের সংখ্যার ওপর ভিত্তি করে নোড জেনারেট করা
    while (_chNodes.length < filtered.length) {
      _chNodes.add(FocusNode(debugLabel: 'chan-${_chNodes.length}'));
    }

    return KeyboardListener(
      focusNode: _rootFocusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              // ── Top bar (সেটিংস ফোকাস নোড পাস করা হয়েছে) ────────────────
              HomeTopBar(
                appState: appState,
                settingsFocusNode: _settingsFocusNode,
              ),

              // ── Main split view ──────────────────────────────────────
              Expanded(
                child: appState.isLoading
                    ? Center(
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
                            // ── Sidebar (ক্যাটাগরি লিস্ট) ──────────────────────
                            SizedBox(
                              width: size.width * 0.18,
                              child: Focus(
                                // অল বা প্রথম ক্যাটাগরি থেকে UP টিপলে সেটিংসে যাবে
                                onKeyEvent: (node, event) {
                                  if (event is KeyDownEvent &&
                                      event.logicalKey == LogicalKeyboardKey.arrowUp &&
                                      _selectedCategoryIndex == 0) {
                                    _settingsFocusNode.requestFocus();
                                    return KeyEventResult.handled;
                                  }
                                  // রাইট বাটন টিপলে চ্যানেল গ্রিডের প্রথম চ্যানেলে ফোকাস যাবে
                                  if (event is KeyDownEvent &&
                                      event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                    if (_chNodes.isNotEmpty) {
                                      _chNodes[0].requestFocus();
                                      return KeyEventResult.handled;
                                    }
                                  }
                                  return KeyEventResult.ignored;
                                },
                                child: CategorySidebar(
                                  cats: cats,
                                  catNodes: _catNodes,
                                  selectedIndex: _selectedCategoryIndex,
                                  onSelect: _changeCategory,
                                ),
                              ),
                            ),

                            const SizedBox(width: 20),

                            // ── Channel grid (চ্যানেল লিস্ট) ──────────────────
                            Expanded(
                              child: Focus(
                                // চ্যানেল গ্রিডে থাকা অবস্থায় লেফট ক্লিক করলে আবার ক্যাটাগরিতে ফিরে আসবে
                                onKeyEvent: (node, event) {
                                  if (event is KeyDownEvent &&
                                      event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                                    // চ্যানেল লিস্টের একদম বামের কলামে থাকলে ক্যাটাগরিতে ব্যাক করবে
                                    // (সাধারণত GridView এর কলাম সংখ্যা অনুযায়ী হ্যান্ডেল করা ভালো, 
                                    // তবে ফোর্সভলি ক্যাটাগরি নোড রিকোয়েস্ট করা হলো নিরাপদ নেভিগেশনের জন্য)
                                    _catNodes[_selectedCategoryIndex].requestFocus();
                                    return KeyEventResult.handled;
                                  }
                                  return KeyEventResult.ignored;
                                },
                                child: ChannelGrid(
                                  channels: filtered,
                                  chNodes: _chNodes,
                                  appState: appState,
                                  categoryName: currentCat,
                                ),
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
