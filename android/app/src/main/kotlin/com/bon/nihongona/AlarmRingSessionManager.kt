package com.bon.nihongona

import android.content.Context
import android.util.Log

/**
 * 알람 울림 주기: [RING_DURATION_MS] 울림 → (미해제 시) [RESCHEDULE_DELAY_MS] 대기 → 재울림, 최대 [MAX_CYCLES]회.
 * TODO(테스트): 현재 1분/30초. 배포 전 5분/5분으로 되돌리세요.
 */
object AlarmRingSessionManager {
    private const val TAG = "AlarmRingSession"

    const val RING_DURATION_MS = 1L * 60L * 1000L
    const val RESCHEDULE_DELAY_MS = 30L * 1000L
    const val MAX_CYCLES = 5

    /** AndroidAlarmScheduler 재알림 슬롯(주간 1–7·1회 0과 겹치지 않음). */
    const val RESCHEDULE_WEEKDAY = 8

    fun onWeeklyAlarmFired(ctx: Context, alarmId: Int, soundId: String) {
        if (alarmId < 0) return
        FlutterPrefsBridge.startRescheduleSession(ctx, alarmId, MAX_CYCLES)
        FlutterPrefsBridge.savePendingAlarm(ctx, alarmId, soundId, isReschedule = false)
        Log.d(TAG, "weekly fire id=$alarmId cycles=$MAX_CYCLES")
    }

    fun onRescheduleAlarmFired(ctx: Context, alarmId: Int, soundId: String) {
        if (alarmId < 0) return
        FlutterPrefsBridge.savePendingAlarm(ctx, alarmId, soundId, isReschedule = true)
        Log.d(TAG, "reschedule fire id=$alarmId remaining=${FlutterPrefsBridge.readRemainingCycles(ctx, alarmId)}")
    }

    /** 울림 구간 종료 — 퀴즈 미해제 시 다음 주기 예약 또는 자동 종료. */
    fun onRingCycleEnded(ctx: Context, alarmId: Int, soundId: String, raw: String) {
        if (alarmId < 0) {
            FlutterPrefsBridge.clearPendingAlarm(ctx)
            return
        }
        val current = FlutterPrefsBridge.readRemainingCycles(ctx, alarmId) ?: MAX_CYCLES
        val next = (current - 1).coerceAtLeast(0)
        FlutterPrefsBridge.writeRemainingCycles(ctx, alarmId, next)
        Log.d(TAG, "cycle ended id=$alarmId remaining=$next")

        if (next > 0) {
            AndroidAlarmScheduler.scheduleRescheduleRing(
                ctx,
                alarmId,
                raw,
                RESCHEDULE_DELAY_MS,
            )
        } else {
            onAutoDismiss(ctx, alarmId)
        }
    }

    /** 5회 모두 소진 — pending·세션·재예약 정리. */
    fun onAutoDismiss(ctx: Context, alarmId: Int) {
        Log.d(TAG, "auto dismiss id=$alarmId")
        AndroidAlarmScheduler.cancelRescheduleRing(ctx, alarmId)
        FlutterPrefsBridge.clearAllForAlarm(ctx, alarmId)
    }

    /** 퀴즈 성공 후 Flutter에서 호출. */
    fun onQuizDismissed(ctx: Context, alarmId: Int) {
        if (alarmId < 0) return
        Log.d(TAG, "quiz dismissed id=$alarmId")
        AndroidAlarmScheduler.cancelRescheduleRing(ctx, alarmId)
        FlutterPrefsBridge.clearAllForAlarm(ctx, alarmId)
    }
}
