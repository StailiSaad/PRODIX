package com.example.prodix

import android.content.Context
import android.content.pm.PackageManager
import rikka.shizuku.Shizuku

object ShizukuManager {
    private const val SHIZUKU_PACKAGE = "moe.shizuku.privileged.api"
    private var listenerRegistered = false
    private var pendingContext: Context? = null

    fun isShizukuInstalled(context: Context): Boolean {
        return try {
            context.packageManager.getPackageInfo(SHIZUKU_PACKAGE, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    fun isShizukuRunning(): Boolean {
        return try {
            Shizuku.pingBinder()
        } catch (_: Exception) {
            false
        }
    }

    fun hasShizukuPermission(): Boolean {
        return try {
            Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
        } catch (_: Exception) {
            false
        }
    }

    fun requestPermission(context: Context): Boolean {
        return try {
            if (!listenerRegistered) {
                pendingContext = context.applicationContext
                Shizuku.addRequestPermissionResultListener(permissionListener)
                listenerRegistered = true
                pendingContext = context.applicationContext
            }
            Shizuku.requestPermission(0)
            true
        } catch (_: Exception) {
            false
        }
    }

    private val permissionListener = Shizuku.OnRequestPermissionResultListener { _, grantResult ->
        if (grantResult == PackageManager.PERMISSION_GRANTED) {
            pendingContext?.let { ctx ->
                EnhancerBridge.applyShizukuGrant(ctx)
            }
        }
    }
}
