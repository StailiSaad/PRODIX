package com.androidtweaker.com.ui.screens.home

import androidx.compose.runtime.Immutable
import com.androidtweaker.com.system.jni.AndroidEnhancerMode
import com.androidtweaker.com.system.util.InstalledApp

@Immutable
data class HomeState(
    val mode: AndroidEnhancerMode = AndroidEnhancerMode.AUTO,
    val apps: Map<String, AndroidEnhancerMode> = emptyMap(),
    val currentApp: String = "",
    val accessibilityEnabled: Boolean = false,
    val androidEnhancerRunning: Boolean = false,
    val installedApps: List<InstalledApp> = emptyList(),
    val isModeUpdating: Boolean = false,
    val serviceEnabled: Boolean = false
)
