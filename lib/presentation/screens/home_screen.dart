import 'package:flutter/material.dart';
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
  final PageController _pageController = PageController(viewportFraction: 0.93);

  @override
  void dispose() {
    _rootFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);

    return RawKeyboardListener(
      focusNode: _rootFocusNode,
      onKey: (event) {
        final appState = context.read<AppState>();
        if (event is! RawKeyDownEvent) {
          return;
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          FocusScope.of(context).nextFocus();
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          FocusScope.of(context).previousFocus();
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          appState.switchChannel(1);
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          appState.switchChannel(-1);
        }
      },
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
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  if (appState.banners.isNotEmpty)
                    SizedBox(
                      height: 180,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: appState.banners.length,
                        itemBuilder: (context, index) {
                          final banner = appState.banners[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.primary,
                                    const Color(0xFF0F172A),
                                  ],
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
                                    banner.title,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    banner.subtitle,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'Featured Categories'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: appState.categories.map((category) {
                      return Chip(
                        label: Text(category.name),
                        avatar: Text(category.icon),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'Live Channels'),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                        trailing: Text(channel.quality),
                        onTap: () {
                          appState.currentChannelIndex = index;
                          Navigator.pushNamed(context, '/player');
                        },
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

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
