package com.example.prodix

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class CallForegroundService : Service() {

    private var notificationId = 1

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val peerName = intent?.getStringExtra("peer_name") ?: "Appel"
        val callType = intent?.getStringExtra("call_type") ?: "audio"
        val callState = intent?.getStringExtra("call_state") ?: "connected"
        val callId = intent?.getStringExtra("call_id") ?: ""
        val isMuted = intent?.getBooleanExtra("is_muted", false) ?: false
        val isSpeaker = intent?.getBooleanExtra("is_speaker", false) ?: false
        showNotification(peerName, callType, callState, callId, isMuted, isSpeaker)
        return START_STICKY
    }

    private fun showNotification(
        peerName: String,
        callType: String,
        callState: String,
        callId: String,
        isMuted: Boolean = false,
        isSpeaker: Boolean = false
    ) {
        val label = if (callType == "video") "Appel vidéo" else "Appel audio"

        val openIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("navigateToCall", true)
        }
        val openPendingIntent = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentIntent(openPendingIntent)
            .setSmallIcon(android.R.drawable.ic_menu_call)

        when (callState) {
            "ringing" -> {
                val answerIntent = Intent(this, NotificationActionReceiver::class.java).apply {
                    putExtra("action", "answer")
                    putExtra("callId", callId)
                    putExtra("callType", callType)
                }
                val answerPendingIntent = PendingIntent.getBroadcast(
                    this, 2, answerIntent,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )

                val declineIntent = Intent(this, NotificationActionReceiver::class.java).apply {
                    putExtra("action", "decline")
                    putExtra("callId", callId)
                }
                val declinePendingIntent = PendingIntent.getBroadcast(
                    this, 3, declineIntent,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )

                builder
                    .setContentTitle("$label - $peerName")
                    .setContentText("Appel entrant")
                    .setCategory(NotificationCompat.CATEGORY_CALL)
                    .setFullScreenIntent(openPendingIntent, true)
                    .setOngoing(false)
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .addAction(android.R.drawable.ic_menu_call, "Répondre", answerPendingIntent)
                    .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Refuser", declinePendingIntent)
            }
            "waiting" -> {
                val endIntent = Intent(this, NotificationActionReceiver::class.java).apply {
                    putExtra("action", "end_call")
                    putExtra("callId", callId)
                }
                val endPendingIntent = PendingIntent.getBroadcast(
                    this, 4, endIntent,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )

                builder
                    .setContentTitle("$label - $peerName")
                    .setContentText("En attente de réponse...")
                    .setCategory(NotificationCompat.CATEGORY_CALL)
                    .setOngoing(true)
                    .setPriority(NotificationCompat.PRIORITY_LOW)
                    .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Raccrocher", endPendingIntent)
            }
            else -> {
                val endIntent = Intent(this, NotificationActionReceiver::class.java).apply {
                    putExtra("action", "end_call")
                    putExtra("callId", callId)
                }
                val endPendingIntent = PendingIntent.getBroadcast(
                    this, 5, endIntent,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )

                val muteIntent = Intent(this, NotificationActionReceiver::class.java).apply {
                    putExtra("action", if (isMuted) "unmute" else "mute")
                    putExtra("callId", callId)
                }
                val mutePendingIntent = PendingIntent.getBroadcast(
                    this, 6, muteIntent,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )

                val speakerIntent = Intent(this, NotificationActionReceiver::class.java).apply {
                    putExtra("action", if (isSpeaker) "speaker_off" else "speaker")
                    putExtra("callId", callId)
                }
                val speakerPendingIntent = PendingIntent.getBroadcast(
                    this, 7, speakerIntent,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )

                builder
                    .setContentTitle("Appel en cours - $peerName")
                    .setContentText(label)
                    .setCategory(NotificationCompat.CATEGORY_CALL)
                    .setOngoing(true)
                    .setPriority(NotificationCompat.PRIORITY_LOW)
                    .addAction(android.R.drawable.ic_menu_call, if (isMuted) "Activer micro" else "Muet", mutePendingIntent)
                    .addAction(android.R.drawable.ic_media_ff, if (isSpeaker) "Haut-parleur off" else "Haut-parleur", speakerPendingIntent)
                    .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Raccrocher", endPendingIntent)
            }
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(notificationId, builder.build(), android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            } else {
                startForeground(notificationId, builder.build())
            }
        } catch (e: Exception) {
            android.util.Log.e("CallForegroundService", "startForeground failed", e)
            stopSelf()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Appels",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Notifications d'appel"
            enableVibration(true)
            setShowBadge(true)
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val CHANNEL_ID = "ongoing_call_channel"
    }
}
