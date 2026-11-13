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
            if (voice != "adhan_makkah" && voice != "adhan_afasy") continue
            val id = index
            val json = JSONObject().put("id", id).put("at", at).put("voice", voice)
            stored.put(json)
            set(context, id, at, voice)
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
                set(context, e.optInt("id"), at, e.optString("voice", "adhan_makkah"))
            }
        }
    }

    private fun set(context: Context, id: Int, at: Long, voice: String) {
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AdhanAlarmReceiver::class.java)
            .putExtra("voice", voice)
        val request = PendingIntent.getBroadcast(context, BASE + id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        if (Build.VERSION.SDK_INT >= 31 && !alarm.canScheduleExactAlarms()) {
            alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, request)
        } else {
            alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, request)
        }
    }
}
