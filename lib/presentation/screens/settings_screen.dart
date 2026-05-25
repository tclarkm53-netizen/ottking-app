// lib/presentation/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/channel_model.dart'; // Note: Keeping your dynamic subscription types intact
import '../providers/app_state.dart';
import '../widgets/focus_glow_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'settings-root');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      FocusScope.of(context).nextFocus();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      FocusScope.of(context).previousFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);

    // রেসপনসিভ টিভি মোড ডিটেকশন 
    final isTV = MediaQuery.of(context).size.width > 800 && 
                 MediaQuery.of(context).orientation == Orientation.landscape;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // ইমেজের মতো প্রিমিয়াম ডার্ক ব্যাকগ্রাউন্ড
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            isTV ? 'oTtking সেটিংস' : 'General Settings',
            style: TextStyle(
              fontSize: isTV ? 24 : 20, 
              fontWeight: FontWeight.bold, 
              color: Colors.white,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isTV ? 32 : 16, 
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── ১. সাধারণ সেটিংস (General) ──────────────────────────────────
              _SectionTitle(title: isTV ? 'সাধারণ' : 'General', isTV: isTV),
              const SizedBox(height: 12),
              _buildLayoutWrapper(
                isTV: isTV,
                children: [
                  FocusGlowButton(
                    isTV: isTV,
                    label: appState.themeMode == ThemeMode.dark
                        ? 'Switch to Light Mode'
                        : 'Switch to Dark Mode',
                    icon: appState.themeMode == ThemeMode.dark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    onTap: appState.toggleTheme,
                  ),
                  if (appState.isSmartTv)
                    FocusGlowButton(
                      isTV: isTV,
                      label: appState.bootToPlayer
                          ? 'Disable Direct Player Boot'
                          : 'Enable Direct Player Boot',
                      icon: Icons.tv_rounded,
                      onTap: () => appState.setBootToPlayer(!appState.bootToPlayer),
                    ),
                ],
              ),

              const SizedBox(height: 28),

              // ── ২. অ্যাকাউন্ট এবং অ্যাক্সেস (Account & Access) ─────────────────────
              _SectionTitle(title: isTV ? 'অ্যাকাউন্ট এবং অ্যাক্সেস' : 'Account & Access', isTV: isTV),
              const SizedBox(height: 12),
              if (appState.isAuthenticated && appState.userProfile != null) ...[
                _AccountInfoCard(profile: appState.userProfile!, theme: theme, isTV: isTV),
                const SizedBox(height: 12),
              ],
              _buildLayoutWrapper(
                isTV: isTV,
                children: [
                  FocusGlowButton(
                    isTV: isTV,
                    label: appState.isAuthenticated
                        ? 'Switch Account / Logout'
                        : 'Login / Register',
                    icon: Icons.account_circle_outlined,
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => const AuthOverlayDialog(),
                    ),
                  ),
                  FocusGlowButton(
                    isTV: isTV,
                    label: isTV ? 'সাবক্রিপশন প্ল্যান দেখুন' : 'View Subscription Plans',
                    icon: Icons.card_membership_rounded,
                    onTap: () => _showSubscriptions(context, appState.plans),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── ৩. সাপোর্ট (Support) ─────────────────────────────────────────
              _SectionTitle(title: isTV ? 'সাপোর্ট' : 'Support', isTV: isTV),
              const SizedBox(height: 12),
              _buildLayoutWrapper(
                isTV: isTV,
                children: [
                  FocusGlowButton(
                    isTV: isTV,
                    label: isTV ? 'ক্যাটালগ পুনরায় লোড করুন' : 'Reload Channel Catalog',
                    icon: Icons.refresh_rounded,
                    onTap: () {
                      appState.loadCatalog();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Refreshing catalog…')),
                      );
                    },
                  ),
                  FocusGlowButton(
                    isTV: isTV,
                    label: isTV ? 'কাস্টমার সাপোর্ট' : 'Contact Support',
                    icon: Icons.headset_mic_outlined,
                    onTap: () async {
  										final Uri url = Uri.parse("https://ottking.top/");

  											await launchUrl(url,mode: LaunchMode.externalApplication,
  										);
												},
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── ৪. প্ল্যাটফর্ম স্ট্যাটাস (Platform Status) ─────────────────────────
              _SectionTitle(title: isTV ? 'প্ল্যাটফর্ম স্ট্যাটাস' : 'Platform Status', isTV: isTV),
              const SizedBox(height: 12),
              _buildStatusFooter(isTV, appState, theme),
            ],
          ),
        ),
      ),
    );
  }

  // টিভি ও মোবাইলের রেসপনসিভ গ্রিড র‍্যাপার মেথড
  Widget _buildLayoutWrapper({required bool isTV, required List<Widget> children}) {
    if (isTV) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children.map((widget) => Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: widget,
          ),
        )).toList(),
      );
    }
    return Column(
      children: children.map((widget) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: widget,
      )).toList(),
    );
  }

  // ইমেজের ডিজাইন অনুযায়ী প্ল্যাটফর্ম স্ট্যাটাস বার
  Widget _buildStatusFooter(bool isTV, AppState appState, ThemeData theme) {
    final statusContent = [
      _buildStatusBadge(
        Icons.check_circle_outline, 
        appState.isSmartTv ? 'Smart TV remote navigation enabled' : 'Mobile touch UI active'
      ),
      if (isTV) const SizedBox(width: 24) else const SizedBox(height: 8),
      _buildStatusBadge(
        appState.errorMessage.isEmpty ? Icons.cloud_done_outlined : Icons.warning_amber_rounded,
        appState.errorMessage.isEmpty ? 'Secure API sync active' : 'API sync failed',
        color: appState.errorMessage.isEmpty ? const Color(0xFF06B6D4) : theme.colorScheme.error,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isTV) 
            Row(children: statusContent) 
          else 
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: statusContent),
          if (appState.errorMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              appState.errorMessage,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildStatusBadge(IconData icon, String text, {Color color = const Color(0xFF06B6D4)}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }

  // প্রিমিয়াম পপআপ সাবক্রিপশন লিস্ট डायलॉग
  void _showSubscriptions(BuildContext context, List<dynamic> plans) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Premium Plans', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 380,
          child: plans.isEmpty
              ? const Text('No plans available.', style: TextStyle(color: Colors.white60))
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(plan.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFF06B6D4).withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                                child: Text(plan.badge, style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(plan.price, style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text(plan.description, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF06B6D4))),
          ),
        ],
      ),
    );
  }
}

// ── Account info card ─────────────────────────────────────────────────────────

class _AccountInfoCard extends StatelessWidget {
  const _AccountInfoCard({required this.profile, required this.theme, required this.isTV});

  final dynamic profile;
  final ThemeData theme;
  final bool isTV;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isTV ? MediaQuery.of(context).size.width * 0.46 : double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.15)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF06B6D4).withOpacity(0.2),
            child: Text(
              profile.email.isNotEmpty ? profile.email[0].toUpperCase() : '?',
              style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.email, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                const SizedBox(height: 2),
                Text('Subscription Plan: ${profile.plan}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Auth dialog ───────────────────────────────────────────────────────────────

class AuthOverlayDialog extends StatefulWidget {
  const AuthOverlayDialog({super.key});

  @override
  State<AuthOverlayDialog> createState() => _AuthOverlayDialogState();
}

class _AuthOverlayDialogState extends State<AuthOverlayDialog> {
  bool _isRegister = false;
  bool _isLoading = false;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState appState) async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);

    if (_isRegister) {
      await appState.register(_emailCtrl.text.trim(), _passCtrl.text);
    } else {
      await appState.login(_emailCtrl.text.trim(), _passCtrl.text);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (appState.errorMessage.isEmpty) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(_isRegister ? 'Create account' : 'Sign in securely', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.email_outlined, color: Colors.white38),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF06B6D4))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.lock_outline, color: Colors.white38),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF06B6D4))),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _isRegister = !_isRegister),
              child: Text(
                _isRegister ? 'Already have an account? Sign in' : 'Need an account? Register',
                style: const TextStyle(color: Color(0xFF06B6D4)),
              ),
            ),
            if (appState.errorMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(appState.errorMessage, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        if (appState.isAuthenticated)
          TextButton(
            onPressed: () {
              appState.logout();
              Navigator.pop(context);
            },
            child: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
        ),
        FilledButton(
          onPressed: _isLoading ? null : () => _submit(appState),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
          child: _isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              : Text(_isRegister ? 'Register' : 'Login', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.isTV});

  final String title;
  final bool isTV;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: isTV ? 18 : 14,
        fontWeight: FontWeight.bold,
        color: Colors.white60,
        letterSpacing: 0.5,
      ),
    );
  }
}
