package io.github.iamlooper.androidenhancer.ui.screens.optimization

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import io.github.iamlooper.androidenhancer.data.local.appDataStore
import io.github.iamlooper.androidenhancer.data.local.snapshotFlow
import io.github.iamlooper.androidenhancer.data.local.updateSnapshot
import io.github.iamlooper.androidenhancer.system.optimization.OptimizationExecutor
import io.github.iamlooper.androidenhancer.system.optimization.OptimizationModule
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

@HiltViewModel
class OptimizationViewModel @Inject constructor(
    @param:ApplicationContext private val context: Context
) : ViewModel() {

    private val dataStore = context.appDataStore
    private val _isApplying = MutableStateFlow<String?>(null)
    private val _lastResult = MutableStateFlow<String?>(null)

    val state: StateFlow<OptimizationState> = combine(
        dataStore.snapshotFlow(),
        _isApplying,
        _lastResult
    ) { snapshot, applying, result ->
        OptimizationState(
            framePacing = snapshot.optimFramePacing,
            goodPing = snapshot.optimGoodPing,
            perfExt = snapshot.optimPerfExt,
            runtimeControl = snapshot.optimRuntimeControl,
            gamePulse = snapshot.optimGamePulse,
            gpuBoost = snapshot.optimGpuBoost,
            audioTuning = snapshot.optimAudioTuning,
            hyperPerf = snapshot.optimHyperPerf,
            isApplying = applying,
            lastResult = result
        )
    }.stateIn(
        viewModelScope,
        SharingStarted.Eagerly,
        OptimizationState()
    )

    fun toggleModule(moduleId: String, enable: Boolean) {
        val module = OptimizationModule.fromId(moduleId) ?: return
        viewModelScope.launch {
            _isApplying.value = moduleId
            val success = withContext(Dispatchers.IO) {
                if (enable) {
                    OptimizationExecutor.applyModule(context, module)
                } else {
                    OptimizationExecutor.disableModule(context, module)
                }
            }
            _lastResult.value = if (success) {
                "${module.name}: ${if (enable) "enabled" else "disabled"}"
            } else {
                "${module.name}: failed"
            }
            _isApplying.value = null
            if (success) {
                dataStore.updateSnapshot { snapshot ->
                    when (moduleId) {
                        "frame_pacing" -> snapshot.copy(optimFramePacing = enable)
                        "good_ping" -> snapshot.copy(optimGoodPing = enable)
                        "perf_ext" -> snapshot.copy(optimPerfExt = enable)
                        "runtime_control" -> snapshot.copy(optimRuntimeControl = enable)
                        "game_pulse" -> snapshot.copy(optimGamePulse = enable)
                        "gpu_boost" -> snapshot.copy(optimGpuBoost = enable)
                        "audio_tuning" -> snapshot.copy(optimAudioTuning = enable)
                        "hyper_perf" -> snapshot.copy(optimHyperPerf = enable)
                        else -> snapshot
                    }
                }
            }
        }
    }
}
