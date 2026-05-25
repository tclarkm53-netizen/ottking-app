// lib/presentation/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

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

    final isTV = MediaQuery.of(context).size.width > 800 && 
                 MediaQuery.of(context).orientation == Orientation.landscape;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0F19),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0B0F19),
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            isTV ? 'oTtking সেটিংস' : 'Settings',
            style: TextStyle(
              fontSize: isTV ? 26 : 22, 
              fontWeight: FontWeight.bold, 
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isTV ? 48 : 20, 
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (appState.isAuthenticated && appState.userProfile != null) ...[
                _SectionTitle(title: isTV ? 'অ্যাকাউন্ট এবং অ্যাক্সেস' : 'Account & Access', isTV: isTV),
                const SizedBox(height: 14),
                _AccountInfoCard(profile: appState.userProfile!, isTV: isTV),
                const SizedBox(height: 24),
              ],

              _SectionTitle(title: isTV ? 'সাধারণ সেটিংস' : 'General Settings', isTV: isTV),
              const SizedBox(height: 12),
              _buildGridOrColumn(
                isTV: isTV,
                children: [
                  _SettingsTile(
                    isTV: isTV,
                    title: 'App Theme',
                    subtitle: appState.themeMode == ThemeMode.dark ? 'Dark Mode Active' : 'Light Mode Active',
                    icon: appState.themeMode == ThemeMode.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    onTap: appState.toggleTheme,
                  ),
                  if (appState.isSmartTv)
                    _SettingsTile(
                      isTV: isTV,
                      title: 'Direct Player Boot',
                      subtitle: appState.bootToPlayer ? 'Enabled' : 'Disabled',
                      icon: Icons.tv_rounded,
                      trailing: Switch(
                        value: appState.bootToPlayer,
                        activeColor: const Color(0xFF06B6D4),
                        onChanged: (val) => appState.setBootToPlayer(val),
                      ),
                      onTap: () => appState.setBootToPlayer(!appState.bootToPlayer),
                    ),
                  _SettingsTile(
                    isTV: isTV,
                    title: appState.isAuthenticated ? 'Account Session' : 'Account Login',
                    subtitle: appState.isAuthenticated ? 'Tap to switch account or logout' : 'Sign in to access premium channels',
                    icon: Icons.account_circle_rounded,
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => const AuthOverlayDialog(),
                    ),
                  ),
                  _SettingsTile(
                    isTV: isTV,
                    title: 'Subscription Plans',
                    subtitle: 'Explore active packages & pricing',
                    icon: Icons.card_membership_rounded,
                    onTap: () => _showSubscriptions(context, appState.plans),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _SectionTitle(title: isTV ? 'সাপোর্ট এবং সিস্টেম' : 'Support & System', isTV: isTV),
              const SizedBox(height: 12),
              _buildGridOrColumn(
                isTV: isTV,
                children: [
                  _SettingsTile(
                    isTV: isTV,
                    title: 'Refresh Catalog',
                    subtitle: 'Force update channel live streams',
                    icon: Icons.sync_rounded,
                    onTap: () {
                      appState.loadCatalog();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Refreshing channel catalog...'),
                          backgroundColor: Color(0xFF1E293B),
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    isTV: isTV,
                    title: 'Customer Support',
                    subtitle: 'Get assistance regarding your stream',
                    icon: Icons.support_agent_rounded,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Connecting to support desk...'),
                          backgroundColor: Color(0xFF1E293B),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 32),
              _buildStatusFooter(isTV, appState, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridOrColumn({required bool isTV, required List<Widget> children}) {
    if (isTV) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 3.8,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: children,
      );
    }
    return Column(
      children: children.map((w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w)).toList(),
    );
  }

  Widget _buildStatusFooter(bool isTV, AppState appState, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _buildStatusBadge(
                Icons.connected_tv_rounded, 
                appState.isSmartTv ? 'Smart TV Mode Active' : 'Mobile Interface Active'
              ),
              _buildStatusBadge(
                // FIXED: 'g_rounded' এর পরিবর্তে 'cloud_done_rounded' ব্যবহার করা হয়েছে
                appState.errorMessage.isEmpty ? Icons.cloud_done_rounded : Icons.warning_amber_rounded,
                appState.errorMessage.isEmpty ? 'Secure API Sync Active' : 'API Outage Detected',
                color: appState.errorMessage.isEmpty ? const Color(0xFF06B6D4) : theme.colorScheme.error,
              ),
            ],
          ),
          if (appState.errorMessage.isNotEmpty) ...[
            const SizedBox(height: 10),
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
        Text(text, style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  void _showSubscriptions(BuildContext context, List<dynamic> plans) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Premium Packages', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          child: plans.isEmpty
              ? const Text('No subscription plans published.', style: TextStyle(color: Colors.white54))
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B0F19),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.04)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            // FIXED: 'between' এর পরিবর্তে 'spaceBetween' অবজেক্ট ব্যবহার করা হয়েছে
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(plan.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF06B6D4).withOpacity(0.15), 
                                  borderRadius: BorderRadius.circular(8)
                                ),
                                child: Text(plan.badge, style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(plan.price, style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 15)),
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
            child: const Text('Close', style: TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool isTV;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
    required this.onTap,
    required this.isTV,
  });

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      onFocusChange: (focus) => setState(() => _isFocused = focus),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _isFocused ? const Color(0xFF1E293B) : const Color(0xFF131B2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isFocused ? const Color(0xFF06B6D4) : Colors.white.withOpacity(0.02),
            width: 1.5,
          ),
          boxShadow: _isFocused 
              ? [BoxShadow(color: const Color(0xFF06B6D4).withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isFocused ? const Color(0xFF06B6D4).withOpacity(0.15) : const Color(0xFF0B0F19),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, color: _isFocused ? const Color(0xFF06B6D4) : Colors.white70, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.title, 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle, 
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            widget.trailing ?? Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: widget.isTV ? 16 : 14),
          ],
        ),
      ),
    );
  }
}

class _AccountInfoCard extends StatelessWidget {
  final dynamic profile;
  final bool isTV;

  const _AccountInfoCard({required this.profile, required this.isTV});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isTV ? MediaQuery.of(context).size.width * 0.48 : double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1E293B), const Color(0xFF131B2E).withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF06B6D4).withOpacity(0.15),
            child: Text(
              profile.email.isNotEmpty ? profile.email[0].toUpperCase() : '?',
              style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.email, 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: Color(0xFFEAB308), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Plan: ${profile.plan}', 
                      style: const TextStyle(color: Color(0xFFEAB308), fontSize: 12, fontWeight: FontWeight.w600)
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
      backgroundColor: const Color(0xFF131B2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(_isRegister ? 'Create Account' : 'Sign In Securely', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                labelText: 'Email Address',
                labelStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.email_outlined, color: Colors.white38),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF06B6D4))),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.lock_outline, color: Colors.white38),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF06B6D4))),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _isRegister = !_isRegister),
              child: Text(
                _isRegister ? 'Already have an account? Sign In' : 'New to oTtking? Register here',
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
            child: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
        ),
        FilledButton(
          onPressed: _isLoading ? null : () => _submit(appState),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF06B6D4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              : Text(_isRegister ? 'Register' : 'Login', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.isTV});

  final String title;
  final bool isTV;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: isTV ? 16 : 14,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF06B6D4),
        letterSpacing: 0.8,
      ),
    );
  }
}
