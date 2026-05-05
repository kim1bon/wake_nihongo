package com.bon.nihongona

import android.content.Context
import android.content.Intent
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var nativeChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nativeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_CHANNEL)
        nativeChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "syncAlarms" -> {
                    val json = call.arguments as String
                    AndroidAlarmScheduler.syncFromJson(applicationContext, json)
                    result.success(null)
                }
                "stopRinging" -> {
                    AlarmRingForegroundService.stop(applicationContext)
                    result.success(null)
                }
                "takePendingAlarmLaunch" -> {
                    val i = intent
                    if (i.getBooleanExtra(EXTRA_FROM_ALARM_SERVICE, false)) {
                        val payload = mapOf(
                            "soundId" to (i.getStringExtra(EXTRA_SOUND_ID) ?: "basic"),
                            "alarmId" to i.getIntExtra(EXTRA_ALARM_ID, -1),
                        )
                        i.removeExtra(EXTRA_FROM_ALARM_SERVICE)
                        result.success(payload)
                    } else {
                        result.success(null)
                    }
                }
                "getSoundPreviewPolicy" -> {
                    val am = applicationContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    result.success(
                        mapOf(
                            "ringerHushed" to isRingerHushed(am),
                            "headsetConnected" to hasHeadphoneLikeOutput(am),
                        ),
                    )
                }
                "clearCorruptedScheduledNotificationCache" -> {
                    clearCorruptedScheduledNotificationCache(applicationContext)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra(EXTRA_FROM_ALARM_SERVICE, false)) {
            val payload = mapOf(
                "soundId" to (intent.getStringExtra(EXTRA_SOUND_ID) ?: "basic"),
                "alarmId" to intent.getIntExtra(EXTRA_ALARM_ID, -1),
            )
            nativeChannel?.invokeMethod(METHOD_ON_ALARM_LAUNCH_INTENT, payload)
            // ?? Intent ??? ? Dart ?? ?? ??
            intent.removeExtra(EXTRA_FROM_ALARM_SERVICE)
        }
    }

    companion object {
        private fun clearCorruptedScheduledNotificationCache(context: Context) {
            val candidatePrefs = listOf(
                "FlutterLocalNotificationsPlugin",
                "flutter_local_notifications_plugin",
                "scheduled_notifications",
                "com.dexterous.flutterlocalnotifications",
                "com.dexterous.flutterlocalnotifications.sharedpreferences",
            )
            for (name in candidatePrefs) {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        context.deleteSharedPreferences(name)
                    } else {
                        context.getSharedPreferences(name, Context.MODE_PRIVATE)
                            .edit()
                            .clear()
                            .apply()
                    }
                } catch (_: Throwable) {
                    // ?? ??? best-effort? ???? ?? ??? ?????.
                }
            }

            // Flutter SharedPreferences ?????? ? ?? ?? ?? ?? ?? ??.
            try {
                val flutterPrefs =
                    context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val toRemove = flutterPrefs.all.keys.filter { key ->
                    val lower = key.lowercase()
                    lower.contains("scheduled_notifications") ||
                        lower.contains("flutterlocalnotifications") ||
                        lower.contains("flutter_local_notifications") ||
                        lower.contains("dexterous")
                }
                if (toRemove.isNotEmpty()) {
                    val editor = flutterPrefs.edit()
                    toRemove.forEach { editor.remove(it) }
                    editor.apply()
                }
            } catch (_: Throwable) {
                // best-effort
            }

            // ?? ????? ??? ???? ???? ? ? ????? ?? ? ?? ?? ??? ??.
            try {
                val dataDir = context.applicationInfo.dataDir ?: return
                val prefsDir = File(dataDir, "shared_prefs")
                if (!prefsDir.exists() || !prefsDir.isDirectory) return
                prefsDir.listFiles()?.forEach { file ->
                    val name = file.name.lowercase()
                    val target = name.contains("flutterlocalnotifications") ||
                        name.contains("flutter_local_notifications") ||
                        name.contains("scheduled_notifications") ||
                        name == "com.dexterous.flutterlocalnotifications.xml"
                    if (!target) return@forEach
                    runCatching { file.delete() }
                }
            } catch (_: Throwable) {
                // best-effort
            }
        }

        private fun isRingerHushed(am: AudioManager): Boolean {
            return when (am.ringerMode) {
                AudioManager.RINGER_MODE_SILENT,
                AudioManager.RINGER_MODE_VIBRATE -> true
                else -> false
            }
        }

        /** ?????????????? ?????????(????? ??????????????? ???). */
        private fun hasHeadphoneLikeOutput(am: AudioManager): Boolean {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.getDevices(AudioManager.GET_DEVICES_OUTPUTS).any { d ->
                    when (d.type) {
                        AudioDeviceInfo.TYPE_WIRED_HEADSET,
                        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                        AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
                        AudioDeviceInfo.TYPE_USB_HEADSET,
                        AudioDeviceInfo.TYPE_BLE_HEADSET,
                        AudioDeviceInfo.TYPE_BLE_SPEAKER -> true
                        else -> false
                    }
                }
            } else {
                @Suppress("DEPRECATION")
                am.isWiredHeadsetOn || am.isBluetoothA2dpOn
            }
        }

        const val EXTRA_FROM_ALARM_SERVICE = "from_alarm_service"
        const val EXTRA_SOUND_ID = "flutter_sound_id"
        const val EXTRA_ALARM_ID = "alarm_id"
        const val METHOD_ON_ALARM_LAUNCH_INTENT = "onAlarmLaunchIntent"
        private const val NATIVE_CHANNEL = "com.bon.nihongona/alarm_native"
    }
}
