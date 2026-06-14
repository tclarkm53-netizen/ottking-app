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

  // ক্যাটাগরির জন্য ফোকাস নোড লিস্ট
  final List<FocusNode> _catNodes = [];
  // চ্যানেলের জন্য ফোকাস নোড লিস্ট
  final List<FocusNode> _chNodes = [];

  @override
  void initState() {
    super.initState();
    // টিভির জন্য ল্যান্ডস্কেপ মোড ফিক্সড করা
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // অ্যাপ চালুর পর প্রথম ক্যাটাগরিতে অটোমেটিক ফোকাস যাবে
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
    _clearCatNodes();
    _clearChNodes();
    super.dispose();
  }

  void _clearCatNodes() {
    for (final n in _catNodes) n.dispose();
    _catNodes.clear();
  }

  void _clearChNodes() {
    for (final n in _chNodes) n.dispose();
    _chNodes.clear();
  }

  // ফোকাস নোডগুলো নিরাপদে ম্যানেজ করার মেথড (মেমোরি লিক এবং ফোকাস লস্ট হবে না)
  void _updateFocusNodes(int targetLength, List<FocusNode> nodeList, String prefix) {
    if (nodeList.length == targetLength) return;

    if (nodeList.length < targetLength) {
      while (nodeList.length < targetLength) {
        nodeList.add(FocusNode(debugLabel: '$prefix-${nodeList.length}'));
      }
    } else {
      while (nodeList.length > targetLength) {
        nodeList.removeLast().dispose();
      }
    }
  }

  // ব্যাক বাটন চাপলে টিভি অ্যাপ বন্ধ হওয়ার লজিক
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
      _clearChNodes(); // ক্যাটাগরি চেঞ্জ হলে আগের চ্যানেল নোড ক্লিয়ার
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_catNodes.isNotEmpty && _catNodes.length > index && mounted) {
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

    _updateFocusNodes(cats.length, _catNodes, 'cat');

    final currentCat = cats[_selectedCategoryIndex]['name']!;
    final filtered = appState.channels.where((ch) {
      if (currentCat == 'All') return true;
      return ch.category.trim().toLowerCase() == currentCat.trim().toLowerCase();
    }).toList();

    _updateFocusNodes(filtered.length, _chNodes, 'chan');

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
                            // ── ক্যাটাগরি সাইডবার ──────────────────────
                            SizedBox(
                              width: size.width * 0.18,
                              child: Focus(
                                onKeyEvent: (node, event) {
                                  if (event is KeyDownEvent) {
                                    // সাইডবারের একদম উপরে থাকলে আরও উপরে চাপলে সেটিংসে যাবে
                                    if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
                                        _selectedCategoryIndex == 0) {
                                      _settingsFocusNode.requestFocus();
                                      return KeyEventResult.handled;
                                    }
                                    // সাইডবার থেকে ডানে চাপলে সরাসরি প্রথম চ্যানেলে ফোকাস যাবে
                                    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                      if (_chNodes.isNotEmpty) {
                                        _chNodes[0].requestFocus();
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

                            // ── চ্যানেল গ্রিড (এখানেই মূল পরিবর্তন) ──────────────────
                            Expanded(
                              // FocusTraversalGroup টিভির রিমোটের আপ/ডাউন/লেফট/রাইট লজিক ঠিক রাখে
                              child: FocusTraversalGroup(
                                child: Focus(
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent &&
                                        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                                      // চ্যানেল লিস্টের যেকোনো জায়গা থেকে বামে চাপলে কারেন্ট ক্যাটাগরিতে ব্যাক করবে
                                      if (_catNodes.length > _selectedCategoryIndex) {
                                        _catNodes[_selectedCategoryIndex].requestFocus();
                                      }
                                      return KeyEventResult.handled;
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: ChannelGrid(
                                    channels: filtered,
                                    chNodes: _chNodes, // এই নোডগুলো গ্রিডের আইটেমে বসাতে হবে
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
