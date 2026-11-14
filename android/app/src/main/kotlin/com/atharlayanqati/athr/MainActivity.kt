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
                        startActivity(android.content.Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS, android.net.Uri.parse("package:$packageName")))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("BATTERY_SETTINGS", e.message, null)
                    }
                } else if (call.method == "exactSettings" || call.method == "notificationSettings") {
                    try {
                        val target = if (call.method == "exactSettings" && android.os.Build.VERSION.SDK_INT >= 31) {
                            android.content.Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, android.net.Uri.parse("package:$packageName"))
                        } else if (call.method == "notificationSettings" && android.os.Build.VERSION.SDK_INT >= 26) {
                            android.content.Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, packageName)
                        } else {
                            android.content.Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS, android.net.Uri.parse("package:$packageName"))
                        }
                        try { startActivity(target) } catch (_: android.content.ActivityNotFoundException) {
                            startActivity(android.content.Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS, android.net.Uri.parse("package:$packageName")))
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PERMISSION_SETTINGS", e.message, null)
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
