package com.guitarpal.guitar_pal

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class PracticeReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        PracticeReminderScheduler.deliver(context, intent.getStringExtra("planId"))
    }
}

class PracticeReminderRescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        PracticeReminderScheduler.rescheduleAll(context)
    }
}
