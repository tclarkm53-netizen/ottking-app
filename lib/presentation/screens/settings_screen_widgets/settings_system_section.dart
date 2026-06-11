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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'সিস্টেম'),
        const SizedBox(height: 16),

        SettingsTwoColRow(children: [
          // ── Catalog refresh ──────────────────────────────────────────
          SettingCard(
            icon: Icons.sync_rounded,
            title: 'ক্যাটালগ রিফ্রেশ',
            subtitle: 'চ্যানেল লিস্ট আপডেট করুন',
            onTap: () => _refreshCatalog(context),
          ),

          // ── App Info ─────────────────────────────────────────────────
          SettingCard(
            icon: Icons.info_outline_rounded,
            title: 'অ্যাপ তথ্য',
            subtitle: 'ভার্সন, ডেভেলপার তথ্য',
            onTap: () => showDialog(
              context: context,
              builder: (_) => const _AppInfoDialog(),
            ),
          ),
        ]),

        const SizedBox(height: 12),

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
              const Icon(Icons.settings_applications_rounded,
                  color: AppTheme.primary, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'বর্তমানে: সিস্টেম সেটিংস — ক্যাটালগ আপডেট ও অ্যাপ তথ্য।',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── App Info Dialog ────────────────────────────────────────────────────────────

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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Live TV Player',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Version 1.0.0',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ডেভেলপার:',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                SizedBox(height: 4),
                Text('Anirban Sumon',
                    style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              Text('বন্ধ', style: TextStyle(color: AppTheme.primary)),
        ),
      ],
    );
  }
}
