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
                } else if (call.method == "setCheckinsEnabled") {
                    val enabled = call.argument<Boolean>("enabled")
                    if (enabled == null) {
                        result.error("ARGUMENT", "Missing enabled flag", null)
                    } else {
                        AdhanScheduler.setCheckinEnabled(this, enabled)
                        result.success(true)
                    }
                } else result.notImplemented()
            }
    }
}
