package com.example.prodix

import android.app.Application
import android.os.Build
import dagger.hilt.android.HiltAndroidApp
import com.topjohnwu.superuser.Shell
import org.lsposed.hiddenapibypass.HiddenApiBypass

@HiltAndroidApp
class ProdixApplication : Application() {
    override fun onCreate() {
        try {
            super.onCreate()
        } catch (e: Throwable) {
            android.util.Log.e("Prodix", "Hilt/super.onCreate failed: ${e.message}")
        }
        // Defer Shell + HiddenApiBypass init to a background thread only if rooted.
        // Shell.Builder.create() blocks waiting for a root shell;
        // on non-rooted devices this can hang up to the 10s timeout, causing ANR.
        Thread {
            try {
                // Quick check: if the device is not rooted, skip Shell init entirely.
                val isRoot = try {
                    val suFile = java.io.File("/system/bin/su")
                    val suFile2 = java.io.File("/system/xbin/su")
                    suFile.exists() || suFile2.exists()
                } catch (_: Exception) { false }

                if (isRoot) {
                    Shell.enableVerboseLogging = false
                    Shell.setDefaultBuilder(Shell.Builder.create()
                        .setFlags(Shell.FLAG_MOUNT_MASTER).setTimeout(10))
                }
            } catch (_: Throwable) {
                android.util.Log.w("Prodix", "Shell init failed (device may not be rooted)")
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                try {
                    HiddenApiBypass.addHiddenApiExemptions("")
                } catch (_: Throwable) {
                    android.util.Log.w("Prodix", "HiddenApiBypass failed")
                }
            }
        }.apply { isDaemon = true }.start()

        setupGlobalExceptionHandler()
        try {
            createNotificationChannel()
        } catch (e: Throwable) {
            android.util.Log.e("Prodix", "createNotificationChannel failed", e)
        }
    }

    private fun setupGlobalExceptionHandler() {
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            val stackTrace = android.util.Log.getStackTraceString(throwable)
            try {
                val crashPath = "${cacheDir.absolutePath}/prodix_crash.txt"
                java.io.FileWriter(crashPath).use { it.write(stackTrace) }
            } catch (_: Exception) {}
            val clipboard = getSystemService(CLIPBOARD_SERVICE) as android.content.ClipboardManager
            clipboard.setPrimaryClip(android.content.ClipData.newPlainText("crash_log", stackTrace))
            android.util.Log.e("Prodix", "Uncaught exception", throwable)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                "boot_service",
                getString(io.github.iamlooper.androidenhancer.R.string.notification_channel_boot_service_name),
                android.app.NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = getString(io.github.iamlooper.androidenhancer.R.string.notification_channel_boot_service_description)
            }
            val manager = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
