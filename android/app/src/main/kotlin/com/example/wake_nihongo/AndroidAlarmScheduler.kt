package com.example.wake_nihongo

import android.app.AlarmManager
import android.app.AlarmManager.AlarmClockInfo
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import org.json.JSONArray
import java.time.DayOfWeek
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * Exact alarms + SharedPreferences backup for BOOT_COMPLETED.
 */
object AndroidAlarmScheduler {
    private const val TAG = "AndroidAlarmScheduler"
    private const val PREFS = "wake_nihongo_native_alarm"
    private const val KEY_JSON = "alarms_json"
    private const val KEY_KEYS = "scheduled_keys"

    fun syncFromJson(context: Context, json: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        cancelAllTracked(context, prefs)
        prefs.edit().putString(KEY_JSON, json).apply()
        if (json.isBlank()) return

        val newKeys = mutableSetOf<String>()
        val arr = JSONArray(json)
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            if (!o.optBoolean("enabled", true)) continue
            val id = o.getInt("id")
            val hour = o.getInt("hour")
            val minute = o.getInt("minute")
            val raw = o.optString("androidRaw", "alram_01")
            val wds = o.getJSONArray("weekdays")
            for (j in 0 until wds.length()) {
                val wd = wds.getInt(j)
                val whenMs = nextOccurrenceMillis(wd, hour, minute)
                scheduleAlarmAtMillis(context, id, wd, hour, minute, raw, whenMs)
                newKeys.add(key(id, wd))
            }
        }
        prefs.edit().putStringSet(KEY_KEYS, newKeys).apply()
        Log.d(TAG, "synced ${newKeys.size} native alarm slots")
    }

    fun rescheduleAfterBoot(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val json = prefs.getString(KEY_JSON, null) ?: return
        if (json.isBlank()) return
        val newKeys = mutableSetOf<String>()
        val arr = JSONArray(json)
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            if (!o.optBoolean("enabled", true)) continue
            val id = o.getInt("id")
            val hour = o.getInt("hour")
            val minute = o.getInt("minute")
            val raw = o.optString("androidRaw", "alram_01")
            val wds = o.getJSONArray("weekdays")
            for (j in 0 until wds.length()) {
                val wd = wds.getInt(j)
                val whenMs = nextOccurrenceMillis(wd, hour, minute)
                scheduleAlarmAtMillis(context, id, wd, hour, minute, raw, whenMs)
                newKeys.add(key(id, wd))
            }
        }
        prefs.edit().putStringSet(KEY_KEYS, newKeys).apply()
        Log.d(TAG, "rescheduled after boot: ${newKeys.size} slots")
    }

    /** After an alarm fires, schedule the same weekday/time one week later. */
    fun scheduleNextWeekSameSlot(
        context: Context,
        alarmId: Int,
        weekday: Int,
        hour: Int,
        minute: Int,
        rawSound: String,
    ) {
        val whenMs = nextWeekSameSlotMillis(weekday, hour, minute)
        scheduleAlarmAtMillis(context, alarmId, weekday, hour, minute, rawSound, whenMs)
    }

    private fun cancelAllTracked(context: Context, prefs: android.content.SharedPreferences) {
        val oldJson = prefs.getString(KEY_JSON, null).orEmpty()
        val arr = if (oldJson.isNotBlank()) JSONArray(oldJson) else JSONArray()
        val old = prefs.getStringSet(KEY_KEYS, emptySet()) ?: emptySet()
        for (k in old) {
            val parts = k.split("-")
            if (parts.size != 2) continue
            val alarmId = parts[0].toInt()
            val wd = parts[1].toInt()
            val meta = findAlarmMeta(arr, alarmId) ?: continue
            cancelOneExact(context, alarmId, wd, meta.first, meta.second, meta.third)
        }
        prefs.edit().remove(KEY_KEYS).apply()
    }

    private fun findAlarmMeta(arr: JSONArray, alarmId: Int): Triple<Int, Int, String>? {
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            if (o.getInt("id") == alarmId) {
                return Triple(
                    o.getInt("hour"),
                    o.getInt("minute"),
                    o.optString("androidRaw", "alram_01"),
                )
            }
        }
        return null
    }

    private fun cancelOneExact(
        context: Context,
        alarmId: Int,
        weekday: Int,
        hour: Int,
        minute: Int,
        rawSound: String,
    ) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = buildAlarmPendingIntent(context, alarmId, weekday, hour, minute, rawSound)
        am.cancel(pi)
        pi.cancel()
    }

    fun scheduleAlarmAtMillis(
        context: Context,
        alarmId: Int,
        weekday: Int,
        hour: Int,
        minute: Int,
        rawSound: String,
        triggerAtMillis: Long,
    ) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = buildAlarmPendingIntent(context, alarmId, weekday, hour, minute, rawSound)
        val show = Intent(context, MainActivity::class.java).let { i ->
            PendingIntent.getActivity(context, 0, i, pendingFlags())
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            am.setAlarmClock(AlarmClockInfo(triggerAtMillis, show), pi)
        } else {
            @Suppress("DEPRECATION")
            am.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
        }
    }

    private fun key(alarmId: Int, weekday: Int) = "$alarmId-$weekday"

    private fun buildAlarmPendingIntent(
        context: Context,
        alarmId: Int,
        weekday: Int,
        hour: Int,
        minute: Int,
        rawSound: String,
    ): PendingIntent {
        val intent = Intent(context, AlarmTriggerReceiver::class.java).apply {
            action = AlarmTriggerReceiver.ACTION_ALARM_FIRE
            putExtra(AlarmTriggerReceiver.EXTRA_ALARM_ID, alarmId)
            putExtra(AlarmTriggerReceiver.EXTRA_WEEKDAY, weekday)
            putExtra(AlarmTriggerReceiver.EXTRA_HOUR, hour)
            putExtra(AlarmTriggerReceiver.EXTRA_MINUTE, minute)
            putExtra(AlarmTriggerReceiver.EXTRA_RAW, rawSound)
        }
        val requestCode = alarmId * 10 + weekday
        return PendingIntent.getBroadcast(context, requestCode, intent, pendingFlags())
    }

    private fun pendingFlags(): Int {
        var f = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            f = f or PendingIntent.FLAG_IMMUTABLE
        }
        return f
    }

    private fun nextOccurrenceMillis(weekday: Int, hour: Int, minute: Int): Long {
        val zone = ZoneId.systemDefault()
        val targetDow = DayOfWeek.of(weekday)
        var candidate = ZonedDateTime.now(zone)
            .withHour(hour)
            .withMinute(minute)
            .withSecond(0)
            .withNano(0)
        while (candidate.dayOfWeek != targetDow) {
            candidate = candidate.plusDays(1)
        }
        val now = ZonedDateTime.now(zone)
        while (!candidate.isAfter(now)) {
            candidate = candidate.plusWeeks(1)
        }
        return candidate.toInstant().toEpochMilli()
    }

    private fun nextWeekSameSlotMillis(weekday: Int, hour: Int, minute: Int): Long {
        val zone = ZoneId.systemDefault()
        val now = ZonedDateTime.now(zone)
        var t = now.plusWeeks(1)
            .withHour(hour)
            .withMinute(minute)
            .withSecond(0)
            .withNano(0)
        while (t.dayOfWeek != DayOfWeek.of(weekday)) {
            t = t.plusDays(1)
        }
        if (!t.isAfter(now)) {
            t = t.plusWeeks(1)
        }
        return t.toInstant().toEpochMilli()
    }
}
