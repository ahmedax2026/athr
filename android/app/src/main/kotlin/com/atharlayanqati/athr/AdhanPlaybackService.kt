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
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import java.util.Locale
import android.os.Build
import android.os.IBinder

class AdhanPlaybackService : Service() {
    private var player: MediaPlayer? = null
    private var tts: TextToSpeech? = null
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
            .setContentTitle("أثر لا ينقطع • حان وقت الصلاة")
            .setContentText("الأذان يعمل الآن • اضغط إيقاف لإنهائه")
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
        if (voice == "reminder") {
            val prayer = intent?.getStringExtra("prayer") ?: "الصلاة"
            tts?.shutdown()
            tts = TextToSpeech(this) { status ->
                val engine = tts
                if (status == TextToSpeech.SUCCESS && engine != null &&
                    engine.setLanguage(Locale.forLanguageTag("ar")) >= TextToSpeech.LANG_AVAILABLE) {
                    engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                        override fun onStart(utteranceId: String?) {}
                        override fun onDone(utteranceId: String?) { stopSelf() }
                        override fun onError(utteranceId: String?) { stopSelf() }
                    })
                    engine.speak("اقتربت صلاة $prayer", TextToSpeech.QUEUE_FLUSH, null, "prayer_reminder")
                } else {
                    try {
                        val media = MediaPlayer.create(this, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION))
                        player = media
                        media?.setOnCompletionListener { stopSelf() }
                        media?.start()
                        if (media == null) stopSelf()
                    } catch (_: Exception) { stopSelf() }
                }
            }
            return START_NOT_STICKY
        }
        val res = if (voice == "adhan_afasy") R.raw.adhan_afasy else R.raw.adhan_makkah
        try {
            val descriptor = resources.openRawResourceFd(res)
            val media = MediaPlayer()
            media.setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
            media.setDataSource(descriptor.fileDescriptor, descriptor.startOffset, descriptor.length)
            descriptor.close()
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
        tts?.stop()
        tts?.shutdown()
        tts = null
        player?.run { if (isPlaying) stop(); release() }
        player = null
        super.onDestroy()
    }
}
