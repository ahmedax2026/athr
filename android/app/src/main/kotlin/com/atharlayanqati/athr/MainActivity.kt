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
                            val retriever = android.media.MediaMetadataRetriever()
                            try {
                                retriever.setDataSource(file.absolutePath + ".part")
                                val duration = retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
                                val audio = retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO)
                                result.success(audio == "yes" && duration in 1000L..600000L)
                            } catch (_: Exception) {
                                result.success(false)
                            } finally {
                                retriever.release()
                            }
                        }
                    }
                } else result.notImplemented()
            }
    }
}
