package com.atharlayanqati.athr

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

object AdhanScheduler {
    private const val STORE = "adhan_background_alarms"
    private const val KEY = "alarms"
    private const val BASE = 46000

    private fun pending(context: Context, id: Int): PendingIntent {
        val intent = Intent(context, AdhanAlarmReceiver::class.java)
        return PendingIntent.getBroadcast(context, BASE + id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    fun update(context: Context, entries: List<Map<String, Any?>>) {
        val prefs = context.getSharedPreferences(STORE, Context.MODE_PRIVATE)
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val previous = JSONArray(prefs.getString(KEY, "[]") ?: "[]")
        for (i in 0 until previous.length()) {
            alarms.cancel(pending(context, previous.optJSONObject(i)?.optInt("id") ?: i))
        }
        val stored = JSONArray()
        for ((index, entry) in entries.withIndex()) {
            val at = (entry["at"] as? Number)?.toLong() ?: continue
            if (at <= System.currentTimeMillis()) continue
            val voice = entry["voice"] as? String ?: "adhan_makkah"
            if (voice != "adhan_makkah" && voice != "adhan_afasy" && voice != "reminder") continue
            val id = index
            val prayer = entry["prayer"] as? String ?: ""
            val json = JSONObject().put("id", id).put("at", at).put("voice", voice).put("prayer", prayer)
            stored.put(json)
            set(context, id, at, voice, prayer)
        }
        prefs.edit().putString(KEY, stored.toString()).apply()
    }

    fun restore(context: Context) {
        val prefs = context.getSharedPreferences(STORE, Context.MODE_PRIVATE)
        val entries = JSONArray(prefs.getString(KEY, "[]") ?: "[]")
        for (i in 0 until entries.length()) {
            val e = entries.optJSONObject(i) ?: continue
            val at = e.optLong("at")
            if (at > System.currentTimeMillis()) {
                set(context, e.optInt("id"), at, e.optString("voice", "adhan_makkah"), e.optString("prayer", ""))
            }
        }
    }

    fun test(context: Context, voice: String) {
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        check(Build.VERSION.SDK_INT < 31 || alarm.canScheduleExactAlarms()) { "Exact alarm permission required" }
        set(context, 9999, System.currentTimeMillis() + 120000L, voice, "تجربة الأذان")
    }

    private fun set(context: Context, id: Int, at: Long, voice: String, prayer: String) {
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AdhanAlarmReceiver::class.java)
            .putExtra("voice", voice)
            .putExtra("prayer", prayer)
            .putExtra("scheduledAt", at)
        val request = PendingIntent.getBroadcast(context, BASE + id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        if (Build.VERSION.SDK_INT >= 31 && !alarm.canScheduleExactAlarms()) {
            alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, request)
        } else if (voice != "reminder") {
            val show = PendingIntent.getActivity(context, 45999,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            alarm.setAlarmClock(AlarmManager.AlarmClockInfo(at, show), request)
        } else {
            alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, request)
        }
    }
}
