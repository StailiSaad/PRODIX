package com.example.prodix

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build

class BackgroundServiceReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_RESTART = "com.example.prodix.RESTART_BACKGROUND_SERVICE"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            ACTION_RESTART -> {
                val prefs = context.getSharedPreferences(
                    BackgroundService.PREF_NAME, Context.MODE_PRIVATE
                )
                val url = prefs.getString(BackgroundService.KEY_URL, null)
                val key = prefs.getString(BackgroundService.KEY_ANON, null)
                val uid = prefs.getString(BackgroundService.KEY_UID, null)
                val token = prefs.getString(BackgroundService.KEY_TOKEN, null)
                if (url == null || key == null || uid == null || token == null) return

                val svcIntent = Intent(context, BackgroundService::class.java).apply {
                    putExtra("supabaseUrl", url)
                    putExtra("anonKey", key)
                    putExtra("userId", uid)
                    putExtra("authToken", token)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(svcIntent)
                } else {
                    context.startService(svcIntent)
                }
            }
        }
    }
}
