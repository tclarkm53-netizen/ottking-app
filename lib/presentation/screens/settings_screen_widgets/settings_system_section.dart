// lib/presentation/screens/settings_screen_widgets/settings_system_section.dart

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/app_state.dart';
import 'settings_shared_widgets.dart';

class SettingsSystemSection extends StatelessWidget {
  const SettingsSystemSection({super.key, required this.appState});
  final AppState appState;

  void _refreshCatalog(BuildContext context) {
    appState.loadCatalog();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('চ্যানেল লিস্ট আপডেট হচ্ছে...'),
        backgroundColor: AppTheme.card,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _checkForUpdates(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('নতুন আপডেটের জন্য চেক করা হচ্ছে...'),
        backgroundColor: AppTheme.card,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'সিস্টেম'),
        const SizedBox(height: 16),

        SettingsTwoColRow(
          children: [
            // ── ১. ক্যাটালগ রিফ্রেশ ──────────────────────────────────────────
            SettingCard(
              icon: Icons.sync_rounded,
              title: 'ক্যাটালগ রিফ্রেশ',
              subtitle: 'চ্যানেল লিস্ট আপডেট করুন',
              onTap: () => _refreshCatalog(context),
            ),

            // ── ২. অ্যাপ আপডেট ────────────────────────────────────────────
            SettingCard(
              icon: Icons.system_update_rounded,
              title: '앱 আপডেট',
              subtitle: 'নতুন ভার্সন চেক করুন',
              onTap: () => _checkForUpdates(context),
            ),

            // ── ৩. ডেভেলপার (আলাদা কার্ড) ──────────────────────────────────
            SettingCard(
              icon: Icons.code_rounded,
              title: 'ডেভেলপার',
              subtitle: 'Anirban Sumon',
              onTap: () => showDialog(
                context: context,
                builder: (_) => const _DeveloperDialog(),
              ),
            ),

            // ── ৪. অ্যাপ তথ্য ──────────────────────────────────────────────
            SettingCard(
              icon: Icons.info_outline_rounded,
              title: 'অ্যাপ তথ্য',
              subtitle: 'ভার্সন ও সিস্টেম তথ্য',
              onTap: () => showDialog(
                context: context,
                builder: (_) => const _AppInfoDialog(),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Section hint ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.settings_applications_rounded,
                color: AppTheme.primary,
                size: 16,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'বর্তমানে: সিস্টেম সেটিংস — ক্যাটালগ আপডেট, সিস্টেম আপডেট, ডেভেলপার ও অ্যাপের তথ্য।',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── ৩. Developer Dialog ──────────────────────────────────────────────────────

class _DeveloperDialog extends StatelessWidget {
  const _DeveloperDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black.withOpacity(0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      title: const Row(
        children: [
          Icon(Icons.person_rounded, color: AppTheme.primary),
          SizedBox(width: 10),
          Text('ডেভেলপার তথ্য', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'প্রধান ডেভেলপার ও প্রজেক্ট আর্কিটেক্ট:',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            'Anirban Sumon',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Full Stack Developer (IPTV & Mobile Systems)',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          autofocus: true,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primary,
            backgroundColor: Colors.transparent,
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.focused)) {
                  return AppTheme.primary.withOpacity(0.15);
                }
                return null;
              },
            ),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text('বন্ধ', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

// ── ৪. App Info Dialog ───────────────────────────────────────────────────────

class _AppInfoDialog extends StatelessWidget {
  const _AppInfoDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black.withOpacity(0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      title: const Row(
        children: [
          Icon(Icons.info_rounded, color: AppTheme.primary),
          SizedBox(width: 10),
          Text('অ্যাপ তথ্য', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Live TV Player',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Version 1.0.0',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          SizedBox(height: 4),
          Text(
            'All rights reserved.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primary,
            backgroundColor: Colors.transparent,
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.focused)) {
                  return AppTheme.primary.withOpacity(0.15);
                }
                return null;
              },
            ),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text('বন্ধ', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
