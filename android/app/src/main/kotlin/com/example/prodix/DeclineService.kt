package com.example.prodix

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import kotlin.concurrent.thread
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

class DeclineService : Service() {

    private val FG_ID = 1005

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val callId = intent?.getStringExtra("callId") ?: ""
        val callType = intent?.getStringExtra("callType") ?: "audio"
        val callerName = intent?.getStringExtra("callerName") ?: "Quelqu'un"

        ensureChannel()

        // Must call startForeground within 5s when started via getForegroundService
        val fgNotification = NotificationCompat.Builder(this, "incoming_calls_channel")
            .setContentTitle("Appel en cours de refus...")
            .setContentText(callerName)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(FG_ID, fgNotification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(FG_ID, fgNotification)
        }

        // HTTP call in background thread
        thread {
            try {
                val prefs = getSharedPreferences(BackgroundService.PREF_NAME, Context.MODE_PRIVATE)
                val supabaseUrl = prefs.getString(BackgroundService.KEY_URL, "") ?: ""
                val authToken = prefs.getString(BackgroundService.KEY_TOKEN, "") ?: ""
                val anonKey = prefs.getString(BackgroundService.KEY_ANON, "") ?: ""
                if (supabaseUrl.isNotEmpty() && authToken.isNotEmpty() && callId.isNotEmpty()) {
                    val url = URL("$supabaseUrl/rest/v1/calls?id=eq.$callId")
                    val conn = url.openConnection() as HttpURLConnection
                    conn.requestMethod = "PATCH"
                    conn.setRequestProperty("Content-Type", "application/json")
                    conn.setRequestProperty("apikey", anonKey)
                    conn.setRequestProperty("Authorization", "Bearer $authToken")
                    conn.doOutput = true
                    conn.connectTimeout = 10000
                    conn.readTimeout = 10000
                    val writer = OutputStreamWriter(conn.outputStream)
                    writer.write("""{"status":"ended"}""")
                    writer.flush()
                    writer.close()
                    conn.responseCode
                    conn.disconnect()
                }
            } catch (_: Exception) {}
        }

        // Update to "Appel refusé"
        val typeLabel = if (callType == "video") "vidéo" else "audio"
        val updatedNotification = NotificationCompat.Builder(this, "incoming_calls_channel")
            .setContentTitle("Appel $typeLabel refusé")
            .setContentText(callerName)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()

        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.notify("incoming_call", 1001, updatedNotification)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "incoming_calls_channel",
                "Appels entrants",
                NotificationManager.IMPORTANCE_MAX
            ).apply {
                description = "Notifications d'appels entrants avec actions"
                enableVibration(true)
                setShowBadge(true)
            }
            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }
}
