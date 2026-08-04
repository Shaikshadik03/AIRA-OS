package com.airaos.aira_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast

class OverlayService : Service() {
    private var windowManager: WindowManager? = null
    private var siriCapsuleView: LinearLayout? = null
    private var statusTextView: TextView? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startForegroundService()
        showSiriStyleOverlay()
    }

    private fun startForegroundService() {
        val channelId = "aira_overlay_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "AIRA Everywhere Assistant",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }

        val notification: Notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
                .setContentTitle("AIRA Voice Assistant Active")
                .setContentText("Say 'Hey AIRA' anytime from any app screen")
                .setSmallIcon(android.R.drawable.ic_btn_speak_now)
                .build()
        } else {
            Notification.Builder(this)
                .setContentTitle("AIRA Voice Assistant Active")
                .setContentText("Say 'Hey AIRA' anytime from any app screen")
                .setSmallIcon(android.R.drawable.ic_btn_speak_now)
                .build()
        }

        startForeground(99, notification)
    }

    private fun showSiriStyleOverlay() {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        // Glassmorphism Capsule Layout (Siri / Bixby style)
        siriCapsuleView = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(36, 20, 48, 20)

            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 60f
                setColor(Color.parseColor("#EE0F172A")) // Dark translucent slate
                setStroke(3, Color.parseColor("#00E5FF")) // Electric Cyan border
            }
        }

        // Glowing Orb Icon
        val micIcon = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_btn_speak_now)
            setColorFilter(Color.parseColor("#00E5FF"))
            setPadding(0, 0, 16, 0)
        }

        // Text status
        statusTextView = TextView(this).apply {
            text = "🎙️ AIRA Assistant — Say \"Hey AIRA...\""
            setTextColor(Color.WHITE)
            textSize = 14f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        }

        siriCapsuleView?.addView(micIcon)
        siriCapsuleView?.addView(statusTextView)

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            y = 120
        }

        // Tap to open full AIRA app
        siriCapsuleView?.setOnClickListener {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(launchIntent)
        }

        try {
            windowManager?.addView(siriCapsuleView, params)
        } catch (e: Exception) {
            Toast.makeText(this, "Enable 'Display Over Other Apps' permission for AIRA Siri overlay", Toast.LENGTH_LONG).show()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (siriCapsuleView != null && windowManager != null) {
            windowManager?.removeView(siriCapsuleView)
        }
    }
}
