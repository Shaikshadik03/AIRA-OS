package com.airaos.aira_app

import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraManager
import android.os.BatteryManager
import android.os.Build
import android.provider.AlarmClock
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.aira.os/device_control"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "toggleFlashlight" -> {
                        val enable = call.argument<Boolean>("enable") ?: false
                        val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
                        val cameraId = cameraManager.cameraIdList.firstOrNull { id ->
                            try {
                                val char = cameraManager.getCameraCharacteristics(id)
                                char.get(android.hardware.camera2.CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
                            } catch (e: Exception) {
                                false
                            }
                        } ?: cameraManager.cameraIdList.firstOrNull()

                        if (cameraId != null) {
                            cameraManager.setTorchMode(cameraId, enable)
                            result.success(mapOf("success" to true, "enabled" to enable))
                        } else {
                            result.error("NO_FLASH", "Flashlight hardware is not available on this device.", null)
                        }
                    }

                    "launchApp" -> {
                        val query = (call.argument<String>("query") ?: "").lowercase().trim()
                        if (query.isEmpty()) {
                            result.error("INVALID_QUERY", "App name query cannot be empty.", null)
                            return@setMethodCallHandler
                        }

                        val pm = packageManager
                        var targetPackage: String? = null
                        var targetLabel: String? = null

                        // Popular Package Map
                        val popularApps = mapOf(
                            "whatsapp" to "com.whatsapp",
                            "spotify" to "com.spotify.music",
                            "youtube" to "com.google.android.youtube",
                            "maps" to "com.google.android.apps.maps",
                            "google maps" to "com.google.android.apps.maps",
                            "chrome" to "com.android.chrome",
                            "instagram" to "com.instagram.android",
                            "twitter" to "com.twitter.android",
                            "x" to "com.twitter.android",
                            "telegram" to "org.telegram.messenger",
                            "gmail" to "com.google.android.gm",
                            "camera" to "com.android.camera",
                            "calculator" to "com.google.android.calculator",
                            "clock" to "com.google.android.deskclock",
                            "settings" to "com.android.settings",
                            "photos" to "com.google.android.apps.photos",
                            "gallery" to "com.sec.android.gallery3d",
                            "phone" to "com.google.android.dialer",
                            "messages" to "com.google.android.apps.messaging"
                        )

                        // 1. Check direct popular app dictionary match
                        val mappedPkg = popularApps[query]
                        if (mappedPkg != null) {
                            val intent = pm.getLaunchIntentForPackage(mappedPkg)
                            if (intent != null) {
                                targetPackage = mappedPkg
                                targetLabel = query.capitalize()
                            }
                        }

                        // 2. Search installed applications
                        if (targetPackage == null) {
                            val installed = pm.getInstalledApplications(0)
                            for (app in installed) {
                                val label = app.loadLabel(pm).toString()
                                if (label.lowercase().contains(query) || app.packageName.lowercase().contains(query)) {
                                    val intent = pm.getLaunchIntentForPackage(app.packageName)
                                    if (intent != null) {
                                        targetPackage = app.packageName
                                        targetLabel = label
                                        break
                                    }
                                }
                            }
                        }

                        if (targetPackage != null) {
                            val launchIntent = pm.getLaunchIntentForPackage(targetPackage)
                            if (launchIntent != null) {
                                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(launchIntent)
                                result.success(mapOf("success" to true, "appName" to (targetLabel ?: query), "packageName" to targetPackage))
                            } else {
                                result.error("LAUNCH_FAILED", "Could not create launch intent for $targetPackage", null)
                            }
                        } else {
                            result.error("APP_NOT_FOUND", "Could not find an installed app matching \"$query\".", null)
                        }
                    }

                    "openSettings" -> {
                        val type = (call.argument<String>("type") ?: "default").lowercase().trim()
                        val action = when (type) {
                            "wifi" -> Settings.ACTION_WIFI_SETTINGS
                            "bluetooth" -> Settings.ACTION_BLUETOOTH_SETTINGS
                            "display", "brightness" -> Settings.ACTION_DISPLAY_SETTINGS
                            "sound", "volume" -> Settings.ACTION_SOUND_SETTINGS
                            "battery" -> Settings.ACTION_POWER_USAGE_SUMMARY
                            "location" -> Settings.ACTION_LOCATION_SOURCE_SETTINGS
                            "nfc" -> Settings.ACTION_NFC_SETTINGS
                            "apps" -> Settings.ACTION_APPLICATION_SETTINGS
                            else -> Settings.ACTION_SETTINGS
                        }
                        val intent = Intent(action)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(mapOf("success" to true, "setting" to type))
                    }

                    "getBatteryStatus" -> {
                        val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                        val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                        val isCharging = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            bm.isCharging
                        } else {
                            false
                        }
                        result.success(mapOf("level" to level, "isCharging" to isCharging))
                    }

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

                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("NATIVE_ERROR", e.localizedMessage ?: e.toString(), null)
            }
        }
    }
}
