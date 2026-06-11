// lib/presentation/screens/player_widgets/player_top_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

class PlayerTopPanel extends StatefulWidget {
  const PlayerTopPanel({
    super.key,
    required this.channel,
    required this.currentIndex,
    required this.totalChannels,
    required this.onSettings,
    required this.isPlaying, // প্লেয়ার প্লে নাকি পজ অবস্থায় আছে
    this.typedNumber = '',
  });

  final dynamic channel;
  final int currentIndex;
  final int totalChannels;
  final VoidCallback onSettings;
  final bool isPlaying;
  final String typedNumber;

  @override
  State<PlayerTopPanel> createState() => _PlayerTopPanelState();
}

class _PlayerTopPanelState extends State<PlayerTopPanel> with SingleTickerProviderStateMixin {
  final FocusNode _settingsFocus = FocusNode(debugLabel: 'settings-btn');
  
  // শুরুতে false থাকবে, রিমোট দিয়ে সেটিংস বাটনে গেলে কেবল true হবে
  bool _isSettingsFocused = false; 
  
  // LIVE লেখা ব্লিংক করানোর জন্য কন্ট্রোলার
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _settingsFocus.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isTyping = widget.typedNumber.isNotEmpty;

    return Stack(
      children: [
        // ========== TOP-LEFT: একক চ্যানেল কার্ড (নম্বর + নাম / টাইপিং মোড + লাইভ) ==========
        Positioned(
          top: 20,
          left: 20,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isTyping 
                    ? Colors.yellow.withOpacity(0.8) // টাইপ করার সময় বর্ডার হলুদ হবে
                    : AppTheme.primary.withOpacity(0.4), // সাধারণ অবস্থায় নরমাল থিম বর্ডার
                width: isTyping ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ১. প্লে/পজ স্ট্যাটাস আইকন (কন্ট্রোলারের সাথে ম্যাচিং)
                Icon(
                  widget.isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: widget.isPlaying ? AppTheme.primary : Colors.redAccent,
                  size: 20,
                ),
                const SizedBox(width: 10),

                // ২. "CH " টেক্সট
                Text(
                  'CH ',
                  style: TextStyle(
                    color: isTyping ? Colors.yellow.withOpacity(0.7) : Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                
                // ৩. চ্যানেল নম্বর
                Text(
                  isTyping ? widget.typedNumber : '${widget.currentIndex + 1}',
                  style: TextStyle(
                    color: isTyping ? Colors.yellow : AppTheme.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),

                // ৪. চ্যানেল নাম এবং লাইভ ব্লিংকার (টাইপ না করলে কার্ডের ভেতরে ঢুকবে)
                if (!isTyping) ...[
                  const SizedBox(width: 12),
                  Container(
                    height: 18,
                    width: 1,
                    color: Colors.white24,
                  ),
                  const SizedBox(width: 12),
                  
                  // মূল চ্যানেলের নাম
                  Text(
                    widget.channel.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(width: 14),
                  Container(
                    height: 18,
                    width: 1,
                    color: Colors.white24,
                  ),
                  const SizedBox(width: 12),

                  // ৫. LIVE ব্লিংকিং ইন্ডিকেটর (লাল ডট + LIVE টেক্সট)
                  FadeTransition(
                    opacity: _blinkController,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // ========== TOP-RIGHT: সেটিংস আইকন (রিমোট ফোকাস লজিকসহ) ==========
        Positioned(
          top: 20,
          right: 20,
          child: Focus(
            focusNode: _settingsFocus,
            onFocusChange: (hasFocus) {
              // রিমোট দিয়ে সিলেক্ট করলেই কেবল ব্যাকগ্রাউন্ড এবং বর্ডার অন হবে
              setState(() {
                _isSettingsFocused = hasFocus;
              });
            },
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.select ||
                      event.logicalKey == LogicalKeyboardKey.space)) {
                widget.onSettings();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: GestureDetector(
              onTap: widget.onSettings,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  // ফোকাস হলে থিম কালার গ্লো পাবে, না হলে সম্পূর্ণ ট্রান্সপারেন্ট (নরমাল আইকন)
                  color: _isSettingsFocused
                      ? AppTheme.primary.withOpacity(0.25)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    // ফোকাস হলে বর্ডার দেখাবে, না হলে হাইড থাকবে
                    color: _isSettingsFocused ? AppTheme.primary : Colors.transparent,
                    width: _isSettingsFocused ? 2 : 1,
                  ),
                ),
                child: Icon(
                  Icons.settings_rounded,
                  // ফোকাসড অবস্থায় আইকনটি উজ্জ্বল সাদা হবে, সাধারণ অবস্থায় একটু হালকা (white70) থাকবে
                  color: _isSettingsFocused ? AppTheme.primary : Colors.white70,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
