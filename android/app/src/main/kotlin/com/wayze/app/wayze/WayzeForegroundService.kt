package com.wayze.app.wayze

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/**
 * Foreground service that holds a partial wake lock to allow camera analysis,
 * fusion processing, and spoken navigation guidance to function with the SCREEN OFF.
 */
class WayzeForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "wayze_guidance_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START = "ACTION_START_GUIDANCE"
        const val ACTION_STOP = "ACTION_STOP_GUIDANCE"
        var isServiceRunning = false
            private set
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForegroundGuidance()
                stopSelf()
            }
            else -> {
                startForegroundGuidance()
            }
        }
        return START_STICKY
    }

    private fun startForegroundGuidance() {
        if (isServiceRunning) return

        // 1. Acquire partial wake lock so CPU continues executing with screen turned off
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "Wayze:ScreenOffGuidanceWakeLock"
        ).apply {
            setReferenceCounted(false)
            acquire(12 * 60 * 60 * 1000L) // 12 hour maximum safety timeout
        }

        // 2. Build foreground notification
        val notification = buildNotification("Wayze Active: Guidance & Hazard Detection Running")
        startForeground(NOTIFICATION_ID, notification)
        isServiceRunning = true
    }

    fun updateStatus(statusMessage: String) {
        val notification = buildNotification(statusMessage)
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, notification)
    }

    private fun stopForegroundGuidance() {
        try {
            wakeLock?.let {
                if (it.isHeld) it.release()
            }
        } catch (_: Exception) {}
        wakeLock = null
        isServiceRunning = false
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    private fun buildNotification(contentText: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Wayze Indoor Navigation")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Wayze Guidance Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps Wayze obstacle detection and voice guidance active with screen off"
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        stopForegroundGuidance()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
