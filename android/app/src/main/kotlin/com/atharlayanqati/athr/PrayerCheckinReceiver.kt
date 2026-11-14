package com.atharlayanqati.athr

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

/** Receives a check-in alarm or a direct action, without launching Flutter. */
class PrayerCheckinReceiver : BroadcastReceiver() {
    companion object {
        private const val CHANNEL = "athr_prayer_checkin_v1"
        private const val ANSWERS = "prayer_checkin_answers"
        const val ACTION_ANSWER = "com.atharlayanqati.athr.PRAYER_CHECKIN_ANSWER"

        fun show(context: Context, prayer: String, scheduledAt: Long) {
            if (prayer !in listOf("الفجر", "الظهر", "العصر", "المغرب", "العشاء")) return
            if (Build.VERSION.SDK_INT >= 33 &&
                context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26) {
                manager.createNotificationChannel(NotificationChannel(
                    CHANNEL, "متابعة أداء الصلاة", NotificationManager.IMPORTANCE_DEFAULT
                ).apply { description = "سؤال بعد الصلاة بنصف ساعة" })
            }
            val notificationId = (scheduledAt / 60000L).toInt() and 0x7fffffff
            fun action(answer: String, label: String): Notification.Action {
                val intent = Intent(context, PrayerCheckinReceiver::class.java)
                    .setAction(ACTION_ANSWER)
                    .putExtra("prayer", prayer)
                    .putExtra("scheduled_at", scheduledAt)
                    .putExtra("answer", answer)
                val requestCode = notificationId * 2 + if (answer == "yes") 1 else 0
                val pi = PendingIntent.getBroadcast(
                    context, requestCode, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                return Notification.Action.Builder(null, label, pi).build()
            }
            val builder = if (Build.VERSION.SDK_INT >= 26)
                Notification.Builder(context, CHANNEL) else Notification.Builder(context)
            val notification = builder
                .setSmallIcon(applicationIcon(context))
                .setContentTitle("هل صليت صلاة $prayer؟")
                .setContentText("مرّت نصف ساعة على موعد الصلاة. تقبّل الله منك.")
                .setStyle(Notification.BigTextStyle().bigText(
                    "مرّت نصف ساعة على موعد صلاة $prayer. تقبّل الله منك."))
                .setAutoCancel(true)
                .setOnlyAlertOnce(true)
                .addAction(action("yes", "نعم، صليت"))
                .addAction(action("not_yet", "ليس بعد"))
                .build()
            manager.notify(notificationId, notification)
        }

        private fun applicationIcon(context: Context): Int =
            context.applicationInfo.icon
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_ANSWER) return
        val prayer = intent.getStringExtra("prayer") ?: return
        val timestamp = intent.getLongExtra("scheduled_at", 0L)
        val answer = intent.getStringExtra("answer") ?: return
        if (timestamp <= 0L || prayer !in listOf("الفجر", "الظهر", "العصر", "المغرب", "العشاء") ||
            answer !in listOf("yes", "not_yet")) return
        val key = "${timestamp}_${prayer}"
        context.getSharedPreferences(ANSWERS, Context.MODE_PRIVATE)
            .edit().putString(key, answer).apply()
        val id = (timestamp / 60000L).toInt() and 0x7fffffff
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(id)
    }
}
