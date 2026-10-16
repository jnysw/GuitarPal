package com.guitarpal.guitar_pal

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import org.json.JSONObject
import java.util.Calendar

data class PracticeReminderSpec(
    val planId: String,
    val title: String,
    val sourceId: String,
    val startDay: Int,
    val endDay: Int,
    val weekdayMask: Int,
    val minuteOfDay: Int,
) {
    fun toJson(): String = JSONObject()
        .put("planId", planId)
        .put("title", title)
        .put("sourceId", sourceId)
        .put("startDay", startDay)
        .put("endDay", endDay)
        .put("weekdayMask", weekdayMask)
        .put("minuteOfDay", minuteOfDay)
        .toString()

    companion object {
        fun fromJson(value: String): PracticeReminderSpec? = try {
            fromValues(
                planId = JSONObject(value).getString("planId"),
                title = JSONObject(value).getString("title"),
                sourceId = JSONObject(value).getString("sourceId"),
                startDay = JSONObject(value).getInt("startDay"),
                endDay = JSONObject(value).getInt("endDay"),
                weekdayMask = JSONObject(value).getInt("weekdayMask"),
                minuteOfDay = JSONObject(value).getInt("minuteOfDay"),
            )
        } catch (_: Throwable) {
            null
        }

        fun fromMap(value: Map<*, *>): PracticeReminderSpec? = fromValues(
            planId = value["planId"] as? String,
            title = value["title"] as? String,
            sourceId = value["sourceId"] as? String,
            startDay = (value["startDay"] as? Number)?.toInt(),
            endDay = (value["endDay"] as? Number)?.toInt(),
            weekdayMask = (value["weekdayMask"] as? Number)?.toInt(),
            minuteOfDay = (value["minuteOfDay"] as? Number)?.toInt(),
        )

        private fun fromValues(
            planId: String?,
            title: String?,
            sourceId: String?,
            startDay: Int?,
            endDay: Int?,
            weekdayMask: Int?,
            minuteOfDay: Int?,
        ): PracticeReminderSpec? {
            if (planId.isNullOrBlank() || title.isNullOrBlank() || sourceId.isNullOrBlank()) {
                return null
            }
            if (startDay == null || endDay == null || endDay < startDay) return null
            if (weekdayMask == null || weekdayMask !in 1..0x7f) return null
            if (minuteOfDay == null || minuteOfDay !in 0 until 24 * 60) return null
            return PracticeReminderSpec(
                planId = planId,
                title = title,
                sourceId = sourceId,
                startDay = startDay,
                endDay = endDay,
                weekdayMask = weekdayMask,
                minuteOfDay = minuteOfDay,
            )
        }
    }
}

object PracticeReminderScheduler {
    private const val preferencesName = "practice_reminders"
    private const val preferencePrefix = "plan:"
    private const val notificationChannelId = "practice_plan_reminders"
    private const val alarmAction = "com.guitarpal.guitar_pal.PRACTICE_REMINDER"

    fun initialize(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                notificationChannelId,
                "练习计划提醒",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "在计划设定的练习日提醒开始练习"
            },
        )
    }

    fun synchronize(context: Context, values: List<Map<*, *>>) {
        val specs = values.mapNotNull(PracticeReminderSpec::fromMap)
            .associateBy(PracticeReminderSpec::planId)
        val previous = loadAll(context)
        val editor = preferences(context).edit()

        for ((planId, oldSpec) in previous) {
            cancel(context, oldSpec)
            if (!specs.containsKey(planId)) editor.remove(preferenceKey(planId))
        }
        for (spec in specs.values) {
            editor.putString(preferenceKey(spec.planId), spec.toJson())
        }
        editor.apply()
        specs.values.forEach { scheduleNext(context, it) }
    }

    fun cancelAll(context: Context) {
        loadAll(context).values.forEach { cancel(context, it) }
        preferences(context).edit().clear().apply()
    }

    fun rescheduleAll(context: Context) {
        initialize(context)
        loadAll(context).values.forEach { spec ->
            cancel(context, spec)
            scheduleNext(context, spec)
        }
    }

    fun deliver(context: Context, planId: String?) {
        if (planId.isNullOrBlank()) return
        val spec = load(context, planId) ?: return
        showNotification(context, spec)
        scheduleNext(context, spec, System.currentTimeMillis() + 60_000L)
    }

    private fun scheduleNext(
        context: Context,
        spec: PracticeReminderSpec,
        afterMillis: Long = System.currentTimeMillis(),
    ) {
        val triggerAt = nextTriggerMillis(spec, afterMillis) ?: return
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        manager.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAt,
            alarmPendingIntent(context, spec),
        )
    }

    internal fun nextTriggerMillis(
        spec: PracticeReminderSpec,
        afterMillis: Long,
    ): Long? {
        val cursor = Calendar.getInstance().apply {
            timeInMillis = afterMillis
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        repeat(36_600) {
            val dayKey = cursor.get(Calendar.YEAR) * 10_000 +
                (cursor.get(Calendar.MONTH) + 1) * 100 +
                cursor.get(Calendar.DAY_OF_MONTH)
            if (dayKey > spec.endDay) return null
            val weekday = ((cursor.get(Calendar.DAY_OF_WEEK) + 5) % 7) + 1
            val selected = (spec.weekdayMask and (1 shl (weekday - 1))) != 0
            if (dayKey >= spec.startDay && selected) {
                val candidate = (cursor.clone() as Calendar).apply {
                    set(Calendar.HOUR_OF_DAY, spec.minuteOfDay / 60)
                    set(Calendar.MINUTE, spec.minuteOfDay % 60)
                }
                if (candidate.timeInMillis > afterMillis) return candidate.timeInMillis
            }
            cursor.add(Calendar.DAY_OF_MONTH, 1)
        }
        return null
    }

    private fun showNotification(context: Context, spec: PracticeReminderSpec) {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        initialize(context)
        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply {
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("practicePlanId", spec.planId)
            }
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(
                context,
                spec.planId.hashCode(),
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, notificationChannelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val notification = builder
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle("练习时间到了")
            .setContentText(spec.title)
            .setStyle(Notification.BigTextStyle().bigText("现在开始「${spec.title}」的练习"))
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(spec.planId.hashCode(), notification)
    }

    private fun alarmPendingIntent(
        context: Context,
        spec: PracticeReminderSpec,
    ): PendingIntent {
        val intent = Intent(context, PracticeReminderReceiver::class.java).apply {
            action = alarmAction
            data = Uri.parse("guitarpal://practice-reminder/${Uri.encode(spec.planId)}")
            putExtra("planId", spec.planId)
        }
        return PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun cancel(context: Context, spec: PracticeReminderSpec) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        manager.cancel(alarmPendingIntent(context, spec))
    }

    private fun loadAll(context: Context): Map<String, PracticeReminderSpec> {
        return preferences(context).all.mapNotNull { (key, raw) ->
            if (!key.startsWith(preferencePrefix) || raw !is String) return@mapNotNull null
            val spec = PracticeReminderSpec.fromJson(raw) ?: return@mapNotNull null
            spec.planId to spec
        }.toMap()
    }

    private fun load(context: Context, planId: String): PracticeReminderSpec? {
        val value = preferences(context).getString(preferenceKey(planId), null) ?: return null
        return PracticeReminderSpec.fromJson(value)
    }

    private fun preferences(context: Context) = context.getSharedPreferences(
        preferencesName,
        Context.MODE_PRIVATE,
    )

    private fun preferenceKey(planId: String) = "$preferencePrefix$planId"
}
