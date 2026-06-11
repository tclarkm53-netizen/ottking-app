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

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack) {
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    }
  }

  void _changeCategory(int index) {
    if (_selectedCategoryIndex == index) return;
    setState(() {
      _selectedCategoryIndex = index;
      
      // নোড ক্লিয়ার করার সময় ডিসপোজ করা জরুরি
      for (final n in _chNodes) n.dispose();
      _chNodes.clear();
    });
    
    // ক্যাটাগরি চেঞ্জ হওয়ার পর গ্রিড রেন্ডার হতে সামান্য সময় নেয়, তাই একটু দেরিতে ফোকাস দেওয়া ভালো
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_catNodes.isNotEmpty && _catNodes.length > index) {
        _catNodes[index].requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final size = MediaQuery.of(context).size;

    final cats = <Map<String, String>>[
      {'name': 'All', 'icon': '🌐'},
      ...appState.categories.map((c) => {'name': c.name, 'icon': c.icon}),
    ];

    while (_catNodes.length < cats.length) {
      _catNodes.add(FocusNode(debugLabel: 'cat-${_catNodes.length}'));
    }

    final currentCat = cats[_selectedCategoryIndex]['name']!;
    final filtered = appState.channels.where((ch) {
      if (currentCat == 'All') return true;
      return ch.category.trim().toLowerCase() == currentCat.trim().toLowerCase();
    }).toList();

    // ফিল্টারড লিস্ট অনুযায়ী নতুন ফোকাস নোড তৈরি
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
              HomeTopBar(
                appState: appState,
                settingsFocusNode: _settingsFocusNode,
              ),
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
                            // ── Sidebar (ক্যাটাগরি) ──────────────────────
                            SizedBox(
                              width: size.width * 0.18,
                              child: Focus(
                                onKeyEvent: (node, event) {
                                  if (event is KeyDownEvent) {
                                    if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
                                        _selectedCategoryIndex == 0) {
                                      _settingsFocusNode.requestFocus();
                                      return KeyEventResult.handled;
                                    }
                                    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                      if (_chNodes.isNotEmpty) {
                                        _chNodes[0].requestFocus(); // প্রথম চ্যানেলে ফোকাস যাবে
                                        return KeyEventResult.handled;
                                      }
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

                            // ── Channel Grid (চ্যানেল লিস্ট) ──────────────────
                            Expanded(
                              child: FocusTraversalGroup(
                                child: Focus(
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent &&
                                        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                                      // বামে চাপলে বর্তমান সিলেক্টেড ক্যাটাগরিতে ফেরত যাবে
                                      _catNodes[_selectedCategoryIndex].requestFocus();
                                      return KeyEventResult.handled;
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: ChannelGrid(
                                    channels: filtered,
                                    chNodes: _chNodes, // এই নোডগুলো ChannelGrid-এর ভেতর পাস হচ্ছে
                                    appState: appState,
                                    categoryName: currentCat,
                                  ),
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
