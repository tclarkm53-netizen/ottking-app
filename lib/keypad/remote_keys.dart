// lib/keypad/remote_keys.dart
import 'package:flutter/services.dart';

class RemoteKeys {
  /// রিমোটের OK / Center / Select বাটন ডিটেক্টর (সব ওএসের জন্য ইউনিভার্সাল)
  static bool isOk(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    return key == LogicalKeyboardKey.select ||
           key == LogicalKeyboardKey.dpadCenter ||
           key == LogicalKeyboardKey.enter ||
           key == LogicalKeyboardKey.gameButtonSelect;
  }

  /// রিমোটের Back / Escape বাটন ডিটেক্টর
  static bool isBack(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    return key == LogicalKeyboardKey.escape ||
           key == LogicalKeyboardKey.goBack ||
           key == LogicalKeyboardKey.backspace;
  }

  /// রিমোটের D-Pad Direction (Arrow) বাটন ডিটেক্টর
  static bool isDirection(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    return key == LogicalKeyboardKey.arrowDown ||
           key == LogicalKeyboardKey.arrowUp ||
           key == LogicalKeyboardKey.arrowLeft ||
           key == LogicalKeyboardKey.arrowRight;
  }
}
