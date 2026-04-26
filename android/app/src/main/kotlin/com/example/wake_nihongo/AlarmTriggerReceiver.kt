package com.example.wake_nihongo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AlarmTriggerReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_ALARM_FIRE) return
        val alarmId = intent.getIntExtra(EXTRA_ALARM_ID, -1)
        val weekday = intent.getIntExtra(EXTRA_WEEKDAY, 1)
        val hour = intent.getIntExtra(EXTRA_HOUR, 0)
        val minute = intent.getIntExtra(EXTRA_MINUTE, 0)
        val raw = intent.getStringExtra(EXTRA_RAW) ?: "alram_01"
        val soundId = rawToFlutterSoundId(raw)

        Log.d(TAG, "alarm fire id=$alarmId wd=$weekday raw=$raw")

        AlarmRingForegroundService.startRinging(
            context.applicationContext,
            alarmId,
            soundId,
            raw,
        )
        val openQuizIntent = Intent(context.applicationContext, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(MainActivity.EXTRA_FROM_ALARM_SERVICE, true)
            putExtra(MainActivity.EXTRA_SOUND_ID, soundId)
            putExtra(MainActivity.EXTRA_ALARM_ID, alarmId)
        }
        context.applicationContext.startActivity(openQuizIntent)

        AndroidAlarmScheduler.scheduleNextWeekSameSlot(
            context.applicationContext,
            alarmId,
            weekday,
            hour,
            minute,
            raw,
        )
    }

    private fun rawToFlutterSoundId(raw: String): String = when (raw) {
        "alram_01" -> "Alram_01"
        "alram_02" -> "Alram_02"
        "alram_03" -> "Alram_03"
        "alram_04" -> "Alram_04"
        else -> "Alram_01"
    }

    companion object {
        const val ACTION_ALARM_FIRE = "com.example.wake_nihongo.ACTION_ALARM_FIRE"
        const val EXTRA_ALARM_ID = "alarm_id"
        const val EXTRA_WEEKDAY = "weekday"
        const val EXTRA_HOUR = "hour"
        const val EXTRA_MINUTE = "minute"
        const val EXTRA_RAW = "raw_sound"
        private const val TAG = "AlarmTriggerReceiver"
    }
}
