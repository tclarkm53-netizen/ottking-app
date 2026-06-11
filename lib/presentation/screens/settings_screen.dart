// lib/presentation/screens/settings_screen.dart
// TV-only settings — always landscape
// ── Widgets আলাদা ফাইলে: settings_screen_widgets/ ──

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../providers/app_state.dart';
import 'settings_screen_widgets/settings_nav_sidebar.dart';
import 'settings_screen_widgets/settings_account_section.dart';
import 'settings_screen_widgets/settings_tv_section.dart';
import 'settings_screen_widgets/settings_system_section.dart';
import 'settings_screen_widgets/settings_status_footer.dart';

// Settings sections enum
enum _Section { account, tvSettings, system }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FocusNode _root = FocusNode(debugLabel: 'settings-root');
  _Section _activeSection = _Section.account;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _root.dispose();
    super.dispose();
  }

  void _handleKey(KeyEvent e) {
    if (e is! KeyDownEvent) return;
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      FocusScope.of(context).nextFocus();
    } else if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      FocusScope.of(context).previousFocus();
    } else if (e.logicalKey == LogicalKeyboardKey.escape ||
        e.logicalKey == LogicalKeyboardKey.goBack) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return KeyboardListener(
      focusNode: _root,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0F19),
        body: Row(
          children: [
            // ── Left sidebar ─────────────────────────────────────────────
            SettingsNavSidebar(
              activeSection: _activeSection.index,
              onSelect: (i) =>
                  setState(() => _activeSection = _Section.values[i]),
              onBack: () => Navigator.pop(context),
            ),

            // ── Right content area ───────────────────────────────────────
            Expanded(
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 48, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section-based content
                      if (_activeSection == _Section.account)
                        SettingsAccountSection(appState: appState),

                      if (_activeSection == _Section.tvSettings)
                        SettingsTvSection(appState: appState),

                      if (_activeSection == _Section.system)
                        SettingsSystemSection(appState: appState),

                      const SizedBox(height: 32),

                      // ── Status footer সবসময় থাকে ──────────────────────
                      SettingsStatusFooter(appState: appState),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
