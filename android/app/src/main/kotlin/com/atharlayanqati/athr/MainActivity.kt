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
                 } else if (call.method == "voicePath" || call.method == "validateVoice") {
                    val id = call.argument<String>("id") ?: ""
                    if (!Regex("remote_[a-zA-Z0-9_]{1,64}").matches(id)) {
                        result.error("INVALID_VOICE", "Invalid voice ID", null)
                    } else {
                        val dir = java.io.File(filesDir, "adhan_voices")
                        dir.mkdirs()
                        val file = java.io.File(dir, "$id.mp3")
                        if (call.method == "voicePath") {
                            result.success(file.absolutePath)
                        } else {
                            // Validate with the same decoder used for actual scheduled playback.
                            Thread {
                                val valid = try {
                                    val media = android.media.MediaPlayer()
                                    try {
                                        media.setDataSource(file.absolutePath + ".part")
                                        media.prepare()
                                        media.duration in 1000..600000
                                    } finally {
                                        media.release()
                                    }
                                } catch (_: Exception) { false }
                                runOnUiThread { result.success(valid) }
                            }.start()
                        }
                    }
                } else if (call.method == "testAdhan") {
                    try {
                        AdhanScheduler.test(this, call.argument<String>("voice") ?: "adhan_makkah", call.argument<Int>("seconds") ?: 10)
                        result.success(true)
                    } catch (e: Exception) { result.error("ADHAN_TEST", e.message, null) }
                } else if (call.method == "batteryStatus") {
                    val power = getSystemService(android.content.Context.POWER_SERVICE) as android.os.PowerManager
                    result.success(power.isIgnoringBatteryOptimizations(packageName))
                } else if (call.method == "batterySettings" || call.method == "exactSettings" || call.method == "notificationSettings") {
                    try {
                        val uri = android.net.Uri.parse("package:$packageName")
                        val fallback = android.content.Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS, uri)
                        val target = when {
                            call.method == "exactSettings" && android.os.Build.VERSION.SDK_INT >= 31 -> android.content.Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, uri)
                            call.method == "notificationSettings" && android.os.Build.VERSION.SDK_INT >= 26 -> android.content.Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, packageName)
                            else -> fallback
                        }
                        try { startActivity(target) } catch (_: android.content.ActivityNotFoundException) { startActivity(fallback) }
                        result.success(true)
                    } catch (e: Exception) { result.error("SETTINGS", e.message, null) }
                } else result.notImplemented()
            }
    }
}
