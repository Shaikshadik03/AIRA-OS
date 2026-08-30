package com.airaos.aira_app

import android.content.Intent
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.EventChannel

class AiraNotificationListenerService : NotificationListenerService() {

    companion object {
        var eventSink: EventChannel.EventSink? = null
        val capturedNotifications = mutableListOf<Map<String, Any>>()
        private const val MAX_SAVED = 100

        fun getNotificationsList(): List<Map<String, Any>> {
            return capturedNotifications.toList()
        }

        fun clearNotifications() {
            capturedNotifications.clear()
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        try {
            val packageName = sbn.packageName ?: return
            
            // Ignore own notifications to prevent infinite loops
            if (packageName == applicationContext.packageName) return

            val extras = sbn.notification.extras
            val title = extras.getCharSequence("android.title")?.toString() ?: ""
            val text = extras.getCharSequence("android.text")?.toString() ?: ""
            val bigText = extras.getCharSequence("android.bigText")?.toString() ?: text
            val subText = extras.getCharSequence("android.subText")?.toString() ?: ""

            // Ignore empty notifications (media players, silent system badges)
            if (title.isEmpty() && text.isEmpty()) return

            val pm = applicationContext.packageManager
            val appName = try {
                val appInfo = pm.getApplicationInfo(packageName, 0)
                pm.getApplicationLabel(appInfo).toString()
            } catch (e: Exception) {
                packageName.split(".").lastOrNull()?.replaceFirstChar { it.uppercase() } ?: packageName
            }

            val category = when {
                packageName.contains("whatsapp") || packageName.contains("telegram") ||
                packageName.contains("messaging") || packageName.contains("signal") ||
                packageName.contains("discord") || packageName.contains("sms") -> "messaging"

                packageName.contains("instagram") || packageName.contains("twitter") ||
                packageName.contains("facebook") || packageName.contains("reddit") ||
                packageName.contains("linkedin") || packageName.contains("snapchat") -> "social"

                packageName.contains("gm") || packageName.contains("email") ||
                packageName.contains("outlook") || packageName.contains("slack") ||
                packageName.contains("teams") -> "email_work"

                packageName.contains("paytm") || packageName.contains("phonepe") ||
                packageName.contains("paisa") || packageName.contains("bank") ||
                packageName.contains("cred") -> "finance"

                packageName.contains("swiggy") || packageName.contains("zomato") ||
                packageName.contains("amazon") || packageName.contains("flipkart") ||
                packageName.contains("uber") || packageName.contains("ola") -> "delivery_transport"

                else -> "general"
            }

            val notifData = mapOf(
                "id" to sbn.id,
                "packageName" to packageName,
                "appName" to appName,
                "title" to title,
                "text" to (if (bigText.isNotEmpty()) bigText else text),
                "subText" to subText,
                "timestamp" to sbn.postTime,
                "category" to category
            )

            synchronized(capturedNotifications) {
                // Avoid exact duplicate spam within 2 seconds
                val isDuplicate = capturedNotifications.any {
                    it["packageName"] == packageName &&
                    it["title"] == title &&
                    it["text"] == notifData["text"] &&
                    (sbn.postTime - (it["timestamp"] as? Long ?: 0L)) < 2000
                }
                if (!isDuplicate) {
                    capturedNotifications.add(0, notifData)
                    if (capturedNotifications.size > MAX_SAVED) {
                        capturedNotifications.removeAt(capturedNotifications.size - 1)
                    }
                }
            }

            // Stream to Flutter if active
            eventSink?.success(notifData)
        } catch (_: Exception) {}
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // Optional: track dismissals
    }
}
