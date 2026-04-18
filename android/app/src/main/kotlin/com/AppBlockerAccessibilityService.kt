package com.example.aria

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class AppBlockerAccessibilityService : AccessibilityService() {

    companion object {
        var instance: AppBlockerAccessibilityService? = null
    }

    private var isBlocking = false
    private var blockedApps = mutableSetOf<String>()
    private var lastPackage = ""
    private val handler = Handler(Looper.getMainLooper())

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                "com.example.aria.START_BLOCKING" -> {
                    val apps = intent.getStringExtra("blocked_apps") ?: ""
                    blockedApps.clear()
                    if (apps.isNotEmpty()) blockedApps.addAll(apps.split(","))
                    isBlocking = true
                    Log.d("ARIABlocker", "✅ Blocking STARTED — apps: $blockedApps")
                }
                "com.example.aria.STOP_BLOCKING" -> {
                    isBlocking = false
                    blockedApps.clear()
                    Log.d("ARIABlocker", "🔓 Blocking STOPPED")
                }
            }
        }
    }

    private fun isBlockingActive(): Boolean {
        if (isBlocking) return true
        return try {
            val dir = getExternalFilesDir(null) ?: filesDir
            val file = java.io.File(dir, "blocking_state.txt")
            file.exists() && file.readText().trim() == "true"
        } catch (e: Exception) { false }
    }

    private fun getBlockedAppsActive(): Set<String> {
        if (blockedApps.isNotEmpty()) return blockedApps
        return try {
            val dir = getExternalFilesDir(null) ?: filesDir
            val file = java.io.File(dir, "blocked_apps.txt")
            if (file.exists()) {
                val content = file.readText().trim()
                if (content.isNotEmpty()) content.split(",").toSet()
                else emptySet()
            } else emptySet()
        } catch (e: Exception) { emptySet() }
    }

    private val checkRunnable = object : Runnable {
        override fun run() {
            if (isBlockingActive() && getBlockedAppsActive().contains(lastPackage)) {
                Log.d("ARIABlocker", "🚫 Periodic — blocking: $lastPackage")
                launchAria()
            }
            handler.postDelayed(this, 500)
        }
    }

    private fun launchAria() {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            )
            putExtra("showBlockScreen", true)
        }
        startActivity(intent)
    }

    override fun onServiceConnected() {
        instance = this
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
            notificationTimeout = 100
        }
        serviceInfo = info

        val filter = IntentFilter().apply {
            addAction("com.example.aria.START_BLOCKING")
            addAction("com.example.aria.STOP_BLOCKING")
        }
        registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        handler.post(checkRunnable)
        Log.d("ARIABlocker", "✅ Service Connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val packageName = event.packageName?.toString() ?: return

        lastPackage = packageName
        Log.d("ARIABlocker", "👁️ App: $packageName | blocking: ${isBlockingActive()}")

        if (!isBlockingActive()) return

        val allowedPackages = setOf(
            "com.example.aria",
            "com.android.systemui",
            "com.android.launcher",
            "com.google.android.launcher",
            "com.android.settings",
            "com.coloros.launcher",
            "com.oppo.launcher",
        )
        if (allowedPackages.contains(packageName)) return

        if (getBlockedAppsActive().contains(packageName)) {
            Log.d("ARIABlocker", "🚫 Blocking: $packageName")
            launchAria()
        }
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        try { unregisterReceiver(receiver) } catch (e: Exception) {}
        handler.removeCallbacks(checkRunnable)
        instance = null
        super.onDestroy()
    }
}