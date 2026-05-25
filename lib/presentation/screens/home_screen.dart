// lib/presentation/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../providers/app_state.dart';
import '../widgets/focus_glow_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FocusNode _rootFocusNode = FocusNode(debugLabel: 'home-root');
  final PageController _pageController =
      PageController(viewportFraction: 0.93);

  @override
  void dispose() {
    _rootFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handleKey(KeyEvent event, AppState appState) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      FocusScope.of(context).nextFocus();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      FocusScope.of(context).previousFocus();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      appState.switchChannel(1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      appState.switchChannel(-1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);

    return KeyboardListener(
      focusNode: _rootFocusNode,
      onKeyEvent: (event) => _handleKey(event, appState),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppConstants.appName),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
        body: appState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : appState.errorMessage.isNotEmpty && appState.channels.isEmpty
                ? _ErrorView(
                    message: appState.errorMessage,
                    onRetry: appState.loadCatalog,
                  )
                : _HomeBody(
                    appState: appState,
                    theme: theme,
                    pageController: _pageController,
                  ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.appState,
    required this.theme,
    required this.pageController,
  });

  final AppState appState;
  final ThemeData theme;
  final PageController pageController;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: appState.loadCatalog,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Banners ──────────────────────────────────────────────────────
          if (appState.banners.isNotEmpty) ...[
            SizedBox(
              height: 190,
              child: PageView.builder(
                controller: pageController,
                itemCount: appState.banners.length,
                itemBuilder: (context, index) {
                  final banner = appState.banners[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _BannerCard(banner: banner, theme: theme),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Categories ───────────────────────────────────────────────────
          if (appState.categories.isNotEmpty) ...[
            const _SectionHeader(title: 'Featured Categories'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: appState.categories.map((cat) {
                return Chip(
                  label: Text(cat.name),
                  avatar: Text(cat.icon),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // ── Channels grid ─────────────────────────────────────────────────
          const _SectionHeader(title: 'Live Channels'),
          const SizedBox(height: 12),
          if (appState.channels.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No channels available'),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemCount: appState.channels.length,
              itemBuilder: (context, index) {
                final channel = appState.channels[index];
                final selected = appState.currentChannelIndex == index;
                return FocusGlowButton(
                  label: channel.name,
                  icon: Icons.play_circle_outline,
                  selected: selected,
                  trailing: Text(
                    channel.quality,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    appState.currentChannelIndex = index;
                    Navigator.pushNamed(context, '/player');
                  },
                );
              },
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Banner card ───────────────────────────────────────────────────────────────

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner, required this.theme});

  final dynamic banner;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, const Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            banner.title as String,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            banner.subtitle as String,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

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

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Could not load channels',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
