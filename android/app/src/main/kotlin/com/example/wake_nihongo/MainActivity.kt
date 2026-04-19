package com.example.wake_nihongo

import android.content.Context
import android.content.Intent
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_CHANNEL).setMethodCallHandler { call, result ->
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
                            "soundId" to (i.getStringExtra(EXTRA_SOUND_ID) ?: "Alram_01"),
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
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    companion object {
        private fun isRingerHushed(am: AudioManager): Boolean {
            return when (am.ringerMode) {
                AudioManager.RINGER_MODE_SILENT,
                AudioManager.RINGER_MODE_VIBRATE -> true
                else -> false
            }
        }

        /** 유선·블루투스 이어폰 등 (내장 스피커만이 아닌 출력). */
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
        private const val NATIVE_CHANNEL = "com.example.wake_nihongo/alarm_native"
    }
}
