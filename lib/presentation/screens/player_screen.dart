import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import 'mobile/mobile_player_view.dart';
import 'tv/tv_player_view.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();

    // Primary: MethodChannel-confirmed TV flag
    if (appState.isSmartTv) {
      return const TvPlayerView();
    }

    // Fallback: screen size heuristic
    final mq = MediaQuery.of(context);
    final isTvScreen =
        mq.size.width >= 960 && mq.orientation == Orientation.landscape;

    if (isTvScreen) {
      return const TvPlayerView();
    }

    return const MobilePlayerView();
  }
}
