package com.atharlayanqati.athr

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder

class AdhanPlaybackService : Service() {
    private var player: MediaPlayer? = null
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val channel = "athr_full_adhan_player"
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(
                channel, "تشغيل الأذان كاملًا", NotificationManager.IMPORTANCE_LOW))
        }
        val stop = PendingIntent.getService(this, 87,
            Intent(this, AdhanPlaybackService::class.java).setAction("STOP"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = Notification.Builder(this, channel)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(if (intent?.getStringExtra("voice") == "qiyam") "أثر لا ينقطع • قيام الليل" else "أثر لا ينقطع • حان وقت الصلاة")
            .setContentText(if (intent?.getStringExtra("voice") == "qiyam") "تذكير خفيف بركعتي قيام الليل" else "الأذان أو التذكير يعمل الآن")
            .addAction(Notification.Action.Builder(null, "إيقاف الأذان", stop).build())
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(780, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(780, notification)
        }
        if (intent?.action == "STOP") {
            stopSelf()
            return START_NOT_STICKY
        }
        player?.release()
        player = null
        val voice = intent?.getStringExtra("voice") ?: "adhan_makkah"
        if (voice == "reminder" || voice == "qiyam") {
            // Human voice only. Do not synthesize spoken prayer names.
            // Add reminder_fajr/dhuhr/asr/maghrib/isha.mp3 to assets/adhan.
            val prayer = intent?.getStringExtra("prayer") ?: ""
            val prayerKey = when (prayer) {
                "الفجر" -> "fajr"
                "الظهر" -> "dhuhr"
                "العصر" -> "asr"
                "المغرب" -> "maghrib"
                "العشاء" -> "isha"
                else -> ""
            }
            val resourceName = if (voice == "qiyam") "reminder_qiyam"
                else if (prayerKey.isNotEmpty()) "reminder_" + prayerKey else ""
            val resId = if (resourceName.isEmpty()) 0
                else resources.getIdentifier(resourceName, "raw", packageName)
            try {
                // A normal system alert is the fallback until a real male
                // recording is supplied; never impersonate a human voice.
                val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                val media = if (resId != 0) MediaPlayer.create(this, resId)
                    else MediaPlayer.create(this, uri)
                player = media
                media?.setOnCompletionListener { stopSelf() }
                media?.setOnErrorListener { _, _, _ -> stopSelf(); true }
                media?.start()
                if (media == null) stopSelf()
            } catch (_: Exception) { stopSelf() }
            return START_NOT_STICKY
        }
        val res = if (voice == "adhan_afasy") R.raw.adhan_afasy else R.raw.adhan_makkah
        try {
            val media = MediaPlayer()
            player = media
            media.setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
            val file = if (Regex("remote_[a-zA-Z0-9_]{1,64}").matches(voice))
                java.io.File(java.io.File(filesDir, "adhan_voices"), "$voice.mp3") else null
            if (file != null && file.isFile) {
                media.setDataSource(file.absolutePath)
            } else {
                resources.openRawResourceFd(res).use { descriptor ->
                    media.setDataSource(descriptor.fileDescriptor, descriptor.startOffset, descriptor.length)
                }
            }
            media.setOnCompletionListener { stopSelf() }
            media.setOnErrorListener { _, _, _ -> stopSelf(); true }
            media.prepare()
            media.start()
            player = media
        } catch (_: Exception) {
            stopSelf()
        }
        return START_NOT_STICKY
    }
    override fun onDestroy() {
        player?.run { if (isPlaying) stop(); release() }
        player = null
        super.onDestroy()
    }
}
