package com.example.aria

import android.app.AppOpsManager
import android.app.NotificationManager
import android.content.Intent
import android.media.AudioManager
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.aria/app_blocker"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // ── Notification Listener ─────────────────────────────
                    "hasNotificationListenerPermission" -> {
                        result.success(hasNotificationListenerPermission())
                    }
                    "requestNotificationListenerPermission" -> {
                        val intentsToTry = listOf(
                            "android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS",
                            "android.settings.NOTIFICATION_LISTENER_SETTINGS",
                            Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS
                        )
                        var opened = false
                        for (action in intentsToTry) {
                            try {
                                val intent = Intent(action)
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                                opened = true
                                break
                            } catch (e: Exception) {
                                continue
                            }
                        }
                        if (!opened) {
                            try {
                                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                                intent.data = android.net.Uri.parse("package:$packageName")
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                            } catch (e: Exception) {
                                e.printStackTrace()
                            }
                        }
                        result.success(null)
                    }
                    "enableNotificationBlocking" -> {
                        NotificationBlockerService.isBlocking = true
                        result.success(true)
                    }
                    "disableNotificationBlocking" -> {
                        NotificationBlockerService.isBlocking = false
                        result.success(true)
                    }

                    // ── Accessibility / App Blocking ──────────────────────
                    "hasAccessibilityPermission" -> {
                        result.success(hasAccessibilityPermission())
                    }
                    "requestAccessibilityPermission" -> {
                        try {
                            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                        result.success(null)
                    }
                    "startAppBlocking" -> {
    val apps = call.argument<List<String>>("blockedApps") ?: emptyList()
    try {
        // Try broadcast first
        val intent = Intent("com.example.aria.START_BLOCKING").apply {
            putExtra("blocked_apps", apps.joinToString(","))
            setPackage(packageName)
        }
        sendBroadcast(intent)
        Log.d("ARIABlocker", "📢 Broadcast sent: START_BLOCKING")
        
        // Also write file as backup
        val dir = getExternalFilesDir(null) ?: filesDir
        dir.mkdirs()
        java.io.File(dir, "blocking_state.txt").writeText("true")
        java.io.File(dir, "blocked_apps.txt").writeText(apps.joinToString(","))
        Log.d("ARIABlocker", "📝 File written too")
        
        result.success(true)
    } catch (e: Exception) {
        Log.d("ARIABlocker", "❌ Error: ${e.message}")
        result.error("ERROR", e.message, null)
    }
}
"stopAppBlocking" -> {
    val intent = Intent("com.example.aria.STOP_BLOCKING").apply {
        setPackage(packageName)
    }
    sendBroadcast(intent)
    try {
        val dir = getExternalFilesDir(null) ?: filesDir
        java.io.File(dir, "blocking_state.txt").writeText("false")
    } catch (e: Exception) {}
    Log.d("ARIABlocker", "📢 Broadcast sent: STOP_BLOCKING")
    result.success(true)
}     
                    

     

                    // ── Volume ────────────────────────────────────────────
                    "setMediaVolume" -> {
                        val volume = call.argument<Int>("volume") ?: 60
                        val audio = getSystemService(AUDIO_SERVICE) as AudioManager
                        val maxVolume = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                        audio.setStreamVolume(
                            AudioManager.STREAM_MUSIC,
                            (maxVolume * volume / 100).toInt(),
                            0
                        )
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun hasNotificationListenerPermission(): Boolean {
        val flat = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        )
        return flat != null && flat.contains(packageName)
    }

    private fun hasAccessibilityPermission(): Boolean {
    return try {
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: ""
        val isEnabled = enabledServices.contains(
            "com.example.aria/com.example.aria.AppBlockerAccessibilityService"
        )
        Log.d("ARIABlocker", "🔐 Accessibility enabled: $isEnabled | services: $enabledServices")
        isEnabled
    } catch (e: Exception) {
        Log.d("ARIABlocker", "❌ Permission check error: ${e.message}")
        false
    }
}
}