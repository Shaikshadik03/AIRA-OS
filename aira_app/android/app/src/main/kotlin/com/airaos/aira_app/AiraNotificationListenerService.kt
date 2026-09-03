package com.airaos.aira_app

import android.app.Notification
import android.app.PendingIntent
import android.app.RemoteInput
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.EventChannel

data class ReplyActionHolder(
    val replyKey: String,
    val pendingIntent: PendingIntent,
    val remoteInput: RemoteInput,
    val packageName: String,
    val sender: String,
    val text: String,
    val timestamp: Long
)

class AiraNotificationListenerService : NotificationListenerService() {

    companion object {
        var eventSink: EventChannel.EventSink? = null
        val capturedNotifications = mutableListOf<Map<String, Any>>()
        val replyHolders = mutableMapOf<String, ReplyActionHolder>()
        private const val MAX_SAVED = 100
        private const val MAX_REPLY_HOLDERS = 50

        fun getNotificationsList(): List<Map<String, Any>> {
            return capturedNotifications.toList()
        }

        fun clearNotifications() {
            capturedNotifications.clear()
            replyHolders.clear()
        }

        fun sendReply(context: Context, replyKey: String, replyText: String): Boolean {
            val holder = synchronized(replyHolders) { replyHolders[replyKey] } ?: return false
            return try {
                val intent = Intent()
                val bundle = Bundle()
                bundle.putCharSequence(holder.remoteInput.resultKey, replyText)
                RemoteInput.addResultsToIntent(arrayOf(holder.remoteInput), intent, bundle)
                holder.pendingIntent.send(context, 0, intent)
                true
            } catch (e: Exception) {
                false
            }
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

            // Inspect for RemoteInput Quick-Reply action (WhatsApp, Telegram, Signal, SMS)
            var canReply = false
            var replyKey = ""
            val actions = sbn.notification.actions
            if (actions != null) {
                for (action in actions) {
                    val remoteInputs = action.remoteInputs
                    if (remoteInputs != null && remoteInputs.isNotEmpty()) {
                        for (ri in remoteInputs) {
                            if (ri.allowFreeFormInput && action.actionIntent != null) {
                                val key = "${packageName}_${sbn.id}_${sbn.postTime}"
                                synchronized(replyHolders) {
                                    replyHolders[key] = ReplyActionHolder(
                                        replyKey = key,
                                        pendingIntent = action.actionIntent,
                                        remoteInput = ri,
                                        packageName = packageName,
                                        sender = title,
                                        text = if (bigText.isNotEmpty()) bigText else text,
                                        timestamp = sbn.postTime
                                    )
                                    if (replyHolders.size > MAX_REPLY_HOLDERS) {
                                        val oldestKey = replyHolders.keys.firstOrNull()
                                        if (oldestKey != null) replyHolders.remove(oldestKey)
                                    }
                                }
                                canReply = true
                                replyKey = key
                                break
                            }
                        }
                    }
                    if (canReply) break
                }
            }

            val notifData = mapOf(
                "id" to sbn.id,
                "packageName" to packageName,
                "appName" to appName,
                "title" to title,
                "text" to (if (bigText.isNotEmpty()) bigText else text),
                "subText" to subText,
                "timestamp" to sbn.postTime,
                "category" to category,
                "canReply" to canReply,
                "replyKey" to replyKey
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
