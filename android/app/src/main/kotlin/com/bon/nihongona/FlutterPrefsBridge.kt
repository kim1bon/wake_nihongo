package com.bon.nihongona

import android.content.Context

/**
 * Flutter [SharedPreferences]와 동일한 키·형식으로 알람 pending·재알림 세션을 읽고 씁니다.
 * Legacy 플러그인: int는 [SharedPreferences.putLong], bool은 putBoolean, string은 putString.
 */
object FlutterPrefsBridge {
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val PREFIX = "flutter."

    private const val KEY_ALARM_ID = "${PREFIX}pending_alarm_id"
    private const val KEY_SOUND_ID = "${PREFIX}pending_alarm_sound_id"
    private const val KEY_TRIGGERED_AT = "${PREFIX}pending_alarm_triggered_at_ms"
    private const val KEY_IS_RESCHEDULE = "${PREFIX}pending_alarm_is_reschedule"
    private const val KEY_SESSION = "${PREFIX}alarm_reschedule_session_v1"

    fun savePendingAlarm(
        ctx: Context,
        alarmId: Int,
        soundId: String,
        isReschedule: Boolean,
    ) {
        val prefs = ctx.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        prefs.edit()
            .putLong(KEY_ALARM_ID, alarmId.toLong())
            .putString(KEY_SOUND_ID, soundId)
            .putLong(KEY_TRIGGERED_AT, System.currentTimeMillis())
            .putBoolean(KEY_IS_RESCHEDULE, isReschedule)
            .apply()
    }

    fun clearPendingAlarm(ctx: Context) {
        val prefs = ctx.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        prefs.edit()
            .remove(KEY_ALARM_ID)
            .remove(KEY_SOUND_ID)
            .remove(KEY_TRIGGERED_AT)
            .remove(KEY_IS_RESCHEDULE)
            .apply()
    }

    fun hasPendingAlarm(ctx: Context): Boolean {
        val prefs = ctx.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        return prefs.contains(KEY_ALARM_ID) &&
            prefs.contains(KEY_SOUND_ID) &&
            prefs.contains(KEY_TRIGGERED_AT)
    }

    fun startRescheduleSession(ctx: Context, alarmId: Int, remainingUses: Int) {
        val json = """{"alarmId":$alarmId,"remaining":$remainingUses}"""
        ctx.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_SESSION, json)
            .apply()
    }

    fun readRemainingCycles(ctx: Context, alarmId: Int): Int? {
        val raw = ctx.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .getString(KEY_SESSION, null) ?: return null
        return try {
            val obj = org.json.JSONObject(raw)
            if (obj.getInt("alarmId") != alarmId) return null
            obj.getInt("remaining")
        } catch (_: Exception) {
            null
        }
    }

    fun writeRemainingCycles(ctx: Context, alarmId: Int, remaining: Int) {
        val json = """{"alarmId":$alarmId,"remaining":$remaining}"""
        ctx.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_SESSION, json)
            .apply()
    }

    fun clearRescheduleSession(ctx: Context, alarmId: Int) {
        val prefs = ctx.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_SESSION, null) ?: return
        try {
            val obj = org.json.JSONObject(raw)
            if (obj.getInt("alarmId") == alarmId) {
                prefs.edit().remove(KEY_SESSION).apply()
            }
        } catch (_: Exception) {
            prefs.edit().remove(KEY_SESSION).apply()
        }
    }

    fun clearAllForAlarm(ctx: Context, alarmId: Int) {
        clearPendingAlarm(ctx)
        clearRescheduleSession(ctx, alarmId)
    }
}
