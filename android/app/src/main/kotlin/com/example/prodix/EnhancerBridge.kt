package com.example.prodix

import android.content.Context
import com.androidtweaker.com.data.local.PreferencesSnapshot
import com.androidtweaker.com.data.local.appDataStore
import com.androidtweaker.com.data.local.snapshotFlow
import com.androidtweaker.com.data.local.updateSnapshot
import com.androidtweaker.com.system.jni.AndroidEnhancerMode
import com.androidtweaker.com.system.root.RootIpc
import com.androidtweaker.com.system.util.AppUtil
import com.topjohnwu.superuser.Shell
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import org.json.JSONArray
import org.json.JSONObject

object EnhancerBridge {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var _isRootAvailable: Boolean? = null
    private var _initialized = false

    suspend fun isRootAvailable(): Boolean {
        if (_isRootAvailable != null) return _isRootAvailable!!
        return withContext(Dispatchers.IO) {
            try {
                withTimeout(5000) {
                    Shell.getShell().isRoot
                }
            } catch (_: Exception) {
                false
            }
        }.also { _isRootAvailable = it }
    }

    fun init(context: Context) {
        if (_initialized) return
        _initialized = true
        scope.launch {
            val root = isRootAvailable()
            if (root) {
                RootIpc.init(context)
            }
        }
    }

    suspend fun getStatus(context: Context): String {
        val root = isRootAvailable()
        val snapshot = context.appDataStore.snapshotFlow().first()
        val isRunning = if (root && snapshot.serviceEnabled) {
            RootIpc.invoke { it.isRunning } ?: false
        } else false
        return JSONObject().apply {
            put("serviceEnabled", snapshot.serviceEnabled)
            put("isRunning", isRunning)
            put("isRootAvailable", root)
            put("mode", snapshot.mode.code)
            put("touchBoostEnabled", snapshot.touchBoostEnabled)
            put("startOnBoot", snapshot.startOnBoot)
            put("accessibilityEnabled", snapshot.accessibilityEnabled)
            put("currentApp", snapshot.currentApp)
        }.toString()
    }

    fun setEnabled(context: Context, enabled: Boolean) {
        scope.launch {
            context.appDataStore.updateSnapshot { it.copy(serviceEnabled = enabled) }
            if (enabled) {
                val root = isRootAvailable()
                if (root) {
                    val snapshot = context.appDataStore.snapshotFlow().first()
                    RootIpc.invoke { svc ->
                        svc.start(
                            com.androidtweaker.com.data.local.appLogFile(context).absolutePath,
                            com.androidtweaker.com.data.local.sysfsBackupFile(context).absolutePath
                        )
                        svc.setMode(snapshot.mode.code)
                        svc.setTouchBoostEnabled(snapshot.touchBoostEnabled)
                        snapshot.apps.forEach { (pkg, mode) ->
                            if (mode != AndroidEnhancerMode.AUTO) {
                                svc.setAppOverride(pkg, mode.code)
                            }
                        }
                    }
                }
            } else {
                val root = isRootAvailable()
                if (root) {
                    RootIpc.invoke { it.stop() }
                }
            }
        }
    }

    fun setMode(context: Context, modeCode: Int) {
        val mode = AndroidEnhancerMode.fromCode(modeCode)
        scope.launch {
            context.appDataStore.updateSnapshot { it.copy(mode = mode) }
            val snapshot = context.appDataStore.snapshotFlow().first()
            if (snapshot.serviceEnabled && isRootAvailable()) {
                RootIpc.invoke { it.setMode(modeCode) }
            }
        }
    }

    fun setTouchBoost(context: Context, enabled: Boolean) {
        scope.launch {
            context.appDataStore.updateSnapshot { it.copy(touchBoostEnabled = enabled) }
            val snapshot = context.appDataStore.snapshotFlow().first()
            if (snapshot.serviceEnabled && isRootAvailable()) {
                RootIpc.invoke { it.setTouchBoostEnabled(enabled) }
            }
        }
    }

    fun setStartOnBoot(context: Context, enabled: Boolean) {
        scope.launch {
            context.appDataStore.updateSnapshot { it.copy(startOnBoot = enabled) }
        }
    }

    suspend fun getInstalledApps(context: Context): String {
        val apps = withContext(Dispatchers.Default) {
            AppUtil.installedLaunchableApps(context)
        }
        val arr = JSONArray()
        for (app in apps) {
            arr.put(JSONObject().apply {
                put("packageName", app.packageName)
                put("label", app.label)
            })
        }
        return arr.toString()
    }

    suspend fun getAppModes(context: Context): String {
        val snapshot = context.appDataStore.snapshotFlow().first()
        val arr = JSONArray()
        for ((pkg, mode) in snapshot.apps) {
            arr.put(JSONObject().apply {
                put("packageName", pkg)
                put("mode", mode.code)
            })
        }
        return arr.toString()
    }

    fun setAppMode(context: Context, packageName: String, modeCode: Int) {
        val mode = AndroidEnhancerMode.fromCode(modeCode)
        scope.launch {
            context.appDataStore.updateSnapshot { prefs ->
                val updated = prefs.apps.toMutableMap()
                if (mode == AndroidEnhancerMode.AUTO) {
                    updated.remove(packageName)
                } else {
                    updated[packageName] = mode
                }
                prefs.copy(apps = updated)
            }
            val snapshot = context.appDataStore.snapshotFlow().first()
            if (snapshot.serviceEnabled && isRootAvailable()) {
                RootIpc.invoke {
                    if (mode == AndroidEnhancerMode.AUTO) {
                        it.removeAppOverride(packageName)
                    } else {
                        it.setAppOverride(packageName, modeCode)
                    }
                }
            }
        }
    }

    fun removeAppMode(context: Context, packageName: String) {
        scope.launch {
            context.appDataStore.updateSnapshot { prefs ->
                val updated = prefs.apps.toMutableMap()
                updated.remove(packageName)
                prefs.copy(apps = updated)
            }
            val snapshot = context.appDataStore.snapshotFlow().first()
            if (snapshot.serviceEnabled && isRootAvailable()) {
                RootIpc.invoke { it.removeAppOverride(packageName) }
            }
        }
    }
}
