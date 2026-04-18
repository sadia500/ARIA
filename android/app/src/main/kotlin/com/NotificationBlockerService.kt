package com.example.aria

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class NotificationBlockerService : NotificationListenerService() {

    companion object {
        var isBlocking = false

        // Packages that are NEVER blocked (calls, alarms, ARIA itself)
        private val allowedPackages = setOf(
            "com.android.dialer",
            "com.google.android.dialer",
            "com.android.deskclock",
            "com.google.android.deskclock",
            "com.example.aria" // never block our own app
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (!isBlocking) return
        if (allowedPackages.contains(sbn.packageName)) return

        // Silently cancel the notification
        try {
            cancelNotification(sbn.key)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        // nothing needed here
    }
}