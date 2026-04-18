package com.example.wake_nihongo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlarmStopReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        AlarmRingForegroundService.stop(context.applicationContext)
    }
}
