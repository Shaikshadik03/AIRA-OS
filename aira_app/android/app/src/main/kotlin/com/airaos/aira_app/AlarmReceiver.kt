package com.airaos.aira_app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import java.util.Calendar

class AlarmReceiver : BroadcastReceiver() {

    companion object {
        const val CHANNEL_ID = "aira_daily_alerts"
        const val EXTRA_TITLE = "notification_title"
        const val EXTRA_BODY = "notification_body"
        const val EXTRA_NOTIFICATION_ID = "notification_id"

        fun scheduleDaily(
            context: Context,
            notificationId: Int,
            title: String,
            body: String,
            hour: Int,
            minute: Int
        ) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            val intent = Intent(context, AlarmReceiver::class.java).apply {
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
                putExtra(EXTRA_NOTIFICATION_ID, notificationId)
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                notificationId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val calendar = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                // If time already passed today, schedule for tomorrow
                if (timeInMillis <= System.currentTimeMillis()) {
                    add(Calendar.DAY_OF_YEAR, 1)
                }
            }

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    if (alarmManager.canScheduleExactAlarms()) {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            calendar.timeInMillis,
                            pendingIntent
                        )
                    } else {
                        // Use inexact as fallback
                        alarmManager.setAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            calendar.timeInMillis,
                            pendingIntent
                        )
                    }
                } else {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                }
            } catch (e: SecurityException) {
                // Fallback inexact alarm
                alarmManager.set(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
            }
        }

        fun scheduleOneTime(
            context: Context,
            notificationId: Int,
            title: String,
            body: String,
            timestampMs: Long
        ) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
                putExtra(EXTRA_NOTIFICATION_ID, notificationId)
                putExtra("is_one_time", true)
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                notificationId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    if (alarmManager.canScheduleExactAlarms()) {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            timestampMs,
                            pendingIntent
                        )
                    } else {
                        alarmManager.setAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            timestampMs,
                            pendingIntent
                        )
                    }
                } else {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        timestampMs,
                        pendingIntent
                    )
                }
            } catch (e: Exception) {
                alarmManager.set(
                    AlarmManager.RTC_WAKEUP,
                    timestampMs,
                    pendingIntent
                )
            }
        }

        fun cancel(context: Context, notificationId: Int) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, AlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                notificationId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra(EXTRA_TITLE) ?: "AIRA"
        val body = intent.getStringExtra(EXTRA_BODY) ?: ""
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0)

        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.LOCKED_BOOT_COMPLETED"
        ) {
            // Reschedule all daily alarms after phone restart
            rescheduleAllAlarms(context)
            return
        }

        // Show the notification
        showNotification(context, notificationId, title, body)

        // Only reschedule if it's a daily recurring alarm (not one-time)
        val isOneTime = intent.getBooleanExtra("is_one_time", false)
        if (!isOneTime) {
            val currentHour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
            val currentMin = Calendar.getInstance().get(Calendar.MINUTE)
            scheduleDaily(context, notificationId, title, body, currentHour, currentMin)
        }
    }

    private fun showNotification(context: Context, id: Int, title: String, body: String) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Create channel
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "AIRA Daily Briefings",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "AIRA morning briefing and evening check-in"
                enableVibration(true)
                enableLights(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        // Tap notification → open AIRA app
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(
            context,
            id,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setVibrate(longArrayOf(0, 300, 200, 300))
            .build()

        notificationManager.notify(id, notification)
    }

    private fun rescheduleAllAlarms(context: Context) {
        // 7 AM Morning Briefing
        scheduleDaily(
            context, 700,
            "☀️ AIRA Morning Briefing",
            "Good morning! Open AIRA for your daily schedule, tasks, and agenda.",
            7, 0
        )
        // 10 PM Evening Check-in
        scheduleDaily(
            context, 2200,
            "🌙 AIRA Evening Check-in",
            "Good evening! Time to review completed tasks and plan for tomorrow.",
            22, 0
        )
    }
}
