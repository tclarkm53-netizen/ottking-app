// lib/presentation/screens/settings_screen.dart
// TV-only settings — always landscape

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../providers/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FocusNode _root = FocusNode(debugLabel: 'settings-root');

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
            // Left sidebar nav
            Container(
              width: 260,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border(
                    right: BorderSide(color: AppTheme.border, width: 1)),
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white70, size: 18),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Text(
                            'সেটিংস',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    _NavItem(
                        icon: Icons.account_circle_rounded,
                        label: 'অ্যাকাউন্ট'),
                    _NavItem(
                        icon: Icons.tv_rounded, label: 'TV সেটিংস'),
                    _NavItem(
                        icon: Icons.card_membership_rounded,
                        label: 'সাবস্ক্রিপশন'),
                    _NavItem(
                        icon: Icons.sync_rounded,
                        label: 'ক্যাটালগ রিফ্রেশ'),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'v1.0.0  |  Smart TV',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.2),
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Main content
            Expanded(
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 48, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Account ──────────────────────────────────────────
                      if (appState.isAuthenticated &&
                          appState.userProfile != null) ...[
                        _SectionHeader(title: 'অ্যাকাউন্ট'),
                        const SizedBox(height: 16),
                        _AccountCard(profile: appState.userProfile!),
                        const SizedBox(height: 32),
                      ],

                      // ── TV Settings ──────────────────────────────────────
                      _SectionHeader(title: 'Smart TV সেটিংস'),
                      const SizedBox(height: 16),
                      _TvGrid(children: [
                        // Boot Player toggle — KEY FEATURE
                        _SettingCard(
                          icon: Icons.rocket_launch_rounded,
                          title: 'Boot Player',
                          subtitle: appState.bootToPlayer
                              ? 'চালু — অ্যাপ খুললেই লাইভ টিভি শুরু হবে'
                              : 'বন্ধ — হোম পেজে যাবে',
                          trailing: Switch(
                            value: appState.bootToPlayer,
                            activeColor: AppTheme.primary,
                            onChanged: (v) => appState.setBootToPlayer(v),
                          ),
                          onTap: () => appState
                              .setBootToPlayer(!appState.bootToPlayer),
                          highlight: appState.bootToPlayer,
                        ),
                        _SettingCard(
                          icon: Icons.palette_rounded,
                          title: 'থিম',
                          subtitle: appState.themeMode == ThemeMode.dark
                              ? 'Dark Mode'
                              : 'Light Mode',
                          onTap: appState.toggleTheme,
                        ),
                        _SettingCard(
                          icon: Icons.account_circle_rounded,
                          title: appState.isAuthenticated
                              ? 'অ্যাকাউন্ট'
                              : 'লগইন করুন',
                          subtitle: appState.isAuthenticated
                              ? 'অ্যাকাউন্ট পরিচালনা করুন'
                              : 'প্রিমিয়াম চ্যানেল পেতে লগইন করুন',
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => const AuthDialog(),
                          ),
                        ),
                        _SettingCard(
                          icon: Icons.sync_rounded,
                          title: 'ক্যাটালগ রিফ্রেশ',
                          subtitle: 'চ্যানেল লিস্ট আপডেট করুন',
                          onTap: () {
                            appState.loadCatalog();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                    'চ্যানেল লিস্ট আপডেট হচ্ছে...'),
                                backgroundColor: AppTheme.card,
                              ),
                            );
                          },
                        ),
                        _SettingCard(
                          icon: Icons.card_membership_rounded,
                          title: 'সাবস্ক্রিপশন প্ল্যান',
                          subtitle: 'প্যাকেজ ও মূল্য দেখুন',
                          onTap: () => _showPlans(context, appState.plans),
                        ),
                      ]),

                      const SizedBox(height: 32),

                      // ── Status footer ─────────────────────────────────────
                      _StatusFooter(appState: appState),
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

  void _showPlans(BuildContext ctx, List plans) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('সাবস্ক্রিপশন প্ল্যান',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 480,
          child: plans.isEmpty
              ? const Text('কোনো প্ল্যান পাওয়া যায়নি।',
                  style: TextStyle(color: Colors.white54))
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: plans.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final p = plans[i];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B0F19),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(p.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(p.badge,
                                    style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(p.price,
                              style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(p.description,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 13)),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বন্ধ',
                style: TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: Colors.white38, size: 20),
        title: Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 14)),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.primary,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _TvGrid extends StatelessWidget {
  const _TvGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 4.0,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      children: children,
    );
  }
}

class _SettingCard extends StatefulWidget {
  const _SettingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.highlight = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool highlight;

  @override
  State<_SettingCard> createState() => _SettingCardState();
}

class _SettingCardState extends State<_SettingCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final active = _focused || widget.highlight;
    return InkWell(
      onTap: widget.onTap,
      onFocusChange: (v) => setState(() => _focused = v),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppTheme.card : const Color(0xFF131B2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? AppTheme.primary : Colors.white.withOpacity(0.04),
            width: 1.5,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.primary.withOpacity(0.15)
                    : const Color(0xFF0B0F19),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon,
                  color: active ? AppTheme.primary : Colors.white54,
                  size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: active ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            widget.trailing ??
                Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.profile});
  final dynamic profile;

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.card, const Color(0xFF131B2E).withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.primary.withOpacity(0.15),
            child: Text(
              profile.email.isNotEmpty
                  ? profile.email[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 22),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.email,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.stars_rounded,
                        color: Color(0xFFEAB308), size: 14),
                    const SizedBox(width: 4),
                    Text('প্ল্যান: ${profile.plan}',
                        style: const TextStyle(
                            color: Color(0xFFEAB308),
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () {
              appState.logout();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.logout_rounded,
                color: Colors.redAccent, size: 16),
            label: const Text('লগআউট',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _StatusFooter extends StatelessWidget {
  const _StatusFooter({required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          _Badge(
            icon: Icons.connected_tv_rounded,
            label: 'Smart TV Mode',
            color: AppTheme.primary,
          ),
          const SizedBox(width: 24),
          _Badge(
            icon: appState.errorMessage.isEmpty
                ? Icons.cloud_done_rounded
                : Icons.warning_amber_rounded,
            label: appState.errorMessage.isEmpty
                ? 'API সংযোগ সচল'
                : 'API সমস্যা',
            color: appState.errorMessage.isEmpty
                ? AppTheme.primary
                : Colors.redAccent,
          ),
          const SizedBox(width: 24),
          _Badge(
            icon: Icons.live_tv_rounded,
            label: '${appState.channels.length} চ্যানেল',
            color: Colors.white54,
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─── Auth Dialog ──────────────────────────────────────────────────────────────

class AuthDialog extends StatefulWidget {
  const AuthDialog({super.key});

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> {
  bool _isRegister = false;
  bool _loading = false;
  final _email = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState appState) async {
    if (_email.text.trim().isEmpty || _pass.text.isEmpty) return;
    setState(() => _loading = true);
    _isRegister
        ? await appState.register(_email.text.trim(), _pass.text)
        : await appState.login(_email.text.trim(), _pass.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (appState.errorMessage.isEmpty) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return AlertDialog(
      backgroundColor: const Color(0xFF131B2E),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        _isRegister ? 'নতুন অ্যাকাউন্ট' : 'সাইন ইন',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Field(ctrl: _email, label: 'Email', icon: Icons.email_outlined),
            const SizedBox(height: 16),
            _Field(
                ctrl: _pass,
                label: 'Password',
                icon: Icons.lock_outline,
                obscure: true),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _isRegister = !_isRegister),
              child: Text(
                _isRegister
                    ? 'ইতিমধ্যে অ্যাকাউন্ট আছে? সাইন ইন করুন'
                    : 'নতুন অ্যাকাউন্ট তৈরি করুন',
                style: const TextStyle(color: AppTheme.primary),
              ),
            ),
            if (appState.errorMessage.isNotEmpty)
              Text(appState.errorMessage,
                  style: const TextStyle(
                      color: Colors.redAccent, fontSize: 13)),
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
            child: const Text('লগআউট',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('বাতিল',
              style: TextStyle(color: Colors.white38)),
        ),
        FilledButton(
          onPressed: _loading ? null : () => _submit(appState),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white)))
              : Text(
                  _isRegister ? 'রেজিস্ট্রেশন' : 'লগইন',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black),
                ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(
      {required this.ctrl,
      required this.label,
      required this.icon,
      this.obscure = false});
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white38),
        enabledBorder: UnderlineInputBorder(
            borderSide:
                BorderSide(color: Colors.white.withOpacity(0.08))),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppTheme.primary)),
      ),
    );
  }
}
