package com.androidtweaker.com.ui.screens.per_app_mode

import androidx.compose.runtime.Immutable
import com.androidtweaker.com.system.jni.AndroidEnhancerMode
import com.androidtweaker.com.system.util.InstalledApp

@Immutable
data class PerAppModeState(
    val apps: Map<String, AndroidEnhancerMode> = emptyMap(),
    val installedApps: List<InstalledApp> = emptyList(),
    val isLoading: Boolean = true,
    val updatingPackage: String? = null
)
