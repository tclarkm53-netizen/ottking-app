// lib/presentation/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models/channel_model.dart';
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

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── General ───────────────────────────────────────────────────
            const _SectionTitle(title: 'General'),
            const SizedBox(height: 12),
            FocusGlowButton(
              label: appState.themeMode == ThemeMode.dark
                  ? 'Switch to Light Mode'
                  : 'Switch to Dark Mode',
              icon: appState.themeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
              onTap: appState.toggleTheme,
            ),
            if (appState.isSmartTv) ...[
              const SizedBox(height: 12),
              FocusGlowButton(
                label: appState.bootToPlayer
                    ? 'Disable Direct Player Boot'
                    : 'Enable Direct Player Boot',
                icon: Icons.tv_outlined,
                onTap: () =>
                    appState.setBootToPlayer(!appState.bootToPlayer),
              ),
            ],
            const SizedBox(height: 24),

            // ── Account ───────────────────────────────────────────────────
            const _SectionTitle(title: 'Account & Access'),
            const SizedBox(height: 12),
            if (appState.isAuthenticated && appState.userProfile != null)
              _AccountInfoCard(profile: appState.userProfile!, theme: theme),
            const SizedBox(height: 12),
            FocusGlowButton(
              label: appState.isAuthenticated
                  ? 'Switch Account / Logout'
                  : 'Login / Register',
              icon: Icons.person_outline,
              onTap: () => showDialog(
                context: context,
                builder: (_) => const AuthOverlayDialog(),
              ),
            ),
            const SizedBox(height: 12),
            FocusGlowButton(
              label: 'View Subscription Plans',
              icon: Icons.card_membership,
              onTap: () =>
                  _showSubscriptions(context, appState.plans),
            ),
            const SizedBox(height: 24),

            // ── Support ───────────────────────────────────────────────────
            const _SectionTitle(title: 'Support'),
            const SizedBox(height: 12),
            FocusGlowButton(
              label: 'Reload Channel Catalog',
              icon: Icons.refresh,
              onTap: () {
                appState.loadCatalog();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Refreshing catalog…')),
                );
              },
            ),
            const SizedBox(height: 12),
            FocusGlowButton(
              label: 'Contact Support',
              icon: Icons.support_agent,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Support request queued securely.'),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Status card ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Platform Status',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    appState.isSmartTv
                        ? 'Smart TV remote navigation enabled'
                        : 'Mobile touch UI active',
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        appState.errorMessage.isEmpty
                            ? Icons.check_circle_outline
                            : Icons.warning_amber_rounded,
                        size: 16,
                        color: appState.errorMessage.isEmpty
                            ? Colors.green
                            : theme.colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          appState.errorMessage.isEmpty
                              ? 'Secure API sync active'
                              : 'API sync failed',
                        ),
                      ),
                    ],
                  ),
                  if (appState.errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      appState.errorMessage,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showSubscriptions(
      BuildContext context, List<SubscriptionPlanModel> plans) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Premium Plans'),
        content: SizedBox(
          width: 360,
          child: plans.isEmpty
              ? const Text('No plans available.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                plan.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(
                                  plan.badge,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            plan.price,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(plan.description),
                          if (plan.features.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...plan.features.map(
                              (f) => Row(
                                children: [
                                  const Icon(Icons.check,
                                      size: 14, color: Colors.green),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(f)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ── Account info card ─────────────────────────────────────────────────────────

class _AccountInfoCard extends StatelessWidget {
  const _AccountInfoCard({required this.profile, required this.theme});

  final UserProfileModel profile;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withAlpha(60)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withAlpha(50),
            child: Text(
              profile.email.isNotEmpty
                  ? profile.email[0].toUpperCase()
                  : '?',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.email,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(profile.plan,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                    )),
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
      title: Text(_isRegister ? 'Create account' : 'Sign in securely'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  setState(() => _isRegister = !_isRegister),
              child: Text(
                _isRegister
                    ? 'Already have an account? Sign in'
                    : 'Need an account? Register',
              ),
            ),
            if (appState.errorMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                appState.errorMessage,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        // Logout button (only when signed in)
        if (appState.isAuthenticated)
          TextButton(
            onPressed: () {
              appState.logout();
              Navigator.pop(context);
            },
            child: const Text('Logout'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : () => _submit(appState),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isRegister ? 'Register' : 'Login'),
        ),
      ],
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}
