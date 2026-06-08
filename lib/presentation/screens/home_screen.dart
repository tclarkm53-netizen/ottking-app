// lib/presentation/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../../data/models/channel_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FocusScopeNode _mainFocusScopeNode = FocusScopeNode();
  int _selectedCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    // স্ক্রিন লোড হওয়ার সাথে সাথে ডিভাইস মোড আপডেট করা
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppState>().updateDeviceMode(context);
      }
    });
  }

  @override
  void dispose() {
    _mainFocusScopeNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    // যদি ডেটা লোড হতে থাকে
    if (appState.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F0F),
        body: Center(
          child: CircularProgressIndicator(color: Colors.red),
        ),
      );
    }

    // যদি কোনো এপিআই এরর থাকে
    if (appState.errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: Center(
          child: Text(
            'Error: ${appState.errorMessage}',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    // টিভির স্ক্রিনের জন্য ল্যান্ডস্কেপ লেআউট এবং মোবাইলের জন্য পোর্ট্রেট রেসপন্সিভনেস
    final bool isTvLayout = appState.isSmartTv;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Text(
          appState.isSmartTv ? 'oTtking TV' : 'oTtking Mobile',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              appState.themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
              color: Colors.white,
            ),
            onPressed: () => appState.toggleTheme(),
          ),
        ],
      ),
      body: FocusScope(
        node: _mainFocusScopeNode,
        autofocus: true, // টিভি রিমোটের জন্য প্রথম ফোকাস এখান থেকে শুরু হবে
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── ১. বাম পাশের ক্যাটাগরি লিস্ট (টিভি লেআউটে বড় দেখাবে) ──
            Container(
              width: isTvLayout ? 240 : 120,
              color: const Color(0xFF141414),
              child: ListView.builder(
                itemCount: appState.categories.length,
                itemBuilder: (context, index) {
                  final category = appState.categories[index];
                  return _TvCategoryItem(
                    title: category.name,
                    isSelected: _selectedCategoryIndex == index,
                    isTv: isTvLayout,
                    onTap: () {
                      setState(() {
                        _selectedCategoryIndex = index;
                      });
                    },
                  );
                },
              ),
            ),

            // ── ২. ডান পাশের চ্যানেল গ্রিড ভিউ ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appState.categories.isNotEmpty
                          ? appState.categories[_selectedCategoryIndex].name
                          : 'Live Channels',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTvLayout ? 24 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: GridView.builder(
                        itemCount: appState.channels.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isTvLayout ? 5 : 3, // টিভিতে ৫টি, মোবাইলে ৩টি কলাম
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 16 / 11, // ওটিটি কার্ডের পারফেক্ট রেশিও
                        ),
                        itemBuilder: (context, index) {
                          final channel = appState.channels[index];
                          return _TvChannelGridCard(
                            channel: channel,
                            isTv: isTvLayout,
                            onTap: () {
                              // চ্যানেল ইন্ডেক্স সিলেক্ট করা
                              appState.currentChannelIndex = index;
                              
                              // TODO: আপনার ভিডিও প্লেয়ার স্ক্রিনে নেভিগেট করুন
                              // Navigator.pushNamed(context, '/player');
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Playing: ${channel.name}'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── কাস্টম ক্যাটাগরি আইটেম উইজেট (রিমোট ফোকাস সাপোর্ট সহ) ──
class _TvCategoryItem extends StatefulWidget {
  final String title;
  final bool isSelected;
  final bool isTv;
  final VoidCallback onTap;

  const _TvCategoryItem({
    required this.title,
    required this.isSelected,
    required this.isTv,
    required this.onTap,
  });

  @override
  State<_TvCategoryItem> createState() => _TvCategoryItemState();
}

class _TvCategoryItemState extends State<_TvCategoryItem> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) {
        setState(() {
          _isFocused = focused;
        });
      },
      onKeyEvent: (node, event) {
        if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.select) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: EdgeInsets.symmetric(
            vertical: widget.isTv ? 16 : 12,
            horizontal: 16,
          ),
          decoration: BoxDecoration(
            // রিমোট ফোকাস হলে লাল ব্যাকগ্রাউন্ড, সিলেক্টেড থাকলে গাঢ় ধূসর
            color: _isFocused
                ? Colors.red.withOpacity(0.9)
                : (widget.isSelected ? const Color(0xFF2E2E2E) : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(
            widget.title,
            style: TextStyle(
              color: (_isFocused || widget.isSelected) ? Colors.white : Colors.grey,
              fontSize: widget.isTv ? 16 : 13,
              fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// ── কাস্টম চ্যানেল কার্ড উইজেট (রিমোট ফোকাস এবং হাইলাইট এফেক্ট সহ) ──
class _TvChannelGridCard extends StatefulWidget {
  final ChannelModel channel;
  final bool isTv;
  final VoidCallback onTap;

  const _TvChannelGridCard({
    required this.channel,
    required this.isTv,
    required this.onTap,
  });

  @override
  State<_TvChannelGridCard> createState() => _TvChannelGridCardState();
}

class _TvChannelGridCardState extends State<_TvChannelGridCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) {
        setState(() {
          _isFocused = focused;
        });
      },
      onKeyEvent: (node, event) {
        // রিমোটের D-Pad বা 'OK' বাটন প্রেস হ্যান্ডেলিং
        if (event is RawKeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          // রিমোট ফোকাস হলে কার্ডটি সামান্য বড় (Scale up) দেখাবে যা টিভিতে দেখতে দারুণ লাগে
          transform: _isFocused
              ? (Matrix4.identity()..scale(1.05))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isFocused ? Colors.red : const Color(0xFF333333),
              width: _isFocused ? 2.5 : 1.0,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // লোগো বা থাম্বনেইল এরিয়া
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                  child: Container(
                    color: const Color(0xFF2A2A2A),
                    child: widget.channel.logoUrl.isNotEmpty
                        ? Image.network(
                            widget.channel.logoUrl,
                            fit: BoxFit.scaleDown,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.tv,
                              color: Colors.grey,
                              size: 32,
                            ),
                          )
                        : const Icon(
                            Icons.live_tv,
                            color: Colors.redAccent,
                            size: 32,
                          ),
                  ),
                ),
              ),
              // চ্যানেলের নাম
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                color: _isFocused ? Colors.red : const Color(0xFF121212),
                child: Text(
                  widget.channel.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: widget.isTv ? 14 : 11,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
