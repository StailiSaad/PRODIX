package com.androidtweaker.com.ui.screens.optimization

import androidx.compose.runtime.Immutable

@Immutable
data class OptimizationState(
    val framePacing: Boolean = false,
    val goodPing: Boolean = false,
    val perfExt: Boolean = false,
    val runtimeControl: Boolean = false,
    val gamePulse: Boolean = false,
    val gpuBoost: Boolean = false,
    val audioTuning: Boolean = false,
    val hyperPerf: Boolean = false,
    val isApplying: String? = null,
    val lastResult: String? = null,
    val liveLog: List<String> = emptyList(),
    val showAdbGrantDialog: Boolean = false,
    val adbWriteSecureGranted: Boolean = false
) {
    fun isEnabled(moduleId: String): Boolean = when (moduleId) {
        "frame_pacing" -> framePacing
        "good_ping" -> goodPing
        "perf_ext" -> perfExt
        "runtime_control" -> runtimeControl
        "game_pulse" -> gamePulse
        "gpu_boost" -> gpuBoost
        "audio_tuning" -> audioTuning
        "hyper_perf" -> hyperPerf
        else -> false
    }

    fun withToggled(moduleId: String, value: Boolean): OptimizationState = when (moduleId) {
        "frame_pacing" -> copy(framePacing = value)
        "good_ping" -> copy(goodPing = value)
        "perf_ext" -> copy(perfExt = value)
        "runtime_control" -> copy(runtimeControl = value)
        "game_pulse" -> copy(gamePulse = value)
        "gpu_boost" -> copy(gpuBoost = value)
        "audio_tuning" -> copy(audioTuning = value)
        "hyper_perf" -> copy(hyperPerf = value)
        else -> this
    }
}
