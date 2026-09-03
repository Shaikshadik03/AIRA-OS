package com.airaos.aira_app

import android.app.AlarmManager
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import java.net.URLEncoder
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.media.MediaMetadataRetriever
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.provider.AlarmClock
import android.provider.ContactsContract
import android.provider.Settings
import android.view.KeyEvent
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.aira.os/device_control"
    private val EVENT_CHANNEL = "com.aira.os/wakeword_events"
    private val NOTIF_EVENT_CHANNEL = "com.aira.os/notification_events"

    private var eventSink: EventChannel.EventSink? = null
    @Volatile private var isAudioRecordListening = false
    private var audioRecord: AudioRecord? = null

    // SpeechRecognizer for real "Hey AIRA" wake word detection
    private var speechRecognizer: SpeechRecognizer? = null
    @Volatile private var isSpeechWakeWordActive = false

    // Comprehensive popular apps package dictionary (60+ apps)
    private val popularApps = mapOf(
        // Social & Communication
        "whatsapp" to "com.whatsapp",
        "telegram" to "org.telegram.messenger",
        "instagram" to "com.instagram.android",
        "twitter" to "com.twitter.android",
        "x" to "com.twitter.android",
        "facebook" to "com.facebook.katana",
        "snapchat" to "com.snapchat.android",
        "linkedin" to "com.linkedin.android",
        "pinterest" to "com.pinterest",
        "reddit" to "com.reddit.frontpage",
        "discord" to "com.discord",
        "signal" to "org.thoughtcrime.securesms",
        "skype" to "com.skype.raider",
        // Google Apps
        "gmail" to "com.google.android.gm",
        "maps" to "com.google.android.apps.maps",
        "google maps" to "com.google.android.apps.maps",
        "youtube" to "com.google.android.youtube",
        "chrome" to "com.android.chrome",
        "meet" to "com.google.android.apps.meetings",
        "google meet" to "com.google.android.apps.meetings",
        "drive" to "com.google.android.apps.docs",
        "google drive" to "com.google.android.apps.docs",
        "docs" to "com.google.android.apps.docs.editors.docs",
        "sheets" to "com.google.android.apps.docs.editors.sheets",
        "slides" to "com.google.android.apps.docs.editors.slides",
        "photos" to "com.google.android.apps.photos",
        "keep" to "com.google.android.apps.keep",
        "google keep" to "com.google.android.apps.keep",
        "translate" to "com.google.android.apps.translate",
        "news" to "com.google.android.apps.magazines",
        "podcasts" to "com.google.android.apps.podcasts",
        // Streaming & Entertainment
        "spotify" to "com.spotify.music",
        "netflix" to "com.netflix.mediaclient",
        "amazon prime" to "com.amazon.avod.thirdpartyclient",
        "prime video" to "com.amazon.avod.thirdpartyclient",
        "hotstar" to "in.startv.hotstar",
        "disney" to "in.startv.hotstar",
        "youtube music" to "com.google.android.apps.youtube.music",
        "gaana" to "com.gaana",
        "jio saavn" to "com.jio.media.jiobeats",
        "saavn" to "com.jio.media.jiobeats",
        "vlc" to "org.videolan.vlc",
        "mx player" to "com.mxtech.videoplayer.ad",
        // Shopping & Finance
        "amazon" to "in.amazon.mShop.android.shopping",
        "flipkart" to "com.flipkart.android",
        "myntra" to "com.myntra.android",
        "swiggy" to "in.swiggy.android",
        "zomato" to "com.application.zomato",
        "phonepe" to "com.phonepe.app",
        "paytm" to "net.one97.paytm",
        "gpay" to "com.google.android.apps.nbu.paisa.user",
        "google pay" to "com.google.android.apps.nbu.paisa.user",
        "cred" to "com.dreamplug.androidapp",
        // Productivity & Utilities
        "calculator" to "com.google.android.calculator",
        "clock" to "com.google.android.deskclock",
        "calendar" to "com.google.android.calendar",
        "camera" to "com.android.camera",
        "settings" to "com.android.settings",
        "files" to "com.google.android.apps.nbu.files",
        "file manager" to "com.google.android.apps.nbu.files",
        "phone" to "com.google.android.dialer",
        "contacts" to "com.google.android.contacts",
        "messages" to "com.google.android.apps.messaging",
        "gallery" to "com.sec.android.gallery3d",
        "notes" to "com.google.android.keep",
        "maps" to "com.google.android.apps.maps",
        // Travel & Navigation
        "uber" to "com.ubercab",
        "ola" to "com.olacabs.customer",
        "rapido" to "com.rapido.passenger",
        // Misc
        "zoom" to "us.zoom.videomeetings",
        "teams" to "com.microsoft.teams",
        "microsoft teams" to "com.microsoft.teams",
        "outlook" to "com.microsoft.office.outlook",
        "word" to "com.microsoft.office.word",
        "excel" to "com.microsoft.office.excel",
        "truecaller" to "com.truecaller"
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    startNativeAudioRecordStream()
                }

                override fun onCancel(arguments: Any?) {
                    stopNativeAudioRecordStream()
                    eventSink = null
                }
            }
        )

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    AiraNotificationListenerService.eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    AiraNotificationListenerService.eventSink = null
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {

                    // ── Overlay Service (Siri / Bixby style system-wide voice bar) ──
                    "startOverlayService" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                            result.success(mapOf("success" to false, "permissionRequested" to true))
                        } else {
                            val intent = Intent(this, OverlayService::class.java)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(mapOf("success" to true))
                        }
                    }

                    // ── Flashlight ──
                    "toggleFlashlight" -> {
                        val enable = call.argument<Boolean>("enable") ?: false
                        val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
                        val cameraId = cameraManager.cameraIdList.firstOrNull { id ->
                            try {
                                val char = cameraManager.getCameraCharacteristics(id)
                                char.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
                            } catch (e: Exception) { false }
                        } ?: cameraManager.cameraIdList.firstOrNull()

                        if (cameraId != null) {
                            cameraManager.setTorchMode(cameraId, enable)
                            result.success(mapOf("success" to true, "enabled" to enable))
                        } else {
                            result.error("NO_FLASH", "Flashlight hardware not available on this device.", null)
                        }
                    }

                    // ── App Launcher (60+ apps) ──
                    "launchApp" -> {
                        val query = (call.argument<String>("query") ?: "").lowercase().trim()
                        if (query.isEmpty()) {
                            result.error("INVALID_QUERY", "App name cannot be empty.", null)
                            return@setMethodCallHandler
                        }

                        val pm = packageManager
                        var targetPackage: String? = null
                        var targetLabel: String? = null

                        // 1. Direct dictionary lookup
                        val mappedPkg = popularApps[query]
                        if (mappedPkg != null && pm.getLaunchIntentForPackage(mappedPkg) != null) {
                            targetPackage = mappedPkg
                            targetLabel = query.replaceFirstChar { it.uppercase() }
                        }

                        // 2. Partial dictionary match
                        if (targetPackage == null) {
                            for ((key, pkg) in popularApps) {
                                if (key.contains(query) || query.contains(key)) {
                                    if (pm.getLaunchIntentForPackage(pkg) != null) {
                                        targetPackage = pkg
                                        targetLabel = key.replaceFirstChar { it.uppercase() }
                                        break
                                    }
                                }
                            }
                        }

                        // 3. Search all installed apps
                        if (targetPackage == null) {
                            val installed = pm.getInstalledApplications(0)
                            for (app in installed) {
                                val label = app.loadLabel(pm).toString()
                                if (label.lowercase().contains(query) || app.packageName.lowercase().contains(query)) {
                                    if (pm.getLaunchIntentForPackage(app.packageName) != null) {
                                        targetPackage = app.packageName
                                        targetLabel = label
                                        break
                                    }
                                }
                            }
                        }

                        if (targetPackage != null) {
                            val launchIntent = pm.getLaunchIntentForPackage(targetPackage)!!
                            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(launchIntent)
                            result.success(mapOf("success" to true, "appName" to (targetLabel ?: query), "packageName" to targetPackage))
                        } else {
                            result.error("APP_NOT_FOUND", "No installed app found matching \"$query\".", null)
                        }
                    }

                    // ── Deep-Link App Search ──
                    "searchInApp" -> {
                        val appName = (call.argument<String>("appName") ?: "").lowercase().trim()
                        val searchQuery = (call.argument<String>("searchQuery") ?: "").trim()
                        val encodedQuery = URLEncoder.encode(searchQuery, "UTF-8")

                        val intent = when {
                            appName.contains("youtube") -> {
                                Intent(Intent.ACTION_VIEW, Uri.parse("https://www.youtube.com/results?search_query=$encodedQuery")).apply {
                                    setPackage("com.google.android.youtube")
                                }
                            }
                            appName.contains("spotify") -> {
                                Intent(Intent.ACTION_VIEW, Uri.parse("spotify:search:$encodedQuery")).apply {
                                    setPackage("com.spotify.music")
                                }
                            }
                            appName.contains("map") -> {
                                Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0?q=$encodedQuery")).apply {
                                    setPackage("com.google.android.apps.maps")
                                }
                            }
                            appName.contains("chrome") || appName.contains("google") || appName.contains("browser") -> {
                                Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/search?q=$encodedQuery"))
                            }
                            appName.contains("amazon") -> {
                                Intent(Intent.ACTION_VIEW, Uri.parse("https://www.amazon.in/s?k=$encodedQuery")).apply {
                                    setPackage("in.amazon.mShop.android.shopping")
                                }
                            }
                            appName.contains("play store") || appName.contains("store") -> {
                                Intent(Intent.ACTION_VIEW, Uri.parse("market://search?q=$encodedQuery"))
                            }
                            else -> {
                                Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/search?q=$encodedQuery"))
                            }
                        }

                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        try {
                            startActivity(intent)
                            result.success(mapOf("success" to true, "appName" to appName, "searchQuery" to searchQuery))
                        } catch (e: Exception) {
                            val fallbackIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/search?q=$encodedQuery")).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(fallbackIntent)
                            result.success(mapOf("success" to true, "appName" to appName, "searchQuery" to searchQuery, "fallback" to true))
                        }
                    }

                    // ── System Settings ──
                    "openSettings" -> {
                        val type = (call.argument<String>("type") ?: "default").lowercase().trim()
                        val action = when (type) {
                            "wifi" -> Settings.ACTION_WIFI_SETTINGS
                            "bluetooth" -> Settings.ACTION_BLUETOOTH_SETTINGS
                            "display", "brightness" -> Settings.ACTION_DISPLAY_SETTINGS
                            "sound", "volume" -> Settings.ACTION_SOUND_SETTINGS
                            "battery" -> Intent.ACTION_POWER_USAGE_SUMMARY
                            "location" -> Settings.ACTION_LOCATION_SOURCE_SETTINGS
                            "nfc" -> Settings.ACTION_NFC_SETTINGS
                            "apps" -> Settings.ACTION_APPLICATION_SETTINGS
                            "accessibility" -> Settings.ACTION_ACCESSIBILITY_SETTINGS
                            "developer" -> Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS
                            "storage" -> Settings.ACTION_INTERNAL_STORAGE_SETTINGS
                            "network" -> Settings.ACTION_WIRELESS_SETTINGS
                            else -> Settings.ACTION_SETTINGS
                        }
                        val intent = Intent(action)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(mapOf("success" to true, "setting" to type))
                    }

                    // ── Battery Status ──
                    "getBatteryStatus" -> {
                        val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                        val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                        val isCharging = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) bm.isCharging else false
                        result.success(mapOf("level" to level, "isCharging" to isCharging))
                    }

                    // ── Set Alarm ──
                    "setAlarm" -> {
                        val hour = call.argument<Int>("hour") ?: 7
                        val minute = call.argument<Int>("minute") ?: 0
                        val message = call.argument<String>("message") ?: "AIRA Alarm"
                        val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                            putExtra(AlarmClock.EXTRA_HOUR, hour)
                            putExtra(AlarmClock.EXTRA_MINUTES, minute)
                            putExtra(AlarmClock.EXTRA_MESSAGE, message)
                            putExtra(AlarmClock.EXTRA_SKIP_UI, false)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(mapOf("success" to true, "hour" to hour, "minute" to minute, "message" to message))
                    }

                    // ── Set Timer ──
                    "setTimer" -> {
                        val seconds = call.argument<Int>("seconds") ?: 60
                        val message = call.argument<String>("message") ?: "AIRA Timer"
                        val intent = Intent(AlarmClock.ACTION_SET_TIMER).apply {
                            putExtra(AlarmClock.EXTRA_LENGTH, seconds)
                            putExtra(AlarmClock.EXTRA_MESSAGE, message)
                            putExtra(AlarmClock.EXTRA_SKIP_UI, false)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(mapOf("success" to true, "seconds" to seconds, "message" to message))
                    }

                    // ── Volume Control ──
                    "adjustVolume" -> {
                        val direction = call.argument<String>("direction") ?: "up"
                        val streamType = call.argument<String>("stream") ?: "media"
                        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager

                        val stream = when (streamType) {
                            "ring" -> AudioManager.STREAM_RING
                            "alarm" -> AudioManager.STREAM_ALARM
                            "notification" -> AudioManager.STREAM_NOTIFICATION
                            else -> AudioManager.STREAM_MUSIC
                        }

                        when (direction) {
                            "up" -> am.adjustStreamVolume(stream, AudioManager.ADJUST_RAISE, AudioManager.FLAG_SHOW_UI)
                            "down" -> am.adjustStreamVolume(stream, AudioManager.ADJUST_LOWER, AudioManager.FLAG_SHOW_UI)
                            "mute" -> am.adjustStreamVolume(stream, AudioManager.ADJUST_MUTE, AudioManager.FLAG_SHOW_UI)
                            "unmute" -> am.adjustStreamVolume(stream, AudioManager.ADJUST_UNMUTE, AudioManager.FLAG_SHOW_UI)
                            "max" -> am.setStreamVolume(stream, am.getStreamMaxVolume(stream), AudioManager.FLAG_SHOW_UI)
                            "min" -> am.setStreamVolume(stream, 0, AudioManager.FLAG_SHOW_UI)
                        }

                        val currentVol = am.getStreamVolume(stream)
                        val maxVol = am.getStreamMaxVolume(stream)
                        result.success(mapOf("success" to true, "currentVolume" to currentVol, "maxVolume" to maxVol, "stream" to streamType))
                    }

                    // ── Media Playback Control ──
                    "controlMedia" -> {
                        val action = call.argument<String>("action") ?: "play_pause"
                        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager

                        val keyCode = when (action) {
                            "play_pause" -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
                            "play" -> KeyEvent.KEYCODE_MEDIA_PLAY
                            "pause" -> KeyEvent.KEYCODE_MEDIA_PAUSE
                            "next" -> KeyEvent.KEYCODE_MEDIA_NEXT
                            "previous" -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
                            "stop" -> KeyEvent.KEYCODE_MEDIA_STOP
                            else -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
                        }

                        am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
                        am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, keyCode))
                        result.success(mapOf("success" to true, "action" to action))
                    }

                    // ── Copy to Clipboard ──
                    "copyToClipboard" -> {
                        val text = call.argument<String>("text") ?: ""
                        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        val clip = ClipData.newPlainText("AIRA", text)
                        clipboard.setPrimaryClip(clip)
                        result.success(mapOf("success" to true, "copied" to text.take(50)))
                    }

                    // ── Device Info ──
                    "getDeviceInfo" -> {
                        val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                        val batteryLevel = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                        val isCharging = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) bm.isCharging else false

                        val stat = StatFs(Environment.getDataDirectory().path)
                        val blockSize = stat.blockSizeLong
                        val totalBlocks = stat.blockCountLong
                        val availBlocks = stat.availableBlocksLong
                        val totalStorage = (totalBlocks * blockSize) / (1024 * 1024 * 1024)
                        val availStorage = (availBlocks * blockSize) / (1024 * 1024)

                        result.success(mapOf(
                            "manufacturer" to Build.MANUFACTURER,
                            "model" to Build.MODEL,
                            "androidVersion" to Build.VERSION.RELEASE,
                            "sdkVersion" to Build.VERSION.SDK_INT,
                            "brand" to Build.BRAND,
                            "batteryLevel" to batteryLevel,
                            "isCharging" to isCharging,
                            "totalStorageGB" to totalStorage,
                            "availStorageMB" to availStorage
                        ))
                    }

                    // ── Floating Overlay ──
                    "canDrawOverlays" -> {
                        val canDraw = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Settings.canDrawOverlays(this)
                        } else {
                            true
                        }
                        result.success(canDraw)
                    }

                    "requestOverlayPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                android.net.Uri.parse("package:$packageName")
                            )
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                        }
                        result.success(true)
                    }

                    "startOverlay" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                            result.error("NO_PERMISSION", "Overlay permission not granted.", null)
                        } else {
                            val intent = Intent(this, OverlayService::class.java)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(true)
                        }
                    }

                    "stopOverlay" -> {
                        val intent = Intent(this, OverlayService::class.java)
                        stopService(intent)
                        result.success(true)
                    }

                    // ── Search Native Android Contacts ──
                    "searchDeviceContacts" -> {
                        val query = (call.argument<String>("query") ?: "").lowercase().trim()
                        val contactsList = mutableListOf<Map<String, String>>()
                        if (query.isNotEmpty()) {
                            val cr = contentResolver
                            val uri = ContactsContract.CommonDataKinds.Phone.CONTENT_URI
                            val projection = arrayOf(
                                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                                ContactsContract.CommonDataKinds.Phone.NUMBER
                            )
                            val selection = "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ?"
                            val selectionArgs = arrayOf("%$query%")
                            val cursor = cr.query(uri, projection, selection, selectionArgs, null)
                            cursor?.use {
                                val nameIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                                val numIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                                while (it.moveToNext()) {
                                    val name = if (nameIdx >= 0) it.getString(nameIdx) else ""
                                    val number = if (numIdx >= 0) it.getString(numIdx) else ""
                                    if (name.isNotEmpty() && number.isNotEmpty()) {
                                        contactsList.add(mapOf("name" to name, "phone" to number))
                                    }
                                }
                            }
                        }
                        result.success(contactsList)
                    }

                    // ── Native Daily Alarm Scheduling ──
                    "scheduleNativeDailyAlarm" -> {
                        val notifId = call.argument<Int>("id") ?: 0
                        val title = call.argument<String>("title") ?: "AIRA"
                        val body = call.argument<String>("body") ?: ""
                        val hour = call.argument<Int>("hour") ?: 7
                        val minute = call.argument<Int>("minute") ?: 0
                        AlarmReceiver.scheduleDaily(this, notifId, title, body, hour, minute)
                        result.success(true)
                    }

                    "scheduleNativeOneTimeAlarm" -> {
                        val notifId = call.argument<Int>("id") ?: 0
                        val title = call.argument<String>("title") ?: "AIRA"
                        val body = call.argument<String>("body") ?: ""
                        val timestampMs = (call.argument<Number>("timestampMs") ?: System.currentTimeMillis()).toLong()
                        AlarmReceiver.scheduleOneTime(this, notifId, title, body, timestampMs)
                        result.success(true)
                    }

                    "requestExactAlarmPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                            if (!alarmManager.canScheduleExactAlarms()) {
                                val intent = Intent(
                                    Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                    Uri.parse("package:$packageName")
                                )
                                startActivity(intent)
                                result.success(false)
                                return@setMethodCallHandler
                            }
                        }
                        result.success(true)
                    }

                    "requestIgnoreBatteryOptimizations" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                                val intent = Intent(
                                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:$packageName")
                                )
                                startActivity(intent)
                                result.success(false)
                                return@setMethodCallHandler
                            }
                        }
                        result.success(true)
                    }

                    "cancelNativeAlarm" -> {
                        val notifId = call.argument<Int>("id") ?: 0
                        AlarmReceiver.cancel(this, notifId)
                        result.success(true)
                    }

                    "scheduleDailyBriefings" -> {
                        // Schedule 7 AM Morning Briefing
                        AlarmReceiver.scheduleDaily(
                            this, 700,
                            "☀️ AIRA Morning Briefing",
                            "Good morning! Open AIRA for your daily schedule, tasks, and agenda.",
                            7, 0
                        )
                        // Schedule 10 PM Evening Check-in
                        AlarmReceiver.scheduleDaily(
                            this, 2200,
                            "🌙 AIRA Evening Check-in",
                            "Good evening! Review your completed tasks and plan for tomorrow.",
                            22, 0
                        )
                        result.success(true)
                    }

                    // ── Notification Intelligence Listener ──
                    "isNotificationListenerEnabled" -> {
                        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
                        val isEnabled = flat != null && flat.contains(packageName)
                        result.success(isEnabled)
                    }

                    "openNotificationListenerSettings" -> {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        } else {
                            Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
                        }
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    }

                    "getRecentNotifications" -> {
                        val list = AiraNotificationListenerService.getNotificationsList()
                        result.success(list)
                    }

                    "clearRecentNotifications" -> {
                        AiraNotificationListenerService.clearNotifications()
                        result.success(true)
                    }

                    "sendNotificationReply" -> {
                        val replyKey = call.argument<String>("replyKey") ?: ""
                        val replyText = call.argument<String>("replyText") ?: ""
                        if (replyKey.isEmpty() || replyText.isEmpty()) {
                            result.error("INVALID_ARGS", "replyKey and replyText must not be empty", null)
                            return@setMethodCallHandler
                        }
                        val success = AiraNotificationListenerService.sendReply(this, replyKey, replyText)
                        result.success(mapOf("success" to success))
                    }

                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("NATIVE_ERROR", e.localizedMessage ?: e.toString(), null)
            }
        }
    }

    private fun startNativeAudioRecordStream() {
        // Use SpeechRecognizer for actual "Hey AIRA" detection
        if (isSpeechWakeWordActive) return
        isSpeechWakeWordActive = true
        isAudioRecordListening = true
        runOnUiThread {
            startSpeechWakeWordLoop()
        }
    }

    private fun startSpeechWakeWordLoop() {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            // Fallback: PCM energy threshold (old behavior) if STT not available
            startPcmFallbackLoop()
            return
        }
        speechRecognizer?.destroy()
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onError(error: Int) {
                // On any error, restart listener after short delay (keep the loop alive)
                if (isSpeechWakeWordActive) {
                    android.os.Handler(mainLooper).postDelayed({
                        if (isSpeechWakeWordActive) startSpeechWakeWordLoop()
                    }, 1000)
                }
            }
            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val recognized = matches?.firstOrNull()?.lowercase() ?: ""
                // Check for "hey aira" or just "aira" variations
                val isWakeWord = recognized.contains("aira") ||
                    recognized.contains("ira") && recognized.contains("hey") ||
                    recognized.contains("era") ||
                    recognized.startsWith("ok aira") ||
                    recognized.startsWith("hello aira")
                if (isWakeWord && isSpeechWakeWordActive) {
                    eventSink?.success("wake_word_detected")
                }
                // Keep the loop going
                if (isSpeechWakeWordActive) {
                    android.os.Handler(mainLooper).postDelayed({
                        if (isSpeechWakeWordActive) startSpeechWakeWordLoop()
                    }, 300)
                }
            }
            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val recognized = matches?.firstOrNull()?.lowercase() ?: ""
                if ((recognized.contains("aira") || recognized.contains("hey ira")) && isSpeechWakeWordActive) {
                    eventSink?.success("wake_word_detected")
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
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 1500L)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
        }
        try {
            speechRecognizer?.startListening(intent)
        } catch (e: Exception) {
            if (isSpeechWakeWordActive) {
                android.os.Handler(mainLooper).postDelayed({
                    if (isSpeechWakeWordActive) startSpeechWakeWordLoop()
                }, 2000)
            }
        }
    }

    /// PCM energy fallback (only used if device has no STT engine)
    private fun startPcmFallbackLoop() {
        thread(start = true, isDaemon = true) {
            val sampleRate = 16000
            val channelConfig = AudioFormat.CHANNEL_IN_MONO
            val audioFormat = AudioFormat.ENCODING_PCM_16BIT
            val minBufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
            val bufferSize = Math.max(minBufferSize, 4096)
            try {
                audioRecord = AudioRecord(
                    MediaRecorder.AudioSource.MIC,
                    sampleRate, channelConfig, audioFormat, bufferSize
                )
                if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                    isAudioRecordListening = false; return@thread
                }
                audioRecord?.startRecording()
                val buffer = ShortArray(bufferSize / 2)
                var lastTriggerTime = 0L
                while (isAudioRecordListening) {
                    val readSize = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                    if (readSize > 0) {
                        var sum = 0.0
                        for (i in 0 until readSize) sum += buffer[i] * buffer[i].toLong()
                        val rms = Math.sqrt(sum / readSize)
                        if (rms > 2000.0) {
                            val now = System.currentTimeMillis()
                            if (now - lastTriggerTime > 3000) {
                                lastTriggerTime = now
                                runOnUiThread { eventSink?.success("wake_word_detected") }
                            }
                        } else {
                            Thread.sleep(100)
                        }
                    }
                }
            } catch (e: Exception) {
                isAudioRecordListening = false
            } finally {
                try { audioRecord?.stop(); audioRecord?.release() } catch (_: Exception) {}
                audioRecord = null
            }
        }
    }

    private fun stopNativeAudioRecordStream() {
        isSpeechWakeWordActive = false
        isAudioRecordListening = false
        runOnUiThread {
            speechRecognizer?.stopListening()
            speechRecognizer?.destroy()
            speechRecognizer = null
        }
        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (_: Exception) {}
        audioRecord = null
    }
}
