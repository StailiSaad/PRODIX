package com.example.prodix

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class NotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.getStringExtra("action") ?: return
        val callId = intent.getStringExtra("callId") ?: ""

        when (action) {
            "decline", "end_call", "mute", "unmute", "speaker", "speaker_off" -> {
                val mainIntent = Intent(context, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    putExtra("notificationAction", action)
                    putExtra("callId", callId)
                }
                context.startActivity(mainIntent)
            }
        }
    }
}
