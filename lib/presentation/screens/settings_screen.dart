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
  final FocusNode _rootFocusNode = FocusNode(debugLabel: 'settings-root');
  _Section _activeSection = _Section.account;

  @override
  void initState() {
    super.initState();
    
    // সেটিংস স্ক্রিন সবসময় ফুল ল্যান্ডস্কেপ মোড ফোর্স করবে
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // স্ক্রিন ওপেন হওয়ার সাথে সাথে রুট ফোকাস ইনিশিয়েট করা হলো যাতে রিমোট সাথে সাথে কাজ করে
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _rootFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _rootFocusNode.dispose();
    super.dispose();
  }

  // কাস্টম কী-হ্যান্ডলার (রিমোটের ব্যাক বাটন এবং সিস্টেম এস্কেপ হ্যান্ডেল করার জন্য)
  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    // রিমোটের ব্যাক বাটন বা এস্কেপ কি প্রেস করলে নিরাপদভাবে পেছনের পেজে ফিরবে
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack) {
      _safelyPop();
    }
    
    // নোট: arrowUp এবং arrowDown হ্যান্ডলারটি ফ্ল্যাটারের ডিফল্ট FocusManager-এর ওপর 
    // ছেড়ে দেওয়া হয়েছে যাতে টিভি রিমোটে ডাবল-জাম্প বা ফোকাস স্কিপিং এরর না হয়।
  }

  void _safelyPop() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return PopScope(
      canPop: true,
      child: KeyboardListener(
        focusNode: _rootFocusNode,
        autofocus: true, // স্ক্রিন লোড হতেই রিমোট লিসেনার একটিভ করবে
        onKeyEvent: _handleKey,
        child: Scaffold(
          backgroundColor: const Color(0xFF0B0F19),
          body: Row(
            children: [
              // ── Left Sidebar (সাইডবার ফোকাস জোন) ──────────────────────────
              SettingsNavSidebar(
                activeSection: _activeSection.index,
                onSelect: (i) {
                  setState(() => _activeSection = _Section.values[i]);
                },
                onBack: _safelyPop,
              ),

              // Vertical Divider (সাইডবার ও কনটেন্টের মাঝে সূক্ষ্ম বর্ডার)
              Container(
                width: 1,
                color: Colors.white.withOpacity(0.05),
              ),

              // ── Right Content Area (কনটেন্ট স্ক্রল জোন) ─────────────────────
              Expanded(
                child: SafeArea(
                  child: FocusTraversalGroup(
                    // এটি নিশ্চিত করে যে ডানপাশের কনটেন্টের ভেতর রিমোটের ফোকাস অর্ডারে যাবে
                    policy: ReadingOrderTraversalPolicy(),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48, 
                        vertical: 32,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // অ্যাক্টিভ সেকশন অনুযায়ী স্মুথ অ্যানিমেশনের সাথে কন্টেন্ট লোড
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _buildActiveSection(appState),
                          ),

                          const SizedBox(height: 40),
                          
                          Divider(color: Colors.white.withOpacity(0.05)),
                          
                          const SizedBox(height: 16),

                          // ── Status Footer (সবসময় দৃশ্যমান থাকবে) ──────────────────
                          SettingsStatusFooter(appState: appState),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // কোড ক্লিন রাখার জন্য উইজেট বিল্ডার আলাদা করা হলো এবং ইউনিক Key দেওয়া হলো
  Widget _buildActiveSection(AppState appState) {
    switch (_activeSection) {
      case _Section.account:
        return SettingsAccountSection(key: const ValueKey('account'), appState: appState);
      case _Section.tvSettings:
        return SettingsTvSection(key: const ValueKey('tv'), appState: appState);
      case _Section.system:
        return SettingsSystemSection(key: const ValueKey('system'), appState: appState);
    }
  }
}
