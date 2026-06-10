// lib/presentation/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../providers/app_state.dart';
import '../widgets/tv_focus_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// সমস্যার সমাধান:
// 1. FocusScopeNode দিয়ে sidebar ও grid আলাদা focus zone
// 2. প্রতিটি widget-এ explicit D-pad key handler (onKeyEvent)
// 3. Category sidebar-এ up/down arrow navigation
// 4. Channel grid-এ arrow navigation, Left চাপলে sidebar-এ ফেরা
// 5. Back/Escape চাপলে Exit Confirmation dialog
// 6. Settings button properly focusable ও selectable
// ─────────────────────────────────────────────────────────────────────────────

enum _FocusPanel { topBar, sidebar, grid }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedCategoryIndex = 0;
  _FocusPanel _activePanel = _FocusPanel.sidebar;

  final List<FocusNode> _catNodes = [];
  final List<FocusNode> _chNodes = [];
  final FocusNode _settingsFocusNode = FocusNode(debugLabel: 'settings-btn');
  final FocusScopeNode _sidebarScope = FocusScopeNode(debugLabel: 'sidebar');
  final FocusScopeNode _gridScope = FocusScopeNode(debugLabel: 'grid');

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // App শুরুতে প্রথম category-তে focus দাও
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_catNodes.isNotEmpty) _catNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _settingsFocusNode.dispose();
    _sidebarScope.dispose();
    _gridScope.dispose();
    for (final n in _catNodes) n.dispose();
    for (final n in _chNodes) n.dispose();
    super.dispose();
  }

  // ── Exit Confirmation ──────────────────────────────────────────────────────
  Future<void> _showExitDialog() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ExitDialog(),
    );
    if (shouldExit == true) {
      await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    }
  }

  // ── Global back key handler ────────────────────────────────────────────────
  KeyEventResult _handleGlobalKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.browserBack) {
      _showExitDialog();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ── Sidebar navigation helper ──────────────────────────────────────────────
  void _moveCategoryFocus(int delta, int total) {
    final next = (_selectedCategoryIndex + delta).clamp(0, total - 1);
    if (next != _selectedCategoryIndex) {
      setState(() => _selectedCategoryIndex = next);
      _catNodes[next].requestFocus();
    }
  }

  // ── Grid navigation helper ─────────────────────────────────────────────────
  void _moveGridFocus(int currentIndex, int delta, int total, int crossCount) {
    final next = currentIndex + delta;
    if (next >= 0 && next < total) {
      _chNodes[next].requestFocus();
    }
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
      return ch.category.toLowerCase() == currentCat.toLowerCase();
    }).toList();

    while (_chNodes.length < filtered.length) {
      _chNodes.add(FocusNode(debugLabel: 'ch-${_chNodes.length}'));
    }

    return Focus(
      autofocus: true,
      onKeyEvent: _handleGlobalKey,
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              // ── Top Bar ───────────────────────────────────────────────────
              _TopBar(
                appState: appState,
                settingsFocusNode: _settingsFocusNode,
                onSettingsFocused: () =>
                    setState(() => _activePanel = _FocusPanel.topBar),
                onSettingsDownArrow: () {
                  setState(() => _activePanel = _FocusPanel.sidebar);
                  if (_catNodes.isNotEmpty) {
                    _catNodes[_selectedCategoryIndex].requestFocus();
                  }
                },
              ),

              // ── Main content ──────────────────────────────────────────────
              Expanded(
                child: appState.isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primary,
                          strokeWidth: 3,
                        ),
                      )
                    : appState.errorMessage.isNotEmpty && appState.channels.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.wifi_off_rounded,
                                    color: Colors.white38, size: 48),
                                const SizedBox(height: 16),
                                Text(
                                  'চ্যানেল লোড হয়নি',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 18),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  appState.errorMessage,
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                TextButton.icon(
                                  onPressed: () => appState.loadCatalog(),
                                  icon: const Icon(Icons.refresh_rounded,
                                      color: AppTheme.primary),
                                  label: const Text('আবার চেষ্টা করুন',
                                      style:
                                          TextStyle(color: AppTheme.primary)),
                                ),
                              ],
                            ),
                          )
                        : Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Category Sidebar ──────────────────────────
                            SizedBox(
                              width: size.width * 0.18,
                              child: FocusScope(
                                node: _sidebarScope,
                                child: _CategorySidebar(
                                  cats: cats,
                                  catNodes: _catNodes,
                                  selectedIndex: _selectedCategoryIndex,
                                  onSelect: (i) => setState(
                                      () => _selectedCategoryIndex = i),
                                  onFocused: () => setState(
                                      () => _activePanel = _FocusPanel.sidebar),
                                  onUpArrow: () =>
                                      _moveCategoryFocus(-1, cats.length),
                                  onDownArrow: () =>
                                      _moveCategoryFocus(1, cats.length),
                                  onRightArrow: () {
                                    setState(
                                        () => _activePanel = _FocusPanel.grid);
                                    if (_chNodes.isNotEmpty) {
                                      _chNodes[0].requestFocus();
                                    }
                                  },
                                  onTopExit: () {
                                    setState(() =>
                                        _activePanel = _FocusPanel.topBar);
                                    _settingsFocusNode.requestFocus();
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(width: 20),

                            // ── Channel Grid ──────────────────────────────
                            Expanded(
                              child: FocusScope(
                                node: _gridScope,
                                child: _ChannelGrid(
                                  channels: filtered,
                                  chNodes: _chNodes,
                                  appState: appState,
                                  categoryName: currentCat,
                                  onFocused: () => setState(
                                      () => _activePanel = _FocusPanel.grid),
                                  onLeftExit: () {
                                    setState(() =>
                                        _activePanel = _FocusPanel.sidebar);
                                    if (_catNodes.isNotEmpty) {
                                      _catNodes[_selectedCategoryIndex]
                                          .requestFocus();
                                    }
                                  },
                                  onMoveGrid: _moveGridFocus,
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

// ─── Exit Confirmation Dialog ─────────────────────────────────────────────────

class _ExitDialog extends StatefulWidget {
  const _ExitDialog();

  @override
  State<_ExitDialog> createState() => _ExitDialogState();
}

class _ExitDialogState extends State<_ExitDialog> {
  // 0 = থাকুন (Cancel), 1 = বের হন (Exit)
  int _focusedBtn = 1;

  final FocusNode _exitNode = FocusNode(debugLabel: 'dialog-exit');
  final FocusNode _cancelNode = FocusNode(debugLabel: 'dialog-cancel');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _exitNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _exitNode.dispose();
    _cancelNode.dispose();
    super.dispose();
  }

  KeyEventResult _onDialogKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      final next = _focusedBtn == 0 ? 1 : 0;
      setState(() => _focusedBtn = next);
      (next == 1 ? _exitNode : _cancelNode).requestFocus();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack) {
      Navigator.of(context).pop(false);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: _onDialogKey,
      child: Dialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.power_settings_new_rounded,
                    color: Colors.redAccent, size: 44),
              ),
              const SizedBox(height: 20),
              const Text(
                'অ্যাপ থেকে বের হবেন?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'আপনি কি সত্যিই অ্যাপটি বন্ধ করতে চান?',
                style: TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _DialogBtn(
                    focusNode: _cancelNode,
                    label: '  থাকুন  ',
                    isFocused: _focusedBtn == 0,
                    isDestructive: false,
                    onFocus: () => setState(() => _focusedBtn = 0),
                    onActivate: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: 16),
                  _DialogBtn(
                    focusNode: _exitNode,
                    label: '  বের হন  ',
                    isFocused: _focusedBtn == 1,
                    isDestructive: true,
                    onFocus: () => setState(() => _focusedBtn = 1),
                    onActivate: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogBtn extends StatelessWidget {
  const _DialogBtn({
    required this.focusNode,
    required this.label,
    required this.isFocused,
    required this.isDestructive,
    required this.onFocus,
    required this.onActivate,
  });

  final FocusNode focusNode;
  final String label;
  final bool isFocused;
  final bool isDestructive;
  final VoidCallback onFocus;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final accent = isDestructive ? Colors.redAccent : AppTheme.primary;
    return Focus(
      focusNode: focusNode,
      onFocusChange: (v) { if (v) onFocus(); },
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          onActivate();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: onActivate,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
          decoration: BoxDecoration(
            color: isFocused ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFocused ? accent : Colors.white24,
              width: 2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isFocused ? Colors.white : Colors.white54,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.appState,
    required this.settingsFocusNode,
    required this.onSettingsFocused,
    required this.onSettingsDownArrow,
  });

  final AppState appState;
  final FocusNode settingsFocusNode;
  final VoidCallback onSettingsFocused;
  final VoidCallback onSettingsDownArrow;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // ── Logo ────────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'OTT',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                AppConstants.appName,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),

          const Spacer(),

          // ── Auth badge ──────────────────────────────────────────────────
          if (appState.isAuthenticated && appState.userProfile != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded,
                      color: Color(0xFFEAB308), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${appState.userProfile!.email.split('@').first}  •  ${appState.userProfile!.plan}',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],

          // ── Channel count ───────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.live_tv_rounded,
                    color: AppTheme.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${appState.channels.length} চ্যানেল',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Settings button ─────────────────────────────────────────────
          _TvIconButton(
            focusNode: settingsFocusNode,
            icon: Icons.settings_rounded,
            onTap: () => Navigator.pushNamed(context, '/settings'),
            onFocused: onSettingsFocused,
            onDownArrow: onSettingsDownArrow,
          ),
        ],
      ),
    );
  }
}

class _TvIconButton extends StatefulWidget {
  const _TvIconButton({
    required this.focusNode,
    required this.icon,
    required this.onTap,
    required this.onFocused,
    required this.onDownArrow,
  });

  final FocusNode focusNode;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onFocused;
  final VoidCallback onDownArrow;

  @override
  State<_TvIconButton> createState() => _TvIconButtonState();
}

class _TvIconButtonState extends State<_TvIconButton> {
  bool _focused = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      widget.onDownArrow();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (v) {
        setState(() => _focused = v);
        if (v) widget.onFocused();
      },
      onKeyEvent: _onKey,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _focused
                ? AppTheme.primary.withOpacity(0.2)
                : AppTheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused ? AppTheme.primary : AppTheme.border,
            ),
          ),
          child: Icon(
            widget.icon,
            color: _focused ? AppTheme.primary : Colors.white70,
            size: 22,
          ),
        ),
      ),
    );
  }
}

// ─── Category Sidebar ─────────────────────────────────────────────────────────

class _CategorySidebar extends StatelessWidget {
  const _CategorySidebar({
    required this.cats,
    required this.catNodes,
    required this.selectedIndex,
    required this.onSelect,
    required this.onFocused,
    required this.onUpArrow,
    required this.onDownArrow,
    required this.onRightArrow,
    required this.onTopExit,
  });

  final List<Map<String, String>> cats;
  final List<FocusNode> catNodes;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onFocused;
  final VoidCallback onUpArrow;
  final VoidCallback onDownArrow;
  final VoidCallback onRightArrow;
  final VoidCallback onTopExit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12, top: 8),
          child: Text(
            '🔥 CATEGORIES',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: cats.length,
            // Key handler দিয়ে scroll হবে, physics বন্ধ
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, i) {
              return _CatItem(
                focusNode: catNodes[i],
                icon: cats[i]['icon']!,
                name: cats[i]['name']!,
                selected: selectedIndex == i,
                onTap: () => onSelect(i),
                onFocus: () {
                  onSelect(i);
                  onFocused();
                },
                onUpArrow: i == 0 ? onTopExit : onUpArrow,
                onDownArrow: onDownArrow,
                onRightArrow: onRightArrow,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CatItem extends StatefulWidget {
  const _CatItem({
    required this.focusNode,
    required this.icon,
    required this.name,
    required this.selected,
    required this.onTap,
    required this.onFocus,
    required this.onUpArrow,
    required this.onDownArrow,
    required this.onRightArrow,
  });

  final FocusNode focusNode;
  final String icon;
  final String name;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onFocus;
  final VoidCallback onUpArrow;
  final VoidCallback onDownArrow;
  final VoidCallback onRightArrow;

  @override
  State<_CatItem> createState() => _CatItemState();
}

class _CatItemState extends State<_CatItem> {
  bool _focused = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      widget.onUpArrow();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      widget.onDownArrow();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      widget.onRightArrow();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final active = _focused || widget.selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (v) {
          setState(() => _focused = v);
          if (v) widget.onFocus();
        },
        onKeyEvent: _onKey,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _focused
                  ? AppTheme.primary
                  : widget.selected
                      ? AppTheme.primary.withOpacity(0.15)
                      : AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? AppTheme.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Text(widget.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.name,
                    style: TextStyle(
                      color: active ? Colors.white : Colors.white60,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Channel Grid ─────────────────────────────────────────────────────────────

class _ChannelGrid extends StatelessWidget {
  const _ChannelGrid({
    required this.channels,
    required this.chNodes,
    required this.appState,
    required this.categoryName,
    required this.onFocused,
    required this.onLeftExit,
    required this.onMoveGrid,
  });

  final List channels;
  final List<FocusNode> chNodes;
  final AppState appState;
  final String categoryName;
  final VoidCallback onFocused;
  final VoidCallback onLeftExit;
  final Function(int currentIndex, int delta, int total, int crossCount)
      onMoveGrid;

  static const int _crossCount = 5;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 8, left: 4),
          child: Row(
            children: [
              Text(
                '📺 $categoryName CHANNELS',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${channels.length}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Grid ────────────────────────────────────────────────────────
        Expanded(
          child: channels.isEmpty
              ? const Center(
                  child: Text(
                    'কোনো চ্যানেল পাওয়া যায়নি',
                    style:
                        TextStyle(color: Colors.white38, fontSize: 16),
                  ),
                )
              : GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _crossCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                  ),
                  // Key handler দিয়ে scroll হবে
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: channels.length,
                  itemBuilder: (context, i) {
                    final ch = channels[i];
                    final origIdx = appState.channels.indexOf(ch);
                    final playing = appState.currentChannelIndex == origIdx;

                    return _GridCell(
                      index: i,
                      focusNode: chNodes[i],
                      crossCount: _crossCount,
                      totalCount: channels.length,
                      onFocused: onFocused,
                      // Row-এর প্রথম column-এ থাকলে Left → sidebar
                      onLeftExit:
                          i % _crossCount == 0 ? onLeftExit : null,
                      onMove: (delta) => onMoveGrid(
                          i, delta, channels.length, _crossCount),
                      onSelect: () {
                        appState.currentChannelIndex = origIdx;
                        Navigator.pushNamed(context, '/player');
                      },
                      child: TvFocusCard(
                        focusNode: chNodes[i],
                        selected: playing,
                        padding: EdgeInsets.zero,
                        onTap: () {
                          appState.currentChannelIndex = origIdx;
                          Navigator.pushNamed(context, '/player');
                        },
                        child: _ChannelCard(
                            channel: ch, isPlaying: playing),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Grid Cell Key Handler Wrapper ─────────────────────────────────────────────

class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.index,
    required this.focusNode,
    required this.crossCount,
    required this.totalCount,
    required this.onFocused,
    required this.onLeftExit,
    required this.onMove,
    required this.onSelect,
    required this.child,
  });

  final int index;
  final FocusNode focusNode;
  final int crossCount;
  final int totalCount;
  final VoidCallback onFocused;
  final VoidCallback? onLeftExit;
  final ValueChanged<int> onMove;
  final VoidCallback onSelect;
  final Widget child;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      onMove(-crossCount);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      onMove(crossCount);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      onMove(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (onLeftExit != null) {
        onLeftExit!();
      } else {
        onMove(-1);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      onSelect();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onFocusChange: (v) { if (v) onFocused(); },
      onKeyEvent: _onKey,
      child: child,
    );
  }
}

// ─── Channel Card ─────────────────────────────────────────────────────────────

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.channel, required this.isPlaying});
  final dynamic channel;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Logo
          Container(
            color: AppTheme.card,
            padding: const EdgeInsets.all(12),
            child: channel.logoUrl.trim().isNotEmpty
                ? Image.network(
                    channel.logoUrl.trim(),
                    fit: BoxFit.contain,
                    loadingBuilder: (ctx, child, prog) =>
                        prog == null ? child : _logoPlaceholder(),
                    errorBuilder: (_, __, ___) => _logoPlaceholder(),
                  )
                : _logoPlaceholder(),
          ),

          // Channel name
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.85),
                    Colors.transparent,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              child: Text(
                channel.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Badges
          Positioned(
            top: 6,
            left: 6,
            child: Row(
              children: [
                if (channel.isPremium == 1)
                  _Badge(
                    label: 'PREMIUM',
                    bg: const Color(0xFFEAB308),
                    fg: Colors.black,
                  ),
                const SizedBox(width: 3),
                _Badge(
                  label: channel.quality.toUpperCase(),
                  bg: Colors.black.withOpacity(0.7),
                  fg: AppTheme.primary,
                ),
              ],
            ),
          ),

          // Now playing overlay
          if (isPlaying)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primary, width: 2),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: _LiveDot(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _logoPlaceholder() => const Icon(
        Icons.live_tv_rounded,
        color: Colors.white24,
        size: 32,
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        label,
        style: TextStyle(
            color: fg, fontSize: 8, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 3, backgroundColor: Colors.white),
          SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
