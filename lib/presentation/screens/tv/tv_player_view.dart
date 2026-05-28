// lib/presentation/screens/tv_player_view.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../providers/app_state.dart';

class TvPlayerView extends StatefulWidget {
  const TvPlayerView({super.key});

  @override
  State<TvPlayerView> createState() => _TvPlayerViewState();
}

class _TvPlayerViewState extends State<TvPlayerView> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'tv-player-root');
  VideoPlayerController? _controller;
  VoidCallback? _controllerListener;
  String? _activeChannelId;
  bool _showControls = true;
  bool _isLoading = false;
  AppState? _appState; 
  
  Timer? _controlsTimer;
  String _typedChannelNumber = ""; 
  Timer? _numberInputTimer;        

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _enableWakelock();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _appState = Provider.of<AppState>(context, listen: false);
        _initController();
        _startControlsTimer();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = context.watch<AppState>();
  }

  void _enableWakelock() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      bool isEnabled = await WakelockPlus.enabled;
      if (!isEnabled) await WakelockPlus.enable();
    } catch (e) {
      debugPrint("TV Wakelock failed: $e");
    }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _showControls && _typedChannelNumber.isEmpty) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControlsVisibility() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startControlsTimer();
  }

  Future<void> _initController() async {
    if (!mounted || _appState == null) return;
    final channel = _appState!.currentChannel;
    if (_activeChannelId == channel.id && _controller != null) return;

    setState(() {
      _isLoading = true;
      _activeChannelId = channel.id;
    });

    if (_controller != null) {
      final oldCtrl = _controller!;
      _controller = null; 
      if (_controllerListener != null) oldCtrl.removeListener(_controllerListener!);
      try {
        await oldCtrl.setVolume(0.0);
        if (oldCtrl.value.isPlaying) await oldCtrl.pause();
      } catch (_) {} finally { oldCtrl.dispose(); }
    }

    final newController = VideoPlayerController.networkUrl(
      Uri.parse(channel.streamUrl),
      videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: false),
      httpHeaders: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': '*/*',
        'Connection': 'keep-alive',
      },
    );

    try {
      await newController.initialize();
      if (!mounted) { await newController.dispose(); return; }
      await newController.play();
      _enableWakelock();
      
      _controllerListener = () { if (mounted) setState(() {}); };
      newController.addListener(_controllerListener!);

      setState(() {
        _controller = newController;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; _activeChannelId = null; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${channel.name} লোড হতে ব্যর্থ হয়েছে।')),
        );
      }
    }
  }

  void _safeChannelSwitch(int direction) {
    if (_appState == null) return;
    setState(() { _showControls = true; _isLoading = true; _activeChannelId = null; });
    _startControlsTimer();
    _appState!.switchChannel(direction);
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _initController(); });
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final keyLabel = event.logicalKey.keyLabel;
    
    if (RegExp(r'^[0-9]$').hasMatch(keyLabel)) {
      _numberInputTimer?.cancel();
      setState(() { _showControls = true; _typedChannelNumber += keyLabel; });
      _numberInputTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted && _typedChannelNumber.isNotEmpty) {
          final targetNum = int.tryParse(_typedChannelNumber);
          if (targetNum != null && targetNum > 0 && targetNum <= _appState!.channels.length) {
            _appState!.selectChannelByIndex(targetNum - 1);
            _initController();
          }
          setState(() => _typedChannelNumber = "");
          _startControlsTimer();
        }
      });
      return;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _safeChannelSwitch(-1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _safeChannelSwitch(1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.escape || event.logicalKey == LogicalKeyboardKey.goBack) {
      _exitPlayer();
    } else if (event.logicalKey == LogicalKeyboardKey.space || event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.select) {
      if (_controller != null) {
        setState(() {
          _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
          if (_controller!.value.isPlaying) _enableWakelock();
        });
      }
    }
  }

  void _exitPlayer() {
    _controlsTimer?.cancel(); _numberInputTimer?.cancel();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  void dispose() {
    _controlsTimer?.cancel(); _numberInputTimer?.cancel();
    WakelockPlus.disable();
    if (_controller != null && _controllerListener != null) _controller!.removeListener(_controllerListener!);
    _controller?.dispose(); _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_appState == null) return const Scaffold(backgroundColor: Colors.black);
    final currentChannel = _appState!.currentChannel;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControlsVisibility,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_controller != null && _controller!.value.isInitialized && !_isLoading)
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                )
              else
                const Center(child: CircularProgressIndicator(color: Colors.white)),

              if (_showControls) ...[
                // টপ বার (টিভি ওএস স্টাইল)
                Positioned(
                  left: 0, right: 0, top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    color: Colors.black38,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${currentChannel.name}  •  ${currentChannel.quality}', 
                             style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: _exitPlayer),
                      ],
                    ),
                  ),
                ),
                // ডি-প্যাড বা রিমোট গাইড সেন্টার কন্ট্রোল
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 36), onPressed: () => _safeChannelSwitch(-1)),
                      const SizedBox(width: 50),
                      Icon(_controller?.value.isPlaying == true ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white, size: 64),
                      const SizedBox(width: 50),
                      IconButton(icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 36), onPressed: () => _safeChannelSwitch(1)),
                    ],
                  ),
                ),
              ],
              // ওএসডি নম্বর ওভারলে
              if (_typedChannelNumber.isNotEmpty)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(color: Colors.black90, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.cyan, width: 2.5)),
                    child: Text(_typedChannelNumber, style: const TextStyle(color: Colors.white, fontSize: 60, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
