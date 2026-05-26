package com.example.prodix

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

class CallMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        val type = message.data["type"] ?: return
        if (type != "call") return // non-call messages handled by Flutter

        val callId = message.data["call_id"] ?: ""
        val callerId = message.data["caller_id"] ?: ""
        val callerName = message.data["caller_name"] ?: "Someone"
        val callType = message.data["call_type"] ?: "audio"
        val typeLabel = if (callType == "video") "vidéo" else "audio"

        // Save call data to prefs so BackgroundService and Flutter can use it
        getSharedPreferences("prodix_bg_prefs", MODE_PRIVATE).edit()
            .putString("pending_call_id", callId)
            .putString("pending_caller_id", callerId)
            .putString("pending_caller_name", callerName)
            .putString("pending_call_type", callType)
            .apply()

        showIncomingCallNotification(callId, callerId, callerName, callType, typeLabel)
    }

    private fun showIncomingCallNotification(
        callId: String,
        callerId: String,
        callerName: String,
        callType: String,
        typeLabel: String
    ) {
        createIncomingCallChannel()
        // Répondre: open MainActivity
        val answerIntent = Intent(this, MainActivity::class.java).apply {
            putExtra("notificationAction", "answer")
            putExtra("callId", callId)
            putExtra("callType", callType)
            putExtra("callerId", callerId)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val piFlags = pendingIntentFlags()
        val answerPi = PendingIntent.getActivity(
            this, callId.hashCode(), answerIntent, piFlags
        )

        // Refuser: DeclineService handles natively (no app open)
        val declineIntent = Intent(this, DeclineService::class.java).apply {
            putExtra("callId", callId)
            putExtra("callType", callType)
            putExtra("callerName", callerName)
        }
        val declinePi = PendingIntent.getForegroundService(
            this, callId.hashCode() + 1, declineIntent, piFlags
        )

        val notification = NotificationCompat.Builder(this, "incoming_calls_channel")
            .setContentTitle("Appel $typeLabel de $callerName")
            .setContentText("Appel $typeLabel entrant")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setFullScreenIntent(answerPi, true)
            .setOngoing(false)
            .setAutoCancel(true)
            .addAction(android.R.drawable.ic_menu_call, "Répondre", answerPi)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Refuser", declinePi)
            .build()

        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        // Same tag+ID as BackgroundService and flutter_local_notifications → no duplicates
        nm.notify("incoming_call", 1001, notification)
    }

    private fun createIncomingCallChannel() {
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
