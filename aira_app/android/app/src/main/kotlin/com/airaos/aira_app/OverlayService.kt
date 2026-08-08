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
import android.speech.tts.TextToSpeech
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import java.util.Locale

/**
 * AIRA Floating Overlay Service — Senior Architecture
 *
 * Shows a Siri/Bixby-style floating capsule on screen.
 * TWO MODES:
 *   1. TAP MODE (default, reliable): Tap capsule → listen for command → open AIRA
 *   2. HANDS-FREE MODE (optional): Continuous SpeechRecognizer loop for "Hey AIRA"
 *
 * SpeechRecognizer runs on main thread (required by Android).
 * Foreground service with MICROPHONE type for Android 14+.
 */
class OverlayService : Service(), TextToSpeech.OnInitListener {
    private var windowManager: WindowManager? = null
    private var capsuleView: LinearLayout? = null
    private var statusText: TextView? = null
    private var micIcon: ImageView? = null

    private var speechRecognizer: SpeechRecognizer? = null
    private var tts: TextToSpeech? = null
    private var isTtsReady = false
    @Volatile private var isListening = false
    @Volatile private var isHandsFreeMode = false
    private val handler = Handler(Looper.getMainLooper())

    // Drag support
    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    private var isDragging = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        tts = TextToSpeech(this, this)
        setupForegroundNotification()
        createOverlayCapsule()
        isHandsFreeMode = true
        startHandsFreeListening()
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            tts?.language = Locale.US
            isTtsReady = true
        }
    }

    private fun speakResponse(text: String) {
        if (isTtsReady && text.isNotEmpty()) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "AIRA_OVERLAY_TTS")
            } else {
                @Suppress("DEPRECATION")
                tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null)
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        isHandsFreeMode = true
        startHandsFreeListening()
        return START_STICKY
    }

    // ─── Foreground Notification ───

    private fun setupForegroundNotification() {
        val channelId = "aira_overlay_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "AIRA Assistant",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "AIRA floating assistant"
                setShowBadge(false)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }.apply {
            setContentTitle("AIRA Active")
            setContentText("Tap the floating button to talk to AIRA")
            setSmallIcon(android.R.drawable.ic_btn_speak_now)
            setContentIntent(pendingIntent)
            setOngoing(true)
        }.build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(99, notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        } else {
            startForeground(99, notification)
        }
    }

    // ─── Overlay Capsule UI ───

    private fun createOverlayCapsule() {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        capsuleView = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(36, 20, 48, 20)
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 60f
                setColor(Color.parseColor("#EE0F172A"))
                setStroke(3, Color.parseColor("#00E5FF"))
            }
            elevation = 12f
        }

        micIcon = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_btn_speak_now)
            setColorFilter(Color.parseColor("#00E5FF"))
            val size = (28 * resources.displayMetrics.density).toInt()
            layoutParams = LinearLayout.LayoutParams(size, size).apply {
                rightMargin = (12 * resources.displayMetrics.density).toInt()
            }
        }

        statusText = TextView(this).apply {
            text = "AIRA • Tap to speak"
            setTextColor(Color.WHITE)
            textSize = 14f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            maxLines = 1
        }

        capsuleView?.addView(micIcon)
        capsuleView?.addView(statusText)

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
            y = 140
        }

        // Touch handler: drag + tap
        capsuleView?.setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isDragging = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - initialTouchX
                    val dy = event.rawY - initialTouchY
                    if (Math.abs(dx) > 10 || Math.abs(dy) > 10) isDragging = true
                    if (isDragging) {
                        params.x = initialX + dx.toInt()
                        params.y = initialY - dy.toInt()
                        try { windowManager?.updateViewLayout(capsuleView, params) } catch (_: Exception) {}
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!isDragging) {
                        // TAP → Start listening
                        onCapsuleTapped()
                    }
                    true
                }
                else -> false
            }
        }

        try {
            windowManager?.addView(capsuleView, params)
        } catch (e: Exception) {
            // SYSTEM_ALERT_WINDOW permission not granted
        }
    }

    // ─── Tap-to-Speak (Primary Mode) ───

    private fun onCapsuleTapped() {
        if (isListening) {
            // Already listening — stop
            stopListening()
            updateUI("AIRA • Tap to speak", "#00E5FF", false)
            return
        }
        startOneShot()
    }

    private fun startOneShot() {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            updateUI("No speech engine!", "#FF4444", false)
            handler.postDelayed({
                updateUI("AIRA • Tap to speak", "#00E5FF", false)
            }, 2000)
            return
        }

        isListening = true
        updateUI("Listening...", "#00FF88", true)

        // Pulse animation on the border
        capsuleView?.post {
            (capsuleView?.background as? GradientDrawable)?.setStroke(4, Color.parseColor("#00FF88"))
        }

        speechRecognizer?.destroy()
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(applicationContext)
        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                updateUI("Speak now...", "#00FF88", true)
            }
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {
                updateUI("Processing...", "#FFD700", true)
            }

            override fun onError(error: Int) {
                isListening = false
                val msg = when (error) {
                    SpeechRecognizer.ERROR_NO_MATCH -> "Didn't catch that"
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech heard"
                    SpeechRecognizer.ERROR_AUDIO -> "Mic error"
                    SpeechRecognizer.ERROR_NETWORK -> "Network error"
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Mic permission needed"
                    else -> "Error ($error)"
                }
                updateUI(msg, "#FF4444", false)
                handler.postDelayed({
                    if (!isListening) updateUI("AIRA • Tap to speak", "#00E5FF", false)
                }, 2000)
            }

            override fun onResults(results: Bundle?) {
                isListening = false
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val heard = matches?.firstOrNull() ?: ""
                if (heard.isNotEmpty()) {
                    updateUI("\"$heard\"", "#00FF88", false)
                    openAiraWithCommand(heard)
                } else {
                    updateUI("Didn't catch that", "#FF4444", false)
                }
                handler.postDelayed({
                    if (!isListening) updateUI("AIRA • Tap to speak", "#00E5FF", false)
                }, 3000)
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val partial = matches?.firstOrNull() ?: ""
                if (partial.isNotEmpty()) {
                    updateUI("\"$partial\"", "#00FF88", true)
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
        }

        try {
            speechRecognizer?.startListening(intent)
        } catch (e: Exception) {
            isListening = false
            updateUI("Speech engine error", "#FF4444", false)
        }
    }

    // ─── Hands-Free Mode (Optional — "Hey AIRA" loop) ───

    private fun startHandsFreeListening() {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            updateUI("STT unavailable", "#FF4444", false)
            return
        }
        isHandsFreeMode = true
        loopListen()
    }

    private fun loopListen() {
        if (!isHandsFreeMode) return
        isListening = true

        speechRecognizer?.destroy()
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(applicationContext)
        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                updateUI("AIRA • Say 'Hey AIRA'", "#00E5FF", true)
            }
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}

            override fun onError(error: Int) {
                isListening = false
                val delay = if (error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY) 2000L else 800L
                handler.postDelayed({ if (isHandsFreeMode) loopListen() }, delay)
            }

            override fun onResults(results: Bundle?) {
                isListening = false
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val heard = matches?.firstOrNull()?.lowercase() ?: ""
                if (isWakeWord(heard)) {
                    updateUI("⚡ AIRA Activated!", "#00FF88", false)
                    openAiraWithCommand(heard)
                }
                handler.postDelayed({ if (isHandsFreeMode) loopListen() }, 500)
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val heard = matches?.firstOrNull()?.lowercase() ?: ""
                if (isWakeWord(heard)) {
                    updateUI("⚡ AIRA Activated!", "#00FF88", false)
                    openAiraWithCommand(heard)
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2500L)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
        }
        try {
            speechRecognizer?.startListening(intent)
        } catch (e: Exception) {
            handler.postDelayed({ if (isHandsFreeMode) loopListen() }, 2000)
        }
    }

    private fun isWakeWord(text: String): Boolean {
        val t = text.lowercase().trim()
        return t.contains("aira") || t.contains("ara") ||
            (t.contains("ira") && (t.contains("hey") || t.contains("hi") || t.contains("hello") || t.contains("ok"))) ||
            t.contains("hey siri") || t.contains("hey google")
    }

    // ─── Helpers ───

    private fun openAiraWithCommand(command: String) {
        val lower = command.lowercase().trim()
        
        // 1. Direct Flashlight Voice Command
        if (lower.contains("flashlight") || lower.contains("torch")) {
            val turnOn = !lower.contains("off")
            toggleFlashlightNative(turnOn)
            val responseText = if (turnOn) "Flashlight turned on" else "Flashlight turned off"
            updateUI(responseText, "#00FF88", false)
            speakResponse(responseText)
            handler.postDelayed({ if (isHandsFreeMode) loopListen() }, 3000)
            return
        }

        // 2. Direct Reminder / Alarm Voice Command (e.g. "remind me at 7 am HOD meeting", "set alarm for 6 am")
        if (lower.contains("remind") || lower.contains("alarm") || lower.contains("alert")) {
            val handled = handleVoiceReminderNative(lower)
            if (handled) {
                handler.postDelayed({ if (isHandsFreeMode) loopListen() }, 3000)
                return
            }
        }

        // 3. App Launcher Voice Command (e.g. "open whatsapp", "open youtube", "open calculator")
        if (lower.startsWith("open ") || lower.startsWith("launch ")) {
            val appQuery = lower.replace("open ", "").replace("launch ", "").trim()
            val launched = launchAppByName(appQuery)
            if (launched) {
                updateUI("Opening $appQuery...", "#00FF88", false)
                speakResponse("Opening $appQuery")
                handler.postDelayed({ if (isHandsFreeMode) loopListen() }, 3000)
                return
            }
        }

        // 4. Default: Speak back response & launch AIRA with command
        speakResponse("AIRA activated")
        updateUI("⚡ \"$command\"", "#00FF88", false)
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("voice_command", command)
        }
        try { startActivity(launchIntent) } catch (_: Exception) {}
        handler.postDelayed({ if (isHandsFreeMode) loopListen() }, 4000)
    }

    private fun toggleFlashlightNative(enable: Boolean) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val cameraManager = getSystemService(Context.CAMERA_SERVICE) as android.hardware.camera2.CameraManager
                val cameraId = cameraManager.cameraIdList.firstOrNull()
                if (cameraId != null) {
                    cameraManager.setTorchMode(cameraId, enable)
                }
            }
        } catch (_: Exception) {}
    }

    private fun handleVoiceReminderNative(lower: String): Boolean {
        try {
            // Regex to parse hour, minute, am/pm
            val timeMatch = Regex("""(\d{1,2})(?::(\d{2}))?\s*(am|pm)?""").find(lower)
            if (timeMatch != null) {
                var hour = timeMatch.groupValues[1].toInt()
                val minStr = timeMatch.groupValues[2]
                val minute = if (minStr.isNotEmpty()) minStr.toInt() else 0
                val ampm = timeMatch.groupValues[3]
                if (ampm == "pm" && hour < 12) hour += 12
                if (ampm == "am" && hour == 12) hour = 0

                // Clean label
                var label = lower.replace(Regex("""remind me (to|that|about|at|on)?"""), "")
                    .replace(Regex("""set (an )?alarm (for|at)?"""), "")
                    .replace(Regex("""\d{1,2}(:\d{2})?\s*(am|pm)?"""), "")
                    .trim()
                if (label.isEmpty()) label = "AIRA Voice Reminder"
                label = label.replaceFirstChar { it.uppercase() }

                val now = java.util.Calendar.getInstance()
                val target = java.util.Calendar.getInstance().apply {
                    set(java.util.Calendar.HOUR_OF_DAY, hour)
                    set(java.util.Calendar.MINUTE, minute)
                    set(java.util.Calendar.SECOND, 0)
                    set(java.util.Calendar.MILLISECOND, 0)
                    if (timeInMillis <= now.timeInMillis) {
                        add(java.util.Calendar.DAY_OF_YEAR, 1)
                    }
                }

                val notifId = (System.currentTimeMillis() / 1000).toInt()
                AlarmReceiver.scheduleOneTime(applicationContext, notifId, "AIRA Reminder 🔔", label, target.timeInMillis)

                val displayTime = String.format("%02d:%02d", hour, minute)
                val responseMsg = "Reminder set for $displayTime for $label"
                updateUI("🔔 $responseMsg", "#00FF88", false)
                speakResponse(responseMsg)
                return true
            }
        } catch (_: Exception) {}
        return false
    }

    private fun launchAppByName(query: String): Boolean {
        try {
            val pm = packageManager
            val packages = pm.getInstalledApplications(android.content.pm.PackageManager.GET_META_DATA)
            for (app in packages) {
                val label = pm.getApplicationLabel(app).toString().lowercase()
                if (label == query || label.contains(query)) {
                    val launchIntent = pm.getLaunchIntentForPackage(app.packageName)
                    if (launchIntent != null) {
                        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(launchIntent)
                        return true
                    }
                }
            }
        } catch (_: Exception) {}
        return false
    }

    private fun updateUI(text: String, borderColor: String, pulsing: Boolean) {
        handler.post {
            statusText?.text = text
            (capsuleView?.background as? GradientDrawable)?.setStroke(
                if (pulsing) 4 else 3,
                Color.parseColor(borderColor)
            )
            micIcon?.setColorFilter(Color.parseColor(borderColor))
        }
    }

    private fun stopListening() {
        isListening = false
        try {
            speechRecognizer?.stopListening()
            speechRecognizer?.cancel()
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        super.onDestroy()
        isHandsFreeMode = false
        isListening = false
        handler.removeCallbacksAndMessages(null)
        try {
            speechRecognizer?.destroy()
            speechRecognizer = null
        } catch (_: Exception) {}
        try {
            tts?.stop()
            tts?.shutdown()
            tts = null
        } catch (_: Exception) {}
        try {
            if (capsuleView != null) windowManager?.removeView(capsuleView)
        } catch (_: Exception) {}
    }
}
