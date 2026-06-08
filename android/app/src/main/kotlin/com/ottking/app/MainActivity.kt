package com.ottking.app

import android.content.Context
import android.app.UiModeManager
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.view.WindowManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.ottking.app/device_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "isAndroidTV") {
                result.success(checkIsTvReal())
            } else {
                result.notImplemented()
            }
        }
    }

    private fun checkIsTvReal(): Boolean {
        // ১. স্ট্যান্ডার্ড চেক (UiModeManager)
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
        if (uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION) {
            return true
        }

        // ২. সিস্টেম ফিচার চেক (Leanback / Fire TV)
        if (packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
            packageManager.hasSystemFeature("amazon.hardware.fire_tv")) {
            return true
        }

        // ৩. কাস্টম/লোকাল টিভি বক্স বা চায়না টিভি ফিক্স (হার্ডওয়্যার টাইপ চেক)
        if (Build.CHARACTERISTICS != null && Build.CHARACTERISTICS.contains("tv")) {
            return true
        }

        return false
    }
}
