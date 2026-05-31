package com.ottking.app

import android.content.pm.PackageManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "ottking/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // ১. স্ক্রিন সবসময় অন রাখার কোড (আপনার বর্তমান কোড)
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )

        // ২. TV Detection-এর জন্য MethodChannel কোড (নতুন যুক্ত করা হলো)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "isAndroidTV") {
                val pm = packageManager
                val isTV = pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
                result.success(isTV)
            } else {
                result.notImplemented()
            }
        }
    }
}
