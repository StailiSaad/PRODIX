package com.example.prodix

import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CALL_CHANNEL = "com.example.prodix/call_service"
    private val BG_CHANNEL = "com.example.prodix/background_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startForegroundService" -> {
                        val peerName = call.argument<String>("peerName") ?: "Appel"
                        val callType = call.argument<String>("callType") ?: "audio"
                        val callState = call.argument<String>("callState") ?: "connected"
                        val callId = call.argument<String>("callId")
                        val isMuted = call.argument<Boolean>("isMuted") ?: false
                        val isSpeaker = call.argument<Boolean>("isSpeaker") ?: false
                        val intent = Intent(this, CallForegroundService::class.java).apply {
                            putExtra("peer_name", peerName)
                            putExtra("call_type", callType)
                            putExtra("call_state", callState)
                            putExtra("call_id", callId)
                            putExtra("is_muted", isMuted)
                            putExtra("is_speaker", isSpeaker)
                        }
                        startForegroundService(intent)
                        result.success(true)
                    }
                    "stopForegroundService" -> {
                        val intent = Intent(this, CallForegroundService::class.java)
                        stopService(intent)
                        result.success(true)
                    }
                    "startOverlay" -> {
                        val intent = Intent(this, OverlayService::class.java)
                        startService(intent)
                        result.success(true)
                    }
                    "stopOverlay" -> {
                        val intent = Intent(this, OverlayService::class.java)
                        stopService(intent)
                        result.success(true)
                    }
                    "canDrawOverlays" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            result.success(Settings.canDrawOverlays(this))
                        } else {
                            result.success(true)
                        }
                    }
                    "openOverlaySettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                android.net.Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BG_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startBackgroundService" -> {
                        val supabaseUrl = call.argument<String>("supabaseUrl") ?: ""
                        val anonKey = call.argument<String>("anonKey") ?: ""
                        val userId = call.argument<String>("userId") ?: ""
                        val authToken = call.argument<String>("authToken") ?: ""
                        val intent = Intent(this, BackgroundService::class.java).apply {
                            putExtra("supabaseUrl", supabaseUrl)
                            putExtra("anonKey", anonKey)
                            putExtra("userId", userId)
                            putExtra("authToken", authToken)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                    "stopBackgroundService" -> {
                        val intent = Intent(this, BackgroundService::class.java)
                        stopService(intent)
                        result.success(true)
                    }
                    "updateBackgroundToken" -> {
                        val authToken = call.argument<String>("authToken") ?: ""
                        val intent = Intent(this, BackgroundService::class.java).apply {
                            putExtra("authToken", authToken)
                        }
                        startService(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        handleNotificationIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleNotificationIntent(intent)
    }

    private fun handleNotificationIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.getStringExtra("notificationAction") ?: return
        val callId = intent.getStringExtra("callId") ?: ""
        val callType = intent.getStringExtra("callType") ?: "audio"

        val messenger = flutterEngine?.dartExecutor?.binaryMessenger ?: return
        MethodChannel(messenger, CALL_CHANNEL).invokeMethod("onNotificationAction", mapOf(
            "action" to action,
            "callId" to callId,
            "callType" to callType
        ))
    }
}
