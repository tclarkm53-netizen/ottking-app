// lib/presentation/screens/player_screen.dart

import 'package:flutter/material.dart';
import 'mobile/mobile_player_view.dart';
import 'tv/tv_player_view.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ল্যান্ডস্কেপ ও ৮০০ পিক্সেলের বেশি উইডথ হলে সেটিকে টিভি হিসেবে গণ্য করা হবে
    final isTV = MediaQuery.of(context).size.width > 800 && 
                 MediaQuery.of(context).orientation == Orientation.landscape;

    if (isTV) {
      return const TvPlayerView();
    } else {
      return const MobilePlayerView();
    }
  }
}
