package io.github.iamlooper.androidenhancer.ui.screens.optimization

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import io.github.iamlooper.androidenhancer.data.local.appDataStore
import io.github.iamlooper.androidenhancer.data.local.snapshotFlow
import io.github.iamlooper.androidenhancer.data.local.updateSnapshot
import io.github.iamlooper.androidenhancer.system.optimization.ExecuteResult
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
import java.io.File
import javax.inject.Inject

@HiltViewModel
class OptimizationViewModel @Inject constructor(
    @param:ApplicationContext private val context: Context
) : ViewModel() {

    private val dataStore = context.appDataStore
    private val _isApplying = MutableStateFlow<String?>(null)
    private val _lastResult = MutableStateFlow<String?>(null)
    private val _liveLog = MutableStateFlow<List<String>>(emptyList())
    private val _showAdbGrantDialog = MutableStateFlow(false)
    private var adbDialogDismissed = false
    private var adbGrantActive = false

    init {
        viewModelScope.launch(Dispatchers.IO) {
            adbGrantActive = testAdbGrant()
        }
    }

    val state: StateFlow<OptimizationState> = combine(
        dataStore.snapshotFlow(),
        _isApplying,
        _lastResult,
        _liveLog,
        _showAdbGrantDialog
    ) { snapshot, applying, result, log, showAdb ->
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
            lastResult = result,
            liveLog = log,
            showAdbGrantDialog = showAdb
        )
    }.stateIn(
        viewModelScope,
        SharingStarted.Eagerly,
        OptimizationState()
    )

    fun dismissAdbGrantDialog() {
        adbDialogDismissed = true
        _showAdbGrantDialog.value = false
    }

    fun confirmAdbGrantApplied() {
        adbDialogDismissed = true
        adbGrantActive = true
        _showAdbGrantDialog.value = false
    }

    private fun testAdbGrant(): Boolean {
        return try {
            val script = File(context.cacheDir, "adb_test_${System.nanoTime()}.sh")
            script.writeText("#!/system/bin/sh\nsettings put global test_adb_perm 1 2>/dev/null; echo EXIT:\$?\nsettings delete global test_adb_perm 2>/dev/null")
            script.setExecutable(true)
            val proc = ProcessBuilder("sh", script.absolutePath)
                .redirectErrorStream(true)
                .start()
            val output = proc.inputStream.bufferedReader().readText()
            script.delete()
            output.contains("EXIT:0")
        } catch (_: Exception) {
            false
        }
    }

    fun toggleModule(moduleId: String, enable: Boolean) {
        val module = OptimizationModule.fromId(moduleId) ?: return
        viewModelScope.launch {
            _isApplying.value = moduleId
            _liveLog.value = emptyList()
            _lastResult.value = null
            _showAdbGrantDialog.value = false

            val outputLines = mutableListOf<String>()
            val execResult: ExecuteResult = withContext(Dispatchers.IO) {
                val onOutput: (String) -> Unit = { line ->
                    outputLines.add(line)
                    _liveLog.value = outputLines.toList()
                }
                if (enable) {
                    OptimizationExecutor.applyModule(context, module, onOutput)
                } else {
                    OptimizationExecutor.disableModule(context, module, onOutput)
                }
            }

            val successCount = execResult.results.count { it.success }
            val totalCount = execResult.results.size
            _lastResult.value = "${module.name}: $successCount/$totalCount commandes OK"
            _isApplying.value = null

            if (!execResult.success && !adbGrantActive && !adbDialogDismissed) {
                _showAdbGrantDialog.value = true
            }

            // Always save the toggle state (user intent).
            // The live log shows which commands actually succeeded/failed.
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
