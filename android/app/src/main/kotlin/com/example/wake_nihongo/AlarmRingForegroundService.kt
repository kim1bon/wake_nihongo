package com.example.wake_nihongo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class AlarmRingForegroundService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopPlayback()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            stopSelf()
            return START_NOT_STICKY
        }

        val raw = intent?.getStringExtra(EXTRA_RAW) ?: "alram_01"
        val alarmId = intent?.getIntExtra(EXTRA_ALARM_ID, -1) ?: -1
        val soundFlutter = intent?.getStringExtra(EXTRA_SOUND_ID) ?: "Alram_01"

        startForegroundWithNotif(alarmId, soundFlutter, raw)
        startPlayer(raw)
        acquireWakeLock()

        return START_STICKY
    }

    private var player: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID,
                "알람 재생",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                setSound(null, null)
                enableVibration(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(ch)
        }
    }

    private fun startForegroundWithNotif(alarmId: Int, soundId: String, raw: String) {
        val immutable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else 0

        val stopIntent = Intent(this, AlarmStopReceiver::class.java)
        val stopPi = PendingIntent.getBroadcast(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutable,
        )

        val open = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(MainActivity.EXTRA_FROM_ALARM_SERVICE, true)
            putExtra(MainActivity.EXTRA_SOUND_ID, soundId)
            putExtra(MainActivity.EXTRA_ALARM_ID, alarmId)
        }
        val openPi = PendingIntent.getActivity(
            this,
            2,
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or immutable,
        )

        val notif = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("WakeNihongo 알람")
            .setContentText("알람이 울리는 중입니다. 탭하여 앱에서 끄세요.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(openPi)
            .setFullScreenIntent(openPi, true)
            .addAction(0, "알람 끄기", stopPi)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIF_ID,
                notif,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIF_ID, notif)
        }
    }

    private fun startPlayer(raw: String) {
        stopPlayback()
        val resId = resources.getIdentifier(raw, "raw", packageName)
        if (resId == 0) return
        val afd = resources.openRawResourceFd(resId) ?: return
        val p = MediaPlayer()
        try {
            p.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            p.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            p.isLooping = true
            p.prepare()
            p.start()
            player = p
        } catch (_: Exception) {
            p.release()
        } finally {
            try {
                afd.close()
            } catch (_: Exception) { }
        }
    }

    private fun acquireWakeLock() {
        releaseWakeLock()
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "wake_nihongo:AlarmRing")
        wakeLock?.setReferenceCounted(false)
        wakeLock?.acquire(3 * 60 * 60 * 1000L)
    }

    private fun releaseWakeLock() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

    private fun stopPlayback() {
        try {
            player?.stop()
        } catch (_: Exception) { }
        player?.release()
        player = null
        releaseWakeLock()
    }

    override fun onDestroy() {
        stopPlayback()
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL_ID = "wake_nihongo_alarm_loop"
        private const val NOTIF_ID = 42001
        private const val ACTION_STOP = "com.example.wake_nihongo.STOP_ALARM_RING"
        const val EXTRA_RAW = "raw_sound"
        const val EXTRA_ALARM_ID = "alarm_id"
        const val EXTRA_SOUND_ID = "sound_id_flutter"

        fun startRinging(ctx: Context, alarmId: Int, soundIdFlutter: String, raw: String) {
            val i = Intent(ctx, AlarmRingForegroundService::class.java).apply {
                putExtra(EXTRA_RAW, raw)
                putExtra(EXTRA_ALARM_ID, alarmId)
                putExtra(EXTRA_SOUND_ID, soundIdFlutter)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ctx.startForegroundService(i)
            } else {
                ctx.startService(i)
            }
        }

        fun stop(ctx: Context) {
            val i = Intent(ctx, AlarmRingForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            try {
                ctx.startService(i)
            } catch (_: Exception) {
                ctx.stopService(Intent(ctx, AlarmRingForegroundService::class.java))
            }
        }
    }
}
