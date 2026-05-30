package com.example.prodix

import android.app.Application
import android.os.Build
import dagger.hilt.android.HiltAndroidApp
import io.github.iamlooper.androidenhancer.system.root.RootIpc
import com.topjohnwu.superuser.Shell
import org.lsposed.hiddenapibypass.HiddenApiBypass

@HiltAndroidApp
class ProdixApplication : Application() {
    override fun onCreate() {
        try {
            super.onCreate()
        } catch (e: Exception) {
            android.util.Log.e("Prodix", "Hilt/super.onCreate failed: ${e.message}")
        }
        try {
            Shell.enableVerboseLogging = false
            Shell.setDefaultBuilder(Shell.Builder.create()
                .setFlags(Shell.FLAG_MOUNT_MASTER).setTimeout(10))
        } catch (_: Exception) {
            android.util.Log.w("Prodix", "Shell init failed (device may not be rooted)")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                HiddenApiBypass.addHiddenApiExemptions("")
            } catch (_: Exception) {
                android.util.Log.w("Prodix", "HiddenApiBypass failed")
            }
        }
        setupGlobalExceptionHandler()
        try {
            createNotificationChannel()
        } catch (e: Exception) {
            android.util.Log.e("Prodix", "createNotificationChannel failed", e)
        }
        try {
            RootIpc.init(this)
        } catch (_: Exception) {
            android.util.Log.w("Prodix", "RootIpc init failed (device may not be rooted)")
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
