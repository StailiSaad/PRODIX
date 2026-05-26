package com.example.prodix

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

class BackgroundService : Service() {
    companion object {
        const val CHANNEL_PERSISTENT = "prodix_bg_persistent"
        const val CHANNEL_CALLS = "prodix_bg_calls"
        const val CHANNEL_MESSAGES = "prodix_bg_messages"
        const val NOTIFICATION_ID = 1001
        const val POLL_INTERVAL_MS = 2000L // 2 secondes
        const val WATCHDOG_INTERVAL_MS = 600_000L // 10 minutes
        const val PREF_NAME = "prodix_bg_prefs"
        const val KEY_URL = "supabase_url"
        const val KEY_ANON = "anon_key"
        const val KEY_UID = "user_id"
        const val KEY_TOKEN = "auth_token"
        const val ACTION_RESTART = "com.example.prodix.RESTART_BACKGROUND_SERVICE"
    }

    private val handler = Handler(Looper.getMainLooper())
    private var supabaseUrl = ""
    private var anonKey = ""
    private var userId = ""
    private var authToken = ""
    private var prefs: SharedPreferences? = null
    private var polling = false

    private val pollRunnable = object : Runnable {
        override fun run() {
            if (!polling) return
            if (userId.isNotEmpty() && authToken.isNotEmpty()) {
                try { checkNewCalls() } catch (_: Exception) {}
                try { checkNewMessages() } catch (_: Exception) {}
            }
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        prefs = getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        supabaseUrl = prefs?.getString(KEY_URL, "") ?: ""
        anonKey = prefs?.getString(KEY_ANON, "") ?: ""
        userId = prefs?.getString(KEY_UID, "") ?: ""
        authToken = prefs?.getString(KEY_TOKEN, "") ?: ""
        createNotificationChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.let {
            it.getStringExtra("supabaseUrl")?.let { v ->
                supabaseUrl = v; prefs?.edit()?.putString(KEY_URL, v)?.apply()
            }
            it.getStringExtra("anonKey")?.let { v ->
                anonKey = v; prefs?.edit()?.putString(KEY_ANON, v)?.apply()
            }
            it.getStringExtra("userId")?.let { v ->
                userId = v; prefs?.edit()?.putString(KEY_UID, v)?.apply()
            }
            it.getStringExtra("authToken")?.let { v ->
                authToken = v; prefs?.edit()?.putString(KEY_TOKEN, v)?.apply()
            }
        }

        if (supabaseUrl.isEmpty() || anonKey.isEmpty() || userId.isEmpty() || authToken.isEmpty()) {
            stopSelf()
            return START_NOT_STICKY
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, buildPersistentNotification(),
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, buildPersistentNotification())
        }

        polling = true
        handler.removeCallbacks(pollRunnable)
        handler.post(pollRunnable)

        scheduleWatchdog()
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        polling = false
        handler.removeCallbacks(pollRunnable)
        scheduleWatchdog()
        super.onDestroy()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_PERSISTENT, "Prodix (arrière-plan)",
                    NotificationManager.IMPORTANCE_MIN).apply {
                    description = "Notification persistante pour le service d'arrière-plan"
                    setShowBadge(false)
                }
            )
            nm.createNotificationChannel(
                NotificationChannel("incoming_calls_channel", "Appels entrants",
                    NotificationManager.IMPORTANCE_MAX).apply {
                    description = "Notifications d'appels entrants avec actions"
                    enableVibration(true)
                    setShowBadge(true)
                }
            )
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_MESSAGES, "Messages",
                    NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "Notifications de messages"
                    setShowBadge(true)
                }
            )
        }
    }

    private fun buildPersistentNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pi = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_PERSISTENT)
            .setContentTitle("Prodix")
            .setContentText("Actif en arrière-plan")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pi)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .build()
    }

    private fun scheduleWatchdog() {
        val intent = Intent(this, BackgroundServiceReceiver::class.java).apply {
            action = ACTION_RESTART
        }
        val pi = PendingIntent.getBroadcast(
            this, 1001, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val triggerAt = SystemClock.elapsedRealtime() + WATCHDOG_INTERVAL_MS
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            am.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi)
        } else {
            am.setExact(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi)
        }
    }

    private fun checkNewCalls() {
        val url = URL(
            "$supabaseUrl/rest/v1/calls" +
            "?callee_id=eq.$userId" +
            "&status=eq.ringing" +
            "&select=id,caller_id,call_type,created_at" +
            "&order=created_at.desc&limit=5"
        )
        val json = makeGetRequest(url) ?: return
        val calls = JSONArray(json)
        for (i in 0 until calls.length()) {
            val call = calls.getJSONObject(i)
            val callId = call.getString("id")
            if (prefs?.getString("notified_call_$callId", null) != null) continue
            val callerId = call.getString("caller_id")
            val callType = call.optString("call_type", "audio")
            showCallNotification(callId, callerId, callType)
            prefs?.edit()?.putString("notified_call_$callId", callId)?.apply()
        }
        val known = prefs?.all?.keys?.filter { it.startsWith("notified_call_") } ?: emptyList()
        val activeIds = (0 until calls.length()).map { calls.getJSONObject(it).getString("id") }.toSet()
        for (key in known) {
            if (key.removePrefix("notified_call_") !in activeIds) {
                prefs?.edit()?.remove(key)?.apply()
            }
        }
    }

    private fun checkNewMessages() {
        val url = URL(
            "$supabaseUrl/rest/v1/messages" +
            "?receiver_id=eq.$userId" +
            "&status=neq.seen" +
            "&select=id,sender_id,content,media_type,created_at" +
            "&order=created_at.desc&limit=10"
        )
        val json = makeGetRequest(url) ?: return
        val messages = JSONArray(json)
        for (i in 0 until messages.length()) {
            val msg = messages.getJSONObject(i)
            val msgId = msg.getString("id")
            if (msg.optString("media_type") == "call_event") continue
            if (prefs?.getString("notified_msg_$msgId", null) != null) continue
            val senderId = msg.getString("sender_id")
            val content = msg.optString("content", "")
            if (content.isNotEmpty()) {
                showMessageNotification(msgId, senderId, content)
                prefs?.edit()?.putString("notified_msg_$msgId", msgId)?.apply()
            }
        }
    }

    private fun makeGetRequest(url: URL): String? {
        val conn = url.openConnection() as HttpURLConnection
        try {
            conn.requestMethod = "GET"
            conn.setRequestProperty("apikey", anonKey)
            conn.setRequestProperty("Authorization", "Bearer $authToken")
            conn.setRequestProperty("Accept", "application/json")
            conn.connectTimeout = 10_000
            conn.readTimeout = 10_000
            if (conn.responseCode != 200) return null
            val reader = BufferedReader(InputStreamReader(conn.inputStream))
            val response = reader.readText()
            reader.close()
            return response
        } catch (_: Exception) {
            return null
        } finally {
            conn.disconnect()
        }
    }

    private fun fetchProfileName(profileId: String): String {
        return try {
            val url = URL("$supabaseUrl/rest/v1/profiles?id=eq.$profileId&select=pseudo")
            val json = makeGetRequest(url) ?: return "Quelqu'un"
            val arr = JSONArray(json)
            if (arr.length() > 0) arr.getJSONObject(0).optString("pseudo", "Quelqu'un")
            else "Quelqu'un"
        } catch (_: Exception) {
            "Quelqu'un"
        }
    }

    private fun showCallNotification(callId: String, callerId: String, callType: String) {
        val callerName = fetchProfileName(callerId)
        val typeLabel = if (callType == "video") "vidéo" else "audio"

        val answerIntent = Intent(this, MainActivity::class.java).apply {
            putExtra("notificationAction", "answer")
            putExtra("callId", callId)
            putExtra("callType", callType)
            putExtra("callerId", callerId)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val answerPi = PendingIntent.getActivity(
            this, callId.hashCode(), answerIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val declineIntent = Intent(this, DeclineService::class.java).apply {
            putExtra("callId", callId)
            putExtra("callType", callType)
            putExtra("callerName", callerName)
        }
        val declinePi = PendingIntent.getForegroundService(
            this, callId.hashCode() + 1, declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, "incoming_calls_channel")
            .setContentTitle("Appel $typeLabel de $callerName")
            .setContentText("Appel $typeLabel entrant")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setFullScreenIntent(answerPi, true)
            .addAction(android.R.drawable.ic_menu_call, "Répondre", answerPi)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Refuser", declinePi)
            .setAutoCancel(true)
            .build()

        val nm = getSystemService(NotificationManager::class.java)
        // Use same ID+tag as flutter_local_notifications so either source replaces the other
        nm.notify("incoming_call", 1001, notification)
    }

    private fun showMessageNotification(msgId: String, senderId: String, content: String) {
        val senderName = fetchProfileName(senderId)

        val intent = Intent(this, MainActivity::class.java).apply {
            putExtra("notificationAction", "open_dm")
            putExtra("peerId", senderId)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pi = PendingIntent.getActivity(
            this, senderId.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_MESSAGES)
            .setContentTitle(senderName)
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(pi)
            .setAutoCancel(true)
            .build()

        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(3000 + (senderId.hashCode() % 1000).coerceAtLeast(0), notification)
    }
}
