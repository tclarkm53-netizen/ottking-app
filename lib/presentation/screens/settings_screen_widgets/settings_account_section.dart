// lib/presentation/screens/settings_screen_widgets/settings_account_section.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/app_state.dart';
import 'settings_shared_widgets.dart';
import 'auth_dialog.dart';
import 'subscription_dialog.dart';

class SettingsAccountSection extends StatelessWidget {
  const SettingsAccountSection({super.key, required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'অ্যাকাউন্ট'),
        const SizedBox(height: 16),

        // ── Logged in: profile card ──────────────────────────────────────
        if (appState.isAuthenticated && appState.userProfile != null) ...[
          AccountCard(profile: appState.userProfile!),
          const SizedBox(height: 20),
        ],

        // ── Two action cards: Login & Subscription ───────────────────────
        SettingsTwoColRow(children: [
          SettingCard(
            icon: appState.isAuthenticated
                ? Icons.manage_accounts_rounded
                : Icons.login_rounded,
            title: appState.isAuthenticated ? 'অ্যাকাউন্ট পরিচালনা' : 'লগইন করুন',
            subtitle: appState.isAuthenticated
                ? appState.userProfile?.email ?? ''
                : 'প্রিমিয়াম চ্যানেল পেতে লগইন করুন',
            highlight: appState.isAuthenticated,
            onTap: () => showDialog(
              context: context,
              builder: (_) => const AuthDialog(),
            ),
          ),
          SettingCard(
            icon: Icons.card_membership_rounded,
            title: 'সাবস্ক্রিপশন',
            subtitle: appState.isAuthenticated
                ? 'প্ল্যান: ${appState.userProfile?.plan ?? "–"}'
                : 'প্যাকেজ ও মূল্য দেখুন',
            onTap: () => showDialog(
              context: context,
              builder: (_) => SubscriptionDialog(plans: appState.plans),
            ),
          ),
        ]),

        const SizedBox(height: 12),

        // ── Right panel label — বর্তমান সেকশন ──────────────────────────
        _SectionHint(
          icon: Icons.info_outline_rounded,
          text: 'বর্তমানে: অ্যাকাউন্ট সেটিংস — লগইন ও সাবস্ক্রিপশন পরিচালনা করুন।',
        ),
      ],
    );
  }
}

class _SectionHint extends StatelessWidget {
  const _SectionHint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ── Account profile card ──────────────────────────────────────────────────────

class AccountCard extends StatelessWidget {
  const AccountCard({super.key, required this.profile});
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
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
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
