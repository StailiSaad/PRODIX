package com.example.prodix

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import kotlin.concurrent.thread
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

class NotificationActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.getStringExtra("notificationAction") ?: return
        val callId = intent.getStringExtra("callId") ?: ""
        val callType = intent.getStringExtra("callType") ?: "audio"
        val callerName = intent.getStringExtra("callerName") ?: "Quelqu'un"

        when (action) {
            "decline" -> handleDecline(context, callId, callType, callerName)
            else -> {
                val mainIntent = Intent(context, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    putExtra("notificationAction", action)
                    putExtra("callId", callId)
                }
                context.startActivity(mainIntent)
            }
        }
    }

    private fun handleDecline(context: Context, callId: String, callType: String, callerName: String) {
        ensureChannel(context)
        thread {
            try {
                val prefs = context.getSharedPreferences(BackgroundService.PREF_NAME, Context.MODE_PRIVATE)
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

        val typeLabel = if (callType == "video") "vidéo" else "audio"
        val updatedNotification = NotificationCompat.Builder(context, "incoming_calls_channel")
            .setContentTitle("Appel $typeLabel refusé")
            .setContentText(callerName)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify("incoming_call", 1001, updatedNotification)
    }

    private fun ensureChannel(context: Context) {
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
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }
}

/**
 * Returns PendingIntent flags compatible with the current API level.
 * FLAG_IMMUTABLE requires API 31+; omitting it on older APIs works fine.
 */
fun pendingIntentFlags(update: Boolean = true): Int {
    var flags = 0
    if (update) flags = flags or PendingIntent.FLAG_UPDATE_CURRENT
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        flags = flags or PendingIntent.FLAG_IMMUTABLE
    }
    return flags
}
