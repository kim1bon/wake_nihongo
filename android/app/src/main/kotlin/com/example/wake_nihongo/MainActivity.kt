package com.example.wake_nihongo

import android.content.Intent
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
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    companion object {
        const val EXTRA_FROM_ALARM_SERVICE = "from_alarm_service"
        const val EXTRA_SOUND_ID = "flutter_sound_id"
        const val EXTRA_ALARM_ID = "alarm_id"
        private const val NATIVE_CHANNEL = "com.example.wake_nihongo/alarm_native"
    }
}
