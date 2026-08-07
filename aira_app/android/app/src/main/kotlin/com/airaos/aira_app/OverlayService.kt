package com.airaos.aira_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

class OverlayService : Service() {
    private var windowManager: WindowManager? = null
    private var siriCapsuleView: LinearLayout? = null
    private var statusTextView: TextView? = null

    // Wake word detection
    private var speechRecognizer: SpeechRecognizer? = null
    @Volatile private var isWakeWordActive = false
    private val handler = Handler(Looper.getMainLooper())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startForegroundService()
        showSiriStyleOverlay()
        startWakeWordDetection()
    }

    private fun startForegroundService() {
        val channelId = "aira_overlay_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "AIRA Everywhere Assistant",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "AIRA voice assistant listening for 'Hey AIRA'"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }

        // Tap notification → open AIRA app
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification: Notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
                .setContentTitle("AIRA Voice Assistant Active")
                .setContentText("Say 'Hey AIRA' anytime from any screen")
                .setSmallIcon(android.R.drawable.ic_btn_speak_now)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("AIRA Voice Assistant Active")
                .setContentText("Say 'Hey AIRA' anytime from any screen")
                .setSmallIcon(android.R.drawable.ic_btn_speak_now)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .build()
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Android 14+ requires specifying foreground service type
            startForeground(99, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        } else {
            startForeground(99, notification)
        }
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
            text = "\uD83C\uDF10 AIRA \u2022 Say \"Hey AIRA...\""
            setTextColor(Color.WHITE)
            textSize = 14f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            maxLines = 1
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
            // Permission not granted
        }
    }

    // ── Real "Hey AIRA" Wake Word Detection ──
    // Uses Android's built-in SpeechRecognizer in a continuous loop.
    // Runs inside the foreground service so it works even when app is in background.

    private fun startWakeWordDetection() {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            updateStatus("STT unavailable on device")
            return
        }
        isWakeWordActive = true
        startListeningLoop()
    }

    private fun startListeningLoop() {
        if (!isWakeWordActive) return

        // Destroy previous instance
        speechRecognizer?.destroy()
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)

        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                updateStatus("\uD83C\uDF10 AIRA \u2022 Listening...")
            }
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}

            override fun onError(error: Int) {
                // Common errors:
                // 6 = ERROR_SPEECH_TIMEOUT (no speech detected)
                // 7 = ERROR_NO_MATCH
                // 8 = ERROR_RECOGNIZER_BUSY
                // Just restart the loop after a short delay
                val delay = when (error) {
                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> 2000L
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> 500L
                    SpeechRecognizer.ERROR_NO_MATCH -> 500L
                    else -> 1000L
                }
                updateStatus("\uD83C\uDF10 AIRA \u2022 Say \"Hey AIRA...\"")
                handler.postDelayed({
                    if (isWakeWordActive) startListeningLoop()
                }, delay)
            }

            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val recognized = matches?.firstOrNull()?.lowercase() ?: ""

                if (isWakeWord(recognized)) {
                    onWakeWordDetected(recognized)
                }

                // Continue listening loop
                handler.postDelayed({
                    if (isWakeWordActive) startListeningLoop()
                }, 300)
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val recognized = matches?.firstOrNull()?.lowercase() ?: ""
                if (recognized.isNotEmpty()) {
                    updateStatus("\uD83C\uDF99\uFE0F $recognized")
                }
                if (isWakeWord(recognized)) {
                    onWakeWordDetected(recognized)
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 500L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2000L)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
        }

        try {
            speechRecognizer?.startListening(intent)
        } catch (e: Exception) {
            // Retry after delay
            handler.postDelayed({
                if (isWakeWordActive) startListeningLoop()
            }, 2000)
        }
    }

    private fun isWakeWord(text: String): Boolean {
        val lower = text.lowercase().trim()
        return lower.contains("aira") ||
            (lower.contains("ira") && (lower.contains("hey") || lower.contains("hi"))) ||
            lower.contains("era") && lower.contains("hey") ||
            lower.startsWith("ok aira") ||
            lower.startsWith("hello aira")
    }

    private fun onWakeWordDetected(recognized: String) {
        updateStatus("\u26A1 AIRA Activated!")

        // Flash the capsule border green briefly
        siriCapsuleView?.post {
            (siriCapsuleView?.background as? GradientDrawable)?.setStroke(4, Color.parseColor("#00FF88"))
            handler.postDelayed({
                (siriCapsuleView?.background as? GradientDrawable)?.setStroke(3, Color.parseColor("#00E5FF"))
            }, 1500)
        }

        // Open AIRA app
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        launchIntent?.putExtra("wake_word_command", recognized)
        try {
            startActivity(launchIntent)
        } catch (_: Exception) {}
    }

    private fun updateStatus(text: String) {
        handler.post {
            statusTextView?.text = text
        }
    }

    private fun stopWakeWordDetection() {
        isWakeWordActive = false
        handler.removeCallbacksAndMessages(null)
        try {
            speechRecognizer?.stopListening()
            speechRecognizer?.destroy()
        } catch (_: Exception) {}
        speechRecognizer = null
    }

    override fun onDestroy() {
        super.onDestroy()
        stopWakeWordDetection()
        if (siriCapsuleView != null && windowManager != null) {
            try {
                windowManager?.removeView(siriCapsuleView)
            } catch (_: Exception) {}
        }
    }
}
