package com.example.prodix

import android.content.Context
import android.content.pm.PackageManager
import android.os.Process
import rikka.shizuku.Shizuku
import rikka.shizuku.ShizukuProvider

object ShizukuManager {
    private const val SHIZUKU_PACKAGE = "moe.shizuku.privileged.api"

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

    fun requestPermission(): Boolean {
        return try {
            Shizuku.requestPermission(0)
            true
        } catch (_: Exception) {
            false
        }
    }


}
