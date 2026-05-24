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

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);

    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: (event) {
        if (event is! RawKeyDownEvent) {
          return;
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          FocusScope.of(context).nextFocus();
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          FocusScope.of(context).previousFocus();
        }
      },
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
            _SectionTitle(title: 'General'),
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
            const SizedBox(height: 12),
            if (appState.isSmartTv)
              FocusGlowButton(
                label: appState.bootToPlayer
                    ? 'Disable Direct Player Boot'
                    : 'Enable Direct Player Boot',
                icon: Icons.tv_outlined,
                onTap: () => appState.setBootToPlayer(!appState.bootToPlayer),
              ),
            const SizedBox(height: 24),
            _SectionTitle(title: 'Account & Access'),
            const SizedBox(height: 12),
            FocusGlowButton(
              label: appState.isAuthenticated ? 'Manage Account' : 'Login / Register',
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
              onTap: () => _showSubscriptions(context, appState.plans),
            ),
            const SizedBox(height: 24),
            _SectionTitle(title: 'Support'),
            const SizedBox(height: 12),
            FocusGlowButton(
              label: 'Contact Support',
              icon: Icons.support_agent,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Support request queued securely.')),
              ),
            ),
            const SizedBox(height: 24),
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
                    'Platform Mode',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    appState.isSmartTv
                        ? 'Smart TV remote navigation enabled'
                        : 'Mobile touch UI active',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'API status: ${appState.errorMessage.isEmpty ? 'Secure sync active' : 'Needs attention'}',
                  ),
                  if (appState.errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Error: ${appState.errorMessage}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubscriptions(BuildContext context, List<SubscriptionPlanModel> plans) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Premium Plans'),
          content: SizedBox(
            width: 360,
            child: ListView.separated(
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
                      Text(plan.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(plan.badge),
                      const SizedBox(height: 6),
                      Text(plan.price),
                      const SizedBox(height: 8),
                      Text(plan.description),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
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
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return AlertDialog(
      title: Text(_isRegister ? 'Create your account' : 'Login securely'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _isRegister = !_isRegister),
              child: Text(_isRegister ? 'Already have an account?' : 'Need an account?'),
            ),
            if (appState.errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                appState.errorMessage,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
              return;
            }

            if (_isRegister) {
              await appState.register(
                _emailController.text,
                _passwordController.text,
              );
            } else {
              await appState.login(
                _emailController.text,
                _passwordController.text,
              );
            }

            if (!mounted) {
              return;
            }

            if (appState.errorMessage.isEmpty) {
              Navigator.pop(context);
            }
          },
          child: Text(_isRegister ? 'Register' : 'Login'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}
