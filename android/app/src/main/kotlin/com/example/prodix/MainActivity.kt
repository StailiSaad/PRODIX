package com.example.prodix

import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleObserver
import androidx.lifecycle.OnLifecycleEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.lifecycle.LifecycleEventObserver

class MainActivity : FlutterActivity() {
    override fun getRenderMode(): io.flutter.embedding.android.RenderMode = io.flutter.embedding.android.RenderMode.texture

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        val platform = Build.HARDWARE.lowercase()
        val board = Build.BOARD.lowercase()
        // Unisoc/Spreadtrum ums9230 (TECNO KL4) GPU can deadlock with
        // hardware-accelerated rendering (Flutter engine stuck in native
        // GPU sync, window stays shown=false). Force software rendering.
        intent.putExtra("enable-software-rendering", platform.contains("ums9230") || board.contains("ums9230"))
        super.onCreate(savedInstanceState)
    }

    private val CALL_CHANNEL = "com.example.prodix/call_service"
    private val BG_CHANNEL = "com.example.prodix/background_service"
    private val ENHANCER_CHANNEL = "com.example.prodix/android_tweaker"
    private var pendingIntent: Intent? = null
    private var deferredBgIntent: Intent? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        android.util.Log.d("FlutterEngine", "configureFlutterEngine called")
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
                        try {
                            startForegroundService(intent)
                            result.success(true)
                        } catch (e: java.lang.SecurityException) {
                            android.util.Log.e("MainActivity", "startForegroundService SecurityException (may be deferred)", e)
                            result.success(true)
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "startForegroundService failed", e)
                            result.error("FOREGROUND_SERVICE_ERROR", e.message, null)
                        }
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
                        if (lifecycle.currentState.isAtLeast(androidx.lifecycle.Lifecycle.State.STARTED)) {
                            try {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                    startForegroundService(intent)
                                } else {
                                    startService(intent)
                                }
                                result.success(true)
                            } catch (e: Exception) {
                                android.util.Log.e("MainActivity", "startBackgroundService failed", e)
                                result.error("BACKGROUND_SERVICE_ERROR", e.message, null)
                            }
                        } else {
                            deferredBgIntent = intent
                            lateinit var observer: LifecycleEventObserver
                            observer = LifecycleEventObserver { source, event ->
                                if (event == androidx.lifecycle.Lifecycle.Event.ON_START) {
                                    deferredBgIntent?.let {
                                        try {
                                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                                startForegroundService(it)
                                            } else {
                                                startService(it)
                                            }
                                        } catch (e: Exception) {
                                            android.util.Log.e("MainActivity", "deferred bg start failed", e)
                                        }
                                    }
                                    deferredBgIntent = null
                                    source.lifecycle.removeObserver(observer)
                                }
                            }
                            lifecycle.addObserver(observer)
                            result.success(true)
                        }
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ENHANCER_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "launchTweaker" -> {
                            val tweakerIntent = Intent(this, com.androidtweaker.com.MainActivity::class.java)
                            startActivity(tweakerIntent)
                            result.success(true)
                        }
                        "getStatus" -> {
                            EnhancerBridge.init(this)
                            kotlinx.coroutines.runBlocking {
                                result.success(EnhancerBridge.getStatus(this@MainActivity))
                            }
                        }
                        "setEnabled" -> {
                            val enabled = call.argument<Boolean>("enabled") ?: false
                            EnhancerBridge.setEnabled(this, enabled)
                            result.success(true)
                        }
                        "setMode" -> {
                            val modeCode = call.argument<Int>("modeCode") ?: 0
                            EnhancerBridge.setMode(this, modeCode)
                            result.success(true)
                        }
                        "setTouchBoost" -> {
                            val enabled = call.argument<Boolean>("enabled") ?: false
                            EnhancerBridge.setTouchBoost(this, enabled)
                            result.success(true)
                        }
                        "setStartOnBoot" -> {
                            val enabled = call.argument<Boolean>("enabled") ?: false
                            EnhancerBridge.setStartOnBoot(this, enabled)
                            result.success(true)
                        }
                        "getInstalledApps" -> {
                            EnhancerBridge.init(this)
                            kotlinx.coroutines.runBlocking {
                                result.success(EnhancerBridge.getInstalledApps(this@MainActivity))
                            }
                        }
                        "getAppModes" -> {
                            EnhancerBridge.init(this)
                            kotlinx.coroutines.runBlocking {
                                result.success(EnhancerBridge.getAppModes(this@MainActivity))
                            }
                        }
                        "setAppMode" -> {
                            val pkg = call.argument<String>("packageName") ?: ""
                            val modeCode = call.argument<Int>("modeCode") ?: 0
                            EnhancerBridge.setAppMode(this, pkg, modeCode)
                            result.success(true)
                        }
                        "removeAppMode" -> {
                            val pkg = call.argument<String>("packageName") ?: ""
                            EnhancerBridge.removeAppMode(this, pkg)
                            result.success(true)
                        }
                        "getShizukuStatus" -> {
                            result.success(EnhancerBridge.getShizukuStatus(this))
                        }
                        "requestShizukuPermission" -> {
                            result.success(EnhancerBridge.requestShizukuPermission())
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "ENHANCER_CHANNEL error: ${e.message}", e)
                    result.error("ENHANCER_ERROR", e.message, null)
                }
            }
        // Defer intent handling so Flutter's MethodChannel handler is registered
        pendingIntent = intent
        Handler(Looper.getMainLooper()).postDelayed({
            pendingIntent?.let { handleNotificationIntent(it) }
            pendingIntent = null
        }, 1500)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Flutter app is already running → handler is registered → handle immediately
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
