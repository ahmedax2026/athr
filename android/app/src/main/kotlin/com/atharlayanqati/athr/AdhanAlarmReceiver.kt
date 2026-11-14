package com.atharlayanqati.athr

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class AdhanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            intent.action == android.app.AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED) {
            AdhanScheduler.restore(context)
            return
        }
        val scheduledAt = intent.getLongExtra("scheduledAt", 0L)
        val voice = intent.getStringExtra("voice") ?: "adhan_makkah"
        val now = System.currentTimeMillis()
        val isAdhan = voice != "reminder" && voice != "qiyam"
        val limitMs = if (isAdhan) intent.getIntExtra("lateLimitSeconds", 120).coerceIn(60, 600) * 1000L else 120000L
        if (scheduledAt <= 0L || now < scheduledAt || now - scheduledAt >= limitMs) return
        if (isAdhan && Build.VERSION.SDK_INT >= 31 && !(context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager).canScheduleExactAlarms()) return
        val service = Intent(context, AdhanPlaybackService::class.java)
            .putExtra("voice", voice)
            .putExtra("preview", intent.getBooleanExtra("preview", false))
            .putExtra("prayer", intent.getStringExtra("prayer") ?: "")
        try {
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(service)
            else context.startService(service)
        } catch (e: Exception) {
            android.util.Log.e("AthrAdhan", "Background playback blocked", e)
        }
    }
}
