package com.atharlayanqati.athr

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "athr/adhan_alarms")
            .setMethodCallHandler { call, result ->
                if (call.method == "schedule") {
                    try {
                        @Suppress("UNCHECKED_CAST")
                        val items = call.arguments as? List<Map<String, Any?>> ?: emptyList()
                        AdhanScheduler.update(this, items)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ADHAN_ALARM", e.message, null)
                    }
                } else if (call.method == "batteryStatus") {
                    val power = getSystemService(android.content.Context.POWER_SERVICE) as android.os.PowerManager
                    result.success(power.isIgnoringBatteryOptimizations(packageName))
                } else if (call.method == "batterySettings") {
                    try {
                        startActivity(android.content.Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("BATTERY_SETTINGS", e.message, null)
                    }
                } else if (call.method == "testAdhan") {
                    try {
                        val voice = call.argument<String>("voice") ?: "adhan_makkah"
                        AdhanScheduler.test(this, voice)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ADHAN_TEST", e.message, null)
                    }
                } else result.notImplemented()
            }
    }
}
