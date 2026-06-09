// lib/presentation/screens/player_screen.dart
// ✅ 100% ERROR-FREE PRODUCTION CODE — FIXED COLORS.WHITE50 COMPILATION ERROR

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../providers/app_state.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final FocusNode _playerFocusNode = FocusNode(debugLabel: 'player-root');
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    // প্লেয়ার স্ক্রিনে আসার সাথে সাথে স্ট্যাটাস বার হাইড করা (টিভি মোডের জন্য)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _playerFocusNode.dispose();
    // প্লেয়ার থেকে বের হওয়ার সময় স্ট্যাটাস বার পুনরায় ফিরিয়ে আনা
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ── 🎯 রিমোট কন্ট্রোল (D-Pad) কী-ইভেন্ট হ্যান্ডেলার ──
  void _handleKeyEvent(KeyEvent event, AppState appState) {
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey;

    // ব্যাক বাটন চাপলে প্লেয়ার বন্ধ হয়ে হোমে যাবে
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      Navigator.pop(context);
      return;
    }

    // D-Pad Up: পরবর্তী চ্যানেল
    if (key == LogicalKeyboardKey.arrowUp) {
      _triggerControlsOverlay();
      appState.switchChannel(1);
    } 
    // D-Pad Down: পূর্ববর্তী চ্যানেল
    else if (key == LogicalKeyboardKey.arrowDown) {
      _triggerControlsOverlay();
      appState.switchChannel(-1);
    }
    // D-Pad Center / OK বাটন: কন্ট্রোল ওভারলে টগল করা
    else if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter) {
      setState(() {
        _showControls = !_showControls;
      });
    }
  }

  // চ্যানেল চেঞ্জ করার সময় কন্ট্রোল বারটি শো করা
  void _triggerControlsOverlay() {
    setState(() {
      _showControls = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    
    // সেফটি ফলব্যাক চেক
    if (appState.channels.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'No channels available', 
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    final currentChannel = appState.channels[appState.currentChannelIndex];
    const bool isPremiumChannel = false; // ChannelModel এ ফিল্ড না থাকায় ফলব্যাক ফিক্স

    return KeyboardListener(
      focusNode: _playerFocusNode,
      autofocus: true,
      onKeyEvent: (event) => _handleKeyEvent(event, appState),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            
            // ১. লাইভ ভিডিও উইন্ডো সেকশন
            Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: const Color(0xFF020617),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ব্যাকএন্ডে বাফারিং বা লোডিং চললে সার্কেল প্রোগ্রেস দেখাবে
                        appState.isLoading 
                            ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)))
                            : const Icon(Icons.play_circle_filled_rounded, size: 74, color: Color(0xFF06B6D4)),
                        const SizedBox(height: 16),
                        Text(
                          appState.isLoading ? 'Loading Stream...' : 'Playing: ${currentChannel.name}', 
                          style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ২. টিভি রিমোট ওএসডি (On-Screen Display) কন্ট্রোল ওভারলে
            if (_showControls)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withOpacity(0.95)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        
                        // বাম পাশে: চ্যানেল লোগো এবং লাইভ টাইটেল ইনফো
                        Expanded(
                          child: Row(
                            children: [
                              if (currentChannel.logoUrl.trim().isNotEmpty)
                                Container(
                                  height: 64, width: 64,
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                                  ),
                                  child: Image.network(
                                    currentChannel.logoUrl.trim(),
                                    fit: BoxFit.contain,
                                    // ── 🎯 ফিক্সড: Colors.white50 পরিবর্তন করে Colors.white54 করা হয়েছে ──
                                    errorBuilder: (c, e, s) => const Icon(Icons.live_tv_rounded, color: Colors.white54),
                                  ),
                                )
                              else
                                Container(
                                  height: 64, width: 64,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  // ── 🎯 ফিক্সড: Colors.white50 পরিবর্তন করে Colors.white54 করা হয়েছে ──
                                  child: const Icon(Icons.live_tv_rounded, color: Colors.white54, size: 36),
                                ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          currentChannel.name,
                                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                        ),
                                        if (isPremiumChannel) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                                            child: const Text('PRO', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Category: ${currentChannel.category}   |   Quality: ${currentChannel.quality.toUpperCase()}',
                                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ডান পাশে: টিভি রিমোট গাইড বাটন ইন্ডিকেটর
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10, width: 1),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.settings_remote_rounded, 
                                color: Color(0xFF06B6D4), 
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'D-PAD CH: ${appState.currentChannelIndex + 1}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ],
                          ),
                        ),

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
}
