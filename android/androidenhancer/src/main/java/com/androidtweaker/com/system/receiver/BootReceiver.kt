package com.androidtweaker.com.system.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import com.androidtweaker.com.data.local.appDataStore
import com.androidtweaker.com.data.local.snapshotFlow
import com.androidtweaker.com.data.local.updateSnapshot
import com.androidtweaker.com.system.service.BootService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        
        // Only proceed if device recently booted (within 5 minutes)
        // This prevents false triggers from app reinstalls or debug scenarios
        val uptimeMinutes = SystemClock.elapsedRealtime() / 60_000
        if (uptimeMinutes > 5) return

        val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        scope.launch {
            try {
                val snapshot = context.appDataStore.snapshotFlow().first()
                if (snapshot.startOnBoot) {
                    // Start on boot is enabled - start the boot service
                    val serviceIntent = Intent(context, BootService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(serviceIntent)
                    } else {
                        context.startService(serviceIntent)
                    }
                } else {
                    // Start on boot is disabled - ensure service is disabled
                    // so it won't auto-start when user opens the app
                    context.appDataStore.updateSnapshot { it.copy(serviceEnabled = false) }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
