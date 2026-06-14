import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme/app_theme.dart';
import '../providers/app_state.dart';
import 'player_widgets/player_top_panel.dart';
import 'player_widgets/player_bottom_bar.dart';
import 'player_widgets/channel_list_panel.dart';
import 'player_widgets/loading_overlay.dart';
import 'player_widgets/app_info_dialog.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  final FocusNode _focus = FocusNode(debugLabel: 'player-root');

  VideoPlayerController? _ctrl;
  VoidCallback? _ctrlListener;
  String? _activeChannelId;

  bool _showControls = true;
  bool _isLoading = false;
  bool _hasStreamError = false;
  bool _showChannelList = false;
  bool _liveBlink = true;

  AppState? _appState;

  Timer? _controlsTimer;
  Timer? _numberTimer;
  Timer? _retryTimer;
  Timer? _blinkTimer;

  String _typed = '';
  int _retryCount = 0;
  static const int _maxRetry = 3;

  DateTime? _okDown;
  bool _longHandled = false;

  // দ্রুত চ্যানেল সুইচের রেস কন্ডিশন ঠেকানোর ইউনিক টাইমস্ট্যাম্প টোকেন
  int _currentInitTimestamp = 0; 

  // ========== Lifecycle ==========

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _wakelock();
      if (_ctrl?.value.hasError == true) {
        _retryCount = 0;
        _initController();
      }
    } else if (state == AppLifecycleState.paused) {
      _ctrl?.pause();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _forceFullLandscape();
    _wakelock();
    _startBlinkTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _appState = Provider.of<AppState>(context, listen: false);
        _initController();
        _startControlsTimer();
        _focus.requestFocus(); // স্ক্রিন খোলার সাথে সাথে রিমোট ফোকাস একটিভ
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // প্লেয়ার রানিং অবস্থায় ব্যাকগ্রাউন্ড ডেটা আপডেটের কারণে যেন হুট করে প্লেয়ার রিলোড না হয়,
    // সেজন্য watch করার সময় আমরা চেক করব কারেন্ট চ্যানেলের ID পরিবর্তন হয়েছে কিনা।
    // চ্যানেল চেঞ্জ না হওয়া পর্যন্ত প্লেয়ার তার নিজের মতো চলতে থাকবে।
    final nextState = context.watch<AppState>();
    if (_appState != null && _activeChannelId != null) {
      final nextChannelId = nextState.channels.isNotEmpty 
          ? nextState.channels[nextState.currentChannelIndex].id 
          : null;
          
      // যদি আইডি একই থাকে (তার মানে ব্যাকগ্রাউন্ডে শুধু ডেটা আপডেট হয়েছে, ইউজার চ্যানেল চেঞ্জ করেননি)
      // তবে প্লেয়ার রি-ইনিশিয়ালাইজেশন স্কিপ করা হবে।
      if (nextChannelId == _activeChannelId) {
        _appState = nextState;
        return; 
      }
    }
    
    _appState = nextState;
  }

  void _forceFullLandscape() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _wakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {}
  }

  void _startBlinkTimer() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted) setState(() => _liveBlink = !_liveBlink);
    });
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _showControls && _typed.isEmpty && !_showChannelList) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    if (_showChannelList) return; 
    setState(() => _showControls = !_showControls);
    if (_showControls) _startControlsTimer();
  }

  // ========== Controller Handle (রেস কন্ডিশন, ট্র্যাকিং ব্লকার ও মেমোরি ফিক্সড) ==========

  Future<void> _disposeController() async {
    if (_ctrl != null) {
      final oldCtrl = _ctrl!;
      _ctrl = null;
      if (_ctrlListener != null) {
        oldCtrl.removeListener(_ctrlListener!);
        _ctrlListener = null;
      }
      try {
        await oldCtrl.setVolume(0);
        if (oldCtrl.value.isPlaying) {
          await oldCtrl.pause();
        }
      } catch (_) {}
      oldCtrl.dispose();
    }
  }

  Future<void> _initController() async {
    if (!mounted || _appState == null) return;
    final channel = _appState!.currentChannel;

    if (_activeChannelId == channel.id &&
        _ctrl != null &&
        _ctrl!.value.isInitialized &&
        !_ctrl!.value.hasError) return;

    // প্রতিবার কল হওয়ার সময় একটি ইউনিক টাইমস্ট্যাম্প লক তৈরি করা হচ্ছে
    final int thisInitTimestamp = DateTime.now().millisecondsSinceEpoch;
    _currentInitTimestamp = thisInitTimestamp;

    setState(() {
      _isLoading = true;
      _hasStreamError = false;
      _activeChannelId = channel.id;
    });

    await _disposeController(); 

    // সিকিউরিটি লেয়ার: কাস্টম হেডার ও এজেন্ট পাসিং (লিঙ্ক ট্র্যাকিং ও থার্ড পার্টি প্লেয়ার ব্লকার)
    final newCtrl = VideoPlayerController.networkUrl(
      Uri.parse(channel.streamUrl),
      videoPlayerOptions: VideoPlayerOptions(
        allowBackgroundPlayback: false,
        mixWithOthers: false,
      ),
      httpHeaders: {
        'User-Agent': 'oTtking-AndroidTV-Secure-Agent',
        'X-App-Token': 'backend_generated_secret_handshake_token',
        'Origin': 'https://ottking.internal',
        'Accept': '*/*',
        'Connection': 'keep-alive',
      },
    );

    try {
      await newCtrl.initialize().timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw TimeoutException('timeout'),
          );

      // রেস কন্ডিশন চেক: নেটওয়ার্ক রিকোয়েস্ট আসার মাঝে ইউজার অন্য চ্যানেলে চলে গেছে কিনা?
      if (_currentInitTimestamp != thisInitTimestamp || !mounted) {
        newCtrl.dispose();
        return; 
      }

      await newCtrl.play();
      _wakelock();

      _ctrlListener = _onCtrlUpdate;
      newCtrl.addListener(_ctrlListener!);
      _retryCount = 0;

      setState(() {
        _ctrl = newCtrl;
        _isLoading = false;
        _hasStreamError = false;
      });
    } catch (e) {
      debugPrint('Init error: $e');
      
      // শুধুমাত্র কারেন্ট চ্যানেলের জন্য এরর হ্যান্ডেল হবে, স্কিপ হওয়া চ্যানেলের জন্য নয়
      if (_currentInitTimestamp == thisInitTimestamp && mounted) {
        newCtrl.dispose();
        _handleLoadError();
      } else {
        newCtrl.dispose();
      }
    }
  }

  void _onCtrlUpdate() {
    if (!mounted) return;
    
    if (_ctrl?.value.hasError == true) {
      _scheduleRetry();
      return;
    }

    if (_ctrl != null && _ctrl!.value.isInitialized) {
      if (!_ctrl!.value.isBuffering && 
          !_ctrl!.value.isPlaying && 
          !_hasStreamError && 
          !_isLoading) {
        _ctrl!.play();
      }
    }
    setState(() {});
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    if (_retryCount >= _maxRetry) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasStreamError = true;
        });
      }
      return;
    }
    _retryCount++;
    if (mounted) setState(() => _isLoading = true);
    _retryTimer = Timer(Duration(seconds: _retryCount * 2), () {
      if (mounted) {
        setState(() => _activeChannelId = null);
        _initController();
      }
    });
  }

  void _handleLoadError() {
    if (!mounted) return;
    if (_retryCount < _maxRetry) {
      _scheduleRetry();
    } else {
      setState(() {
        _isLoading = false;
        _hasStreamError = true;
      });
    }
  }

  // ========== Channel Switch ==========

  void _switchChannel(int direction) async {
    if (_appState == null) return;

    _retryTimer?.cancel();
    _retryCount = 0;
    
    // বাটন চাপার সাথে সাথে আগের রানিং টাইমস্ট্যাম্প বাতিল করে দেওয়া হলো
    _currentInitTimestamp = DateTime.now().millisecondsSinceEpoch;

    await _disposeController();

    setState(() {
      _showControls = true;
      _isLoading = true;
      _hasStreamError = false;
      _activeChannelId = null; 
    });
    _startControlsTimer();

    _appState!.switchChannel(direction);

    Future.microtask(() {
      if (mounted) _initController();
    });
  }

  void _switchToIndex(int index) async {
    if (_appState == null) return;
    final allCh = _appState!.channels;
    if (index < 0 || index >= allCh.length) {
      _showSnack('$index নম্বরে কোনো চ্যানেল নেই');
      return;
    }

    _retryTimer?.cancel();
    _retryCount = 0;
    
    _currentInitTimestamp = DateTime.now().millisecondsSinceEpoch;

    await _disposeController();

    setState(() {
      _showControls = true;
      _isLoading = true;
      _hasStreamError = false;
      _activeChannelId = null;
    });

    _appState!.selectChannelByIndex(index);
    
    Future.microtask(() {
      if (mounted) _initController();
    });
  }

  void _handleNumberInput(String digit) {
    _numberTimer?.cancel();
    setState(() {
      _showControls = true;
      _typed += digit;
    });
    _numberTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && _typed.isNotEmpty) {
        final n = int.tryParse(_typed);
        if (n != null) _switchToIndex(n - 1);
        setState(() => _typed = '');
        _startControlsTimer();
      }
    });
  }

  // ========== Settings Dialog ==========

  void _openSettings() {
    _controlsTimer?.cancel();
    showDialog(
      context: context,
      builder: (_) => Consumer<AppState>(
        builder: (ctx, state, __) => _SettingsDialog(
          state: state,
          onAppInfo: () {
            Navigator.pop(context); 
            _showAppInfo();
          },
          onNavigateSettings: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/settings');
          },
          onClose: () => Navigator.pop(context),
        ),
      ),
    ).then((_) {
      _focus.requestFocus(); // ডায়ালগ বন্ধ হলে মেইন রিমোট ফোকাস রিস্টোর
      _startControlsTimer();
    });
  }

  void _showAppInfo() {
    showDialog(
      context: context,
      builder: (_) => const AppInfoDialog(),
    ).then((_) {
      _focus.requestFocus(); 
      _startControlsTimer();
    });
  }

  // ========== Exit Logic ==========

  Future<void> _handleExit() async {
    if (_appState == null) return;
    final shouldFullExit = _appState!.isPlayerBootEnabled;

    if (shouldFullExit) {
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.primary, width: 1.5),
          ),
          title: const Text(
            'অ্যাপ এক্সিট করবেন?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'সম্পূর্ণ অ্যাপ বন্ধ করতে চান?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('না', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('হ্যাঁ', style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) await _exit();
    } else {
      await _goToHome();
    }
  }

  Future<void> _goToHome() async {
    _controlsTimer?.cancel();
    _numberTimer?.cancel();
    _retryTimer?.cancel();
    _blinkTimer?.cancel();
    try { await WakelockPlus.disable(); } catch (_) {}
    await _disposeController();
    if (!mounted) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _exit() async {
    _controlsTimer?.cancel();
    _numberTimer?.cancel();
    _retryTimer?.cancel();
    _blinkTimer?.cancel();
    try { await WakelockPlus.disable(); } catch (_) {}
    await _disposeController();
    if (!mounted) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    exit(0);
  }

  void _togglePlayPause() {
    if (_isLoading || _hasStreamError) return;
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    setState(() {
      c.value.isPlaying ? c.pause() : c.play();
    });
    _wakelock();
    _startControlsTimer();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars
      ..showSnackBar(SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 2),
          backgroundColor: AppTheme.card));
  }

  // ========== Proper Android TV Remote Key Handler ==========

  void _handleKey(KeyEvent event) {
    final label = event.logicalKey.keyLabel;

    if (event is KeyDownEvent) {
      // ১. নম্বর বাটন হ্যান্ডলিং (0-9)
      if (RegExp(r'^[0-9]$').hasMatch(label)) {
        _handleNumberInput(label);
        return;
      }

      // ২. চ্যানেল আপ / রিমোটের আপ বাটন (চ্যানেল পরিবর্তন -১)
      if (event.logicalKey == LogicalKeyboardKey.channelUp ||
          event.logicalKey == LogicalKeyboardKey.pageUp ||
          event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _switchChannel(-1);
        return;
      }
      
      // ৩. চ্যানেল ডাউন / রিমোটের ডাউন বাটন (চ্যানেল পরিবর্তন +১)
      if (event.logicalKey == LogicalKeyboardKey.channelDown ||
          event.logicalKey == LogicalKeyboardKey.pageDown ||
          event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _switchChannel(1);
        return;
      }

      // ৪. ওকে (OK) / এন্টার বাটন চেপে ধরা ট্র্যাকিং
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.space) {
        _okDown ??= DateTime.now();
        _longHandled = false;
      }

      // ৫. কন্ট্রোল প্যানেল হাইড থাকলে যেকোনো বাটন প্রেস করলে আগে প্যানেল শো করবে
      if (!_showControls) {
        setState(() => _showControls = true);
        _startControlsTimer();
        return;
      }
      _startControlsTimer();

      // ৬. ব্যাক বাটন প্রেস (Exit Logic)
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.goBack) {
        _handleExit();
      }
    }

    // ফিক্সড: KeyUpEvent স্ট্যান্ডার্ড রিমোট হ্যান্ডলার
    if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.space) {
        final held = _okDown != null ? DateTime.now().difference(_okDown!) : Duration.zero;
        _okDown = null;

        // ৮মশো মিলি-সেকেন্ড বা তার বেশি চেপে ধরলে লং-প্রেস (চ্যানেল লিস্ট প্যানেল ওপেন)
        if (!_longHandled && held.inMilliseconds >= 800) {
          _longHandled = true;
          setState(() {
            _showChannelList = !_showChannelList;
            if (_showChannelList) _showControls = true;
          });
        } else if (!_longHandled) {
          // নরমাল সিঙ্গেল ক্লিকে প্লে/পজ
          _togglePlayPause();
        }
        _longHandled = false;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlsTimer?.cancel();
    _numberTimer?.cancel();
    _retryTimer?.cancel();
    _blinkTimer?.cancel();
    try { WakelockPlus.disable(); } catch (_) {}
    _disposeController();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_appState == null) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final ch = _appState!.currentChannel;
    final initialized = _ctrl != null && _ctrl!.value.isInitialized && !_hasStreamError;
    final isLive = _ctrl?.value.duration == Duration.zero || _ctrl?.value.duration == null;

    return KeyboardListener(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControls,
          onHorizontalDragEnd: (d) {
            if (d.primaryVelocity == null) return;
            if (d.primaryVelocity! < -300) _switchChannel(1);
            if (d.primaryVelocity! > 300) _switchChannel(-1);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (initialized)
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.fill, // TV Aspect ratio স্ট্রেচ (fitXY)
                    child: SizedBox(
                      width: _ctrl!.value.size.width,
                      height: _ctrl!.value.size.height,
                      child: VideoPlayer(_ctrl!),
                    ),
                  ),
                )
              else
                LoadingOverlay(
                  hasError: _hasStreamError,
                  retryCount: _retryCount,
                  maxRetry: _maxRetry,
                  channelName: ch.name,
                  onRetry: () {
                    _retryCount = 0;
                    setState(() {
                      _hasStreamError = false;
                      _activeChannelId = null;
                    });
                    _initController();
                  },
                  onNext: () => _switchChannel(1),
                ),

              if (_showControls)
                PlayerTopPanel(
                  channel: ch,
                  currentIndex: _appState!.currentChannelIndex,
                  totalChannels: _appState!.channels.length,
                  onSettings: _openSettings,
                  typedNumber: _typed,
                ),

              if (_showControls && initialized)
                PlayerBottomBar(
                  ctrl: _ctrl!,
                  isLive: isLive,
                  liveBlink: _liveBlink,
                  onPlayPause: _togglePlayPause,
                  onExit: _handleExit,
                  onChannelUp: () => _switchChannel(-1),
                  onChannelDown: () => _switchChannel(1),
                ),

              if (_showChannelList)
                ChannelListPanel(
                  channels: _appState!.channels,
                  currentIndex: _appState!.currentChannelIndex,
                  onSelect: (i) {
                    setState(() => _showChannelList = false);
                    _switchToIndex(i);
                  },
                  onClose: () => setState(() => _showChannelList = false),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== Settings Dialog (সম্পূর্ণ বাংলা টেক্সট ও বাগ ফিক্সড) ==========

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({
    required this.state,
    required this.onAppInfo,
    required this.onNavigateSettings,
    required this.onClose,
  });

  final AppState state;
  final VoidCallback onAppInfo;
  final VoidCallback onNavigateSettings;
  final VoidCallback onClose;

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  final List<FocusNode> _focusNodes = [];
  int _focusedIndex = 0;
  int _totalItems = 0;

  @override
  void initState() {
    super.initState();
    
    _totalItems = widget.state.isAuthenticated ? 4 : 3; 
    _totalItems += 1; // নিচের এক্সট্রা সেটিংস বাটনের জন্য (+১)

    for (int i = 0; i < _totalItems; i++) {
      _focusNodes.add(FocusNode(debugLabel: 'settings-item-$i'));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusNodes.isNotEmpty) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final n in _focusNodes) n.dispose();
    super.dispose();
  }

  void _moveFocus(int dir) {
    if (_focusNodes.isEmpty) return;
    final next = (_focusedIndex + dir).clamp(0, _focusNodes.length - 1);
    setState(() => _focusedIndex = next);
    _focusNodes[next].requestFocus();
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveFocus(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveFocus(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _focusableItem({
    required int listIndex,
    required Widget child,
    required VoidCallback onActivate,
  }) {
    final isFocused = _focusedIndex == listIndex;
    return Focus(
      focusNode: _focusNodes[listIndex],
      onFocusChange: (v) {
        if (v) setState(() => _focusedIndex = listIndex);
      },
      onKeyEvent: (_, e) {
        if (e is KeyDownEvent &&
            (e.logicalKey == LogicalKeyboardKey.enter ||
                e.logicalKey == LogicalKeyboardKey.select)) {
          onActivate();
          return KeyEventResult.handled;
        }
        return _onKey(e);
      },
      child: GestureDetector(
        onTap: onActivate,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isFocused ? AppTheme.primary.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isFocused ? AppTheme.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    int currentVisualIndex = 0; 

    return AlertDialog(
      backgroundColor: Colors.black.withOpacity(0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      title: const Row(
        children: [
          Icon(Icons.settings, color: Colors.white),
          Spacer(),
          Text('প্লেয়ার সেটিংস', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _focusableItem(
            listIndex: currentVisualIndex++,
            onActivate: () => state.togglePlayerBoot(),
            child: SwitchListTile(
              title: const Text('Boot Player (অটো প্লেয়ার)', style: TextStyle(color: Colors.white)),
              subtitle: Text(
                'অ্যাপ চালু হলে সরাসরি লাইভ টিভি খুলবে',
                style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12),
              ),
              activeColor: AppTheme.primary,
              value: state.isPlayerBootEnabled,
              onChanged: (v) => state.togglePlayerBoot(),
            ),
          ),

          if (state.isAuthenticated)
            _focusableItem(
              listIndex: currentVisualIndex++,
              onActivate: () {},
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ListTile(
                  leading: const Icon(Icons.stars_rounded, color: Color(0xFFEAB308)),
                  title: Text(
                    state.userProfile?.email ?? '',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'প্ল্যান: ${state.userProfile?.plan ?? ''}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ),
            ),

          const Divider(color: Colors.white12, height: 20),

          _focusableItem(
            listIndex: currentVisualIndex++,
            onActivate: widget.onAppInfo,
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded, color: AppTheme.primary),
              title: const Text('অ্যাপ তথ্য (App Info)', style: TextStyle(color: Colors.white)),
              subtitle: const Text('ভার্সন ও ডেভেলপার তথ্য',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            ),
          ),
        ],
      ),
      actions: [
        _focusableItem(
          listIndex: currentVisualIndex++,
          onActivate: widget.onNavigateSettings,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              'সেটিংস', 
              style: TextStyle(color: _focusedIndex == (currentVisualIndex - 1) ? Colors.white : Colors.white54),
            ),
          ),
        ),
        TextButton(
          onPressed: widget.onClose,
          child: Text('বন্ধ', style: TextStyle(color: AppTheme.primary)),
        ),
      ],
    );
  }
}
