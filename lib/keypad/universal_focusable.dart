// lib/keypad/universal_focusable.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'remote_keys.dart';

class UniversalFocusable extends StatefulWidget {
  const UniversalFocusable({
    super.key,
    required this.onTap,
    required this.builder,
    this.focusNode,
    this.autofocus = false,
    this.onDirectionPressed,
  });

  final VoidCallback onTap;
  final FocusNode? focusNode;
  final bool autofocus;
  
  /// এটি বলে দেবে কোন উইজেটটি এখন একটিভ এবং ফোকাসড অবস্থায় আছে কি না
  final Widget Function(BuildContext context, bool isFocused) builder;

  /// বিশেষ কোনো ডিরেকশনে (যেমন শুধু লেফট চাপলে আলাদা পেজ লোড হওয়া) কাস্টম লজিক চালানোর জন্য
  final Function(LogicalKeyboardKey key)? onDirectionPressed;

  @override
  State<UniversalFocusable> createState() => _UniversalFocusableState();
}

class _UniversalFocusableState extends State<UniversalFocusable> {
  bool _isFocused = false;
  late final FocusNode _node;

  @override
  void initState() {
    super.initState();
    _node = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        // ১. ইউনিভার্সাল OK বাটন চেকার (সব স্মার্ট ওএস এবং বক্সের জন্য)
        if (RemoteKeys.isOk(event)) {
          widget.onTap();
          return KeyEventResult.handled;
        }

        // ২. যদি কোনো স্পেসিফিক ডিরেকশনে কাস্টম কাজ করাতে চান (যেমন: বাঁয়ে চাপলে মেনু খোলা)
        if (RemoteKeys.isDirection(event) && widget.onDirectionPressed != null) {
          widget.onDirectionPressed!(event.logicalKey);
          // এখানে ignored রাখব যাতে কাস্টম লজিকের পাশাপাশি ফোকাসও মুভ হতে পারে
          return KeyEventResult.ignored; 
        }

        return KeyEventResult.ignored;
      },
      child: InkWell(
        onTap: widget.onTap,
        canRequestFocus: false, // ফোকাস ইঞ্জিন জটলা পাকানো রোধ করতে এটি মাস্ট
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: widget.builder(context, _isFocused),
      ),
    );
  }
}
