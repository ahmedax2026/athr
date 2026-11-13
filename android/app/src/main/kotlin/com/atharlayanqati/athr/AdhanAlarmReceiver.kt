package com.atharlayanqati.athr

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class AdhanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            AdhanScheduler.restore(context)
            return
        }
        val voice = intent.getStringExtra("voice") ?: "adhan_makkah"
        val service = Intent(context, AdhanPlaybackService::class.java)
            .putExtra("voice", voice)
            .putExtra("prayer", intent.getStringExtra("prayer") ?: "")
        try {
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(service)
            else context.startService(service)
        } catch (_: Exception) {
            // Device background restrictions may block playback.
        }
    }
}
