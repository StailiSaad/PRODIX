package com.androidtweaker.com.system.optimization

import android.content.Context
import java.io.File
import java.io.InputStream

object OptimizationExecutor {

    fun applyModule(context: Context, module: OptimizationModule, onOutput: ((String) -> Unit)? = null): ExecuteResult {
        return executeScript(context, module.activeScript, onOutput)
    }

    fun disableModule(context: Context, module: OptimizationModule, onOutput: ((String) -> Unit)? = null): ExecuteResult {
        return executeScript(context, module.disableScript, onOutput)
    }

    private val CMD_PREFIXES = listOf("setprop ", "settings ", "device_config ", "cmd ")

    private fun shizukuExecLines(cmd: Array<String>): List<String>? {
        return try {
            val shizukuClass = Class.forName("rikka.shizuku.Shizuku")
            val method = shizukuClass.getDeclaredMethod("newProcess",
                Array<String>::class.java, Array<String>::class.java, String::class.java)
            method.isAccessible = true
            val remote = method.invoke(null, cmd, null, null)
            val cls = remote::class.java
            val input = cls.getMethod("getInputStream").invoke(remote) as InputStream
            val error = cls.getMethod("getErrorStream").invoke(remote) as InputStream
            val merged = input.bufferedReader().readLines() + error.bufferedReader().readLines()
            cls.getMethod("waitFor").invoke(remote)
            merged
        } catch (_: Exception) {
            null
        }
    }

    private fun executeScript(context: Context, script: String, onOutput: ((String) -> Unit)? = null): ExecuteResult {
        return try {
            val tempScript = File(context.cacheDir, "optim_script_${System.nanoTime()}.sh")

            // Build enhanced script:
            // - For real modification commands → capture exit code per command
            // - For everything else (echo, assignments, control flow) → pass through
            val enhancedScript = buildString {
                appendLine("#!/system/bin/sh")
                script.lines().forEach { line ->
                    val trimmed = line.trim()
                    when {
                        trimmed.isEmpty() || trimmed.startsWith("#") -> appendLine(trimmed)
                        trimmed.startsWith("echo ") -> appendLine(trimmed)
                        isModificationCommand(trimmed) -> {
                            val summary = summarize(trimmed)
                            appendLine("echo \"→ $summary\"")
                            appendLine("${trimmed.replace(" 2>/dev/null", " 2>&1")}; echo \"⟐EXIT:\$?\"")
                        }
                        else -> appendLine(trimmed)
                    }
                }
            }

            tempScript.writeText(enhancedScript)
            tempScript.setExecutable(true)

            val shizukuLines = shizukuExecLines(arrayOf("sh", tempScript.absolutePath))

            if (shizukuLines != null) {
                val lines = shizukuLines
                tempScript.delete()
                return parseOutputLines(lines, onOutput)
            }

            val process = ProcessBuilder("sh", tempScript.absolutePath)
                    .redirectErrorStream(true)
                    .start()

            val results = mutableListOf<CommandResult>()
            val streamLines = mutableListOf<String>()

            process.inputStream.bufferedReader().use { reader ->
                reader.lineSequence().forEach { line ->
                    streamLines.add(line)
                }
            }
            process.waitFor()
            tempScript.delete()
            return parseOutputLines(streamLines, onOutput)
        } catch (e: Exception) {
            onOutput?.invoke("Error: ${e.message}")
            ExecuteResult(success = false, results = listOf(CommandResult("Script execution", false, -1)))
        }
    }

    private fun parseOutputLines(lines: List<String>, onOutput: ((String) -> Unit)?): ExecuteResult {
        val results = mutableListOf<CommandResult>()
        var currentSummary: String? = null
        var anyFailed = false

        lines.forEach { line ->
            when {
                line.startsWith("→ ") -> {
                    currentSummary = line.removePrefix("→ ")
                    onOutput?.invoke(line)
                }
                line.startsWith("⟐EXIT:") -> {
                    val code = line.removePrefix("⟐EXIT:").toIntOrNull() ?: 1
                    val ok = code == 0
                    val summary = currentSummary ?: "unknown"
                    results.add(CommandResult(summary, ok, code))
                    currentSummary = null
                    if (!ok) anyFailed = true
                    val status = if (ok) "✓" else "✗"
                    onOutput?.invoke("  $status $summary")
                }
                else -> onOutput?.invoke(line)
            }
        }
        return ExecuteResult(success = !anyFailed, results = results)
    }

    private fun isModificationCommand(cmd: String): Boolean =
        cmd.endsWith(" 2>/dev/null") && CMD_PREFIXES.any { cmd.startsWith(it) }

    private fun summarize(cmd: String): String {
        val clean = cmd.removeSuffix(" 2>/dev/null").trimEnd()
        return when {
            cmd.startsWith("setprop ") -> {
                val prop = clean.removePrefix("setprop ").substringBefore(" ")
                "Setting $prop …"
            }
            cmd.startsWith("settings put global ") -> {
                val key = clean.removePrefix("settings put global ").substringBefore(" ")
                "Setting global $key …"
            }
            cmd.startsWith("settings put system ") -> {
                val key = clean.removePrefix("settings put system ").substringBefore(" ")
                "Setting system $key …"
            }
            cmd.startsWith("settings put secure ") -> {
                val key = clean.removePrefix("settings put secure ").substringBefore(" ")
                "Setting secure $key …"
            }
            cmd.startsWith("settings delete ") -> {
                val key = clean.removePrefix("settings delete ").trimEnd()
                "Resetting $key …"
            }
            cmd.startsWith("device_config put ") -> {
                val key = clean.removePrefix("device_config put ").substringBefore(" ")
                "Configuring $key …"
            }
            cmd.startsWith("device_config delete ") -> {
                val key = clean.removePrefix("device_config delete ").substringBefore(" ")
                "Resetting device_config $key …"
            }
            cmd.startsWith("cmd ") -> "Running system command …"
            else -> clean.take(50) + if (clean.length > 50) "…" else ""
        }
    }
}

data class ExecuteResult(val success: Boolean, val results: List<CommandResult>)
data class CommandResult(val summary: String, val success: Boolean, val exitCode: Int)

private fun sh(vararg lines: String): String = lines.joinToString("\n").replace("§", "$")

data class OptimizationModule(
    val id: String,
    val name: String,
    val description: String,
    val iconPlaceholder: String,
    val activeScript: String,
    val disableScript: String
) {
    companion object {
        val FRAME_PACING = OptimizationModule(
            id = "frame_pacing",
            name = "Frame Pacing",
            description = "Optimize display frame pacing and SurfaceFlinger phase offsets for smoother UI",
            iconPlaceholder = "ic_bolt",
            activeScript = sh(
                """FPS=§(dumpsys display 2>/dev/null | grep -m1 'fps' | grep -oE '[0-9]+(\\.[0-9]+)?' | head -1)""",
                """if [ -z "§FPS" ] || [ "§FPS" = "0" ]; then FPS=60; fi""",
                """FPS=§{FPS%.*}""",
                """NS=§((1000000000 / FPS))""",
                """APP_DUR=§((NS * 95 / 100))""",
                """SF_DUR=§((NS * 85 / 100))""",
                """APP_PHASE=-§APP_DUR""",
                """SF_PHASE=-§SF_DUR""",
                """setprop debug.sf.early_app_duration §APP_DUR 2>/dev/null""",
                """setprop debug.sf.early_sf_duration §SF_DUR 2>/dev/null""",
                """setprop debug.sf.early_app_phase_offset §APP_PHASE 2>/dev/null""",
                """setprop debug.sf.early_sf_phase_offset §SF_PHASE 2>/dev/null""",
                """setprop debug.sf.early_gl_app_duration §APP_DUR 2>/dev/null""",
                """setprop debug.sf.early_gl_sf_duration §SF_DUR 2>/dev/null""",
                """setprop debug.sf.early_gl_app_phase_offset §APP_PHASE 2>/dev/null""",
                """setprop debug.sf.early_gl_sf_phase_offset §SF_PHASE 2>/dev/null""",
                """setprop debug.sf.default_refresh_rate 1 2>/dev/null""",
                """setprop debug.choreographer.frametime §NS 2>/dev/null""",
                """setprop vendor.display.poweron_vrefresh §FPS 2>/dev/null""",
                """echo "FramePacing: applied for §{FPS}Hz""""
            ),
            disableScript = sh(
                """setprop debug.sf.early_app_duration "" 2>/dev/null""",
                """setprop debug.sf.early_sf_duration "" 2>/dev/null""",
                """setprop debug.sf.early_app_phase_offset "" 2>/dev/null""",
                """setprop debug.sf.early_sf_phase_offset "" 2>/dev/null""",
                """setprop debug.sf.early_gl_app_duration "" 2>/dev/null""",
                """setprop debug.sf.early_gl_sf_duration "" 2>/dev/null""",
                """setprop debug.sf.early_gl_app_phase_offset "" 2>/dev/null""",
                """setprop debug.sf.early_gl_sf_phase_offset "" 2>/dev/null""",
                """setprop debug.sf.default_refresh_rate "" 2>/dev/null""",
                """setprop debug.choreographer.frametime "" 2>/dev/null""",
                """setprop vendor.display.poweron_vrefresh "" 2>/dev/null""",
                """echo "FramePacing: disabled""""
            )
        )

        val GOOD_PING = OptimizationModule(
            id = "good_ping",
            name = "GoodPing",
            description = "Optimize network DNS, TCP buffers, and connectivity for lower latency",
            iconPlaceholder = "ic_bolt",
            activeScript = sh(
                """setprop net.dns1 8.8.8.8 2>/dev/null""",
                """setprop net.dns2 8.8.4.4 2>/dev/null""",
                """setprop dhcp.wlan0.dns1 8.8.8.8 2>/dev/null""",
                """setprop dhcp.wlan0.dns2 8.8.4.4 2>/dev/null""",
                """settings put global tcp_congestion_control bbr 2>/dev/null""",
                """settings put global wifi_scan_always_enabled 0 2>/dev/null""",
                """settings put global wifi_power_save 0 2>/dev/null""",
                """settings put global wifi_suspend_optimizations_enabled 0 2>/dev/null""",
                """settings put global mobile_data_always_on 0 2>/dev/null""",
                """settings put global wifi_fast_bss_transition_enabled 1 2>/dev/null""",
                """settings put global network_avoid_bad_wifi 1 2>/dev/null""",
                """settings put global captive_portal_mode 0 2>/dev/null""",
                """settings put global captive_portal_detection_enabled 0 2>/dev/null""",
                """settings put secure wifi_country_code US 2>/dev/null""",
                """cmd wifi set-wifi-enabled enabled 2>/dev/null""",
                """cmd connectivity airplane-mode disable 2>/dev/null""",
                """echo "GoodPing: network optimized""""
            ),
            disableScript = sh(
                """setprop net.dns1 "" 2>/dev/null""",
                """setprop net.dns2 "" 2>/dev/null""",
                """setprop dhcp.wlan0.dns1 "" 2>/dev/null""",
                """setprop dhcp.wlan0.dns2 "" 2>/dev/null""",
                """settings delete global tcp_congestion_control 2>/dev/null""",
                """settings delete global wifi_scan_always_enabled 2>/dev/null""",
                """settings delete global wifi_power_save 2>/dev/null""",
                """settings delete global wifi_suspend_optimizations_enabled 2>/dev/null""",
                """settings delete global mobile_data_always_on 2>/dev/null""",
                """settings delete global wifi_fast_bss_transition_enabled 2>/dev/null""",
                """settings delete global network_avoid_bad_wifi 2>/dev/null""",
                """settings delete global captive_portal_mode 2>/dev/null""",
                """settings delete global captive_portal_detection_enabled 2>/dev/null""",
                """settings delete secure wifi_country_code 2>/dev/null""",
                """echo "GoodPing: disabled""""
            )
        )

        val PERF_EXT = OptimizationModule(
            id = "perf_ext",
            name = "PerfExt",
            description = "GPU rendering forcing, power mode, animation speed, and device_config optimizations",
            iconPlaceholder = "ic_bolt",
            activeScript = sh(
                """settings put global force_gpu_rendering 1 2>/dev/null""",
                """settings put global power_save_mode 0 2>/dev/null""",
                """settings put global sustained_performance_mode 1 2>/dev/null""",
                """settings put global hwui.disable_msaa true 2>/dev/null""",
                """settings put global battery_saver_const_enabled false 2>/dev/null""",
                """settings put system window_animation_scale 0 2>/dev/null""",
                """settings put system transition_animation_scale 0 2>/dev/null""",
                """settings put system animator_duration_scale 0 2>/dev/null""",
                """settings put system font_weight_adjustment 900 2>/dev/null""",
                """settings put system screen_off_timeout 1800000 2>/dev/null""",
                """setprop debug.hwui.renderer skiavk 2>/dev/null""",
                """setprop debug.composition.type gpu 2>/dev/null""",
                """setprop persist.sys.composition.type gpu 2>/dev/null""",
                """setprop debug.sf.hw 1 2>/dev/null""",
                """setprop video.accelerate.hw 1 2>/dev/null""",
                """setprop debug.performance.tuning 1 2>/dev/null""",
                """setprop profiler.force_disable_err_rpt 1 2>/dev/null""",
                """setprop profiler.force_disable_ulog 1 2>/dev/null""",
                """device_config put activity_manager max_phantom_processes 1024 2>/dev/null""",
                """device_config put runtime_native use_svelte false 2>/dev/null""",
                """device_config put surface_flinger_native_boot force_gpu true 2>/dev/null""",
                """device_config put surface_flinger_native_boot use_max_frame_rate true 2>/dev/null""",
                """device_config put core_graphics force_gpu true 2>/dev/null""",
                """device_config put core_graphics use_skia true 2>/dev/null""",
                """device_config put display_manager peak_refresh_rate 120 2>/dev/null""",
                """device_config put display_manager refresh_rate 120 2>/dev/null""",
                """cmd power set-fixed-performance-mode-enabled true 2>/dev/null""",
                """echo "PerfExt: applied""""
            ),
            disableScript = sh(
                """settings delete global force_gpu_rendering 2>/dev/null""",
                """settings delete global power_save_mode 2>/dev/null""",
                """settings delete global sustained_performance_mode 2>/dev/null""",
                """settings delete global hwui.disable_msaa 2>/dev/null""",
                """settings delete global battery_saver_const_enabled 2>/dev/null""",
                """settings delete system window_animation_scale 2>/dev/null""",
                """settings delete system transition_animation_scale 2>/dev/null""",
                """settings delete system animator_duration_scale 2>/dev/null""",
                """settings delete system font_weight_adjustment 2>/dev/null""",
                """settings delete system screen_off_timeout 2>/dev/null""",
                """setprop debug.hwui.renderer "" 2>/dev/null""",
                """setprop debug.composition.type "" 2>/dev/null""",
                """setprop persist.sys.composition.type "" 2>/dev/null""",
                """setprop debug.sf.hw "" 2>/dev/null""",
                """setprop video.accelerate.hw "" 2>/dev/null""",
                """setprop debug.performance.tuning "" 2>/dev/null""",
                """setprop profiler.force_disable_err_rpt "" 2>/dev/null""",
                """setprop profiler.force_disable_ulog "" 2>/dev/null""",
                """device_config delete activity_manager max_phantom_processes 2>/dev/null""",
                """device_config delete runtime_native use_svelte 2>/dev/null""",
                """device_config delete surface_flinger_native_boot force_gpu 2>/dev/null""",
                """device_config delete surface_flinger_native_boot use_max_frame_rate 2>/dev/null""",
                """device_config delete core_graphics force_gpu 2>/dev/null""",
                """device_config delete core_graphics use_skia 2>/dev/null""",
                """device_config delete display_manager peak_refresh_rate 2>/dev/null""",
                """device_config delete display_manager refresh_rate 2>/dev/null""",
                """cmd power set-fixed-performance-mode-enabled false 2>/dev/null""",
                """echo "PerfExt: disabled""""
            )
        )

        val RUNTIME_CONTROL = OptimizationModule(
            id = "runtime_control",
            name = "Runtime Control",
            description = "Disable doze, app standby, thermal throttling, and background restrictions",
            iconPlaceholder = "ic_bolt",
            activeScript = sh(
                """settings put global app_standby_enabled 0 2>/dev/null""",
                """settings put global forced_app_standby_enabled 0 2>/dev/null""",
                """settings put global background_check_enabled 0 2>/dev/null""",
                """settings put global adaptive_battery_management_enabled 0 2>/dev/null""",
                """settings put global cached_apps_freezer_enabled 0 2>/dev/null""",
                """settings put global doze_enabled 0 2>/dev/null""",
                """settings put global wifi_scan_throttle_enabled 0 2>/dev/null""",
                """settings put global wifi_scan_background_throttle_interval 0 2>/dev/null""",
                """settings put global ble_scan_background_throttle 0 2>/dev/null""",
                """settings put secure thermal_service disabled 2>/dev/null""",
                """settings put secure thermal_throttle disabled 2>/dev/null""",
                """settings put secure thermal_control disabled 2>/dev/null""",
                """settings put secure therapeutic_mode 0 2>/dev/null""",
                """settings put secure overheating_detection 0 2>/dev/null""",
                """settings put system window_animation_scale 0 2>/dev/null""",
                """settings put system transition_animation_scale 0 2>/dev/null""",
                """settings put system animator_duration_scale 0 2>/dev/null""",
                """settings put system font_weight_adjustment 1000 2>/dev/null""",
                """device_config put core_graphics force_gpu true 2>/dev/null""",
                """device_config put core_graphics skip_window_blur true 2>/dev/null""",
                """device_config put display_manager peak_refresh_rate 120 2>/dev/null""",
                """device_config put display_manager refresh_rate 120 2>/dev/null""",
                """device_config put activity_manager max_phantom_processes 1024 2>/dev/null""",
                """cmd notification set_zen_mode 0 2>/dev/null""",
                """cmd power set-adaptive-power-saver enabled false 2>/dev/null""",
                """cmd power set-fixed-performance-mode-enabled true 2>/dev/null""",
                """echo "RuntimeControl: applied""""
            ),
            disableScript = sh(
                """settings delete global app_standby_enabled 2>/dev/null""",
                """settings delete global forced_app_standby_enabled 2>/dev/null""",
                """settings delete global background_check_enabled 2>/dev/null""",
                """settings delete global adaptive_battery_management_enabled 2>/dev/null""",
                """settings delete global cached_apps_freezer_enabled 2>/dev/null""",
                """settings delete global doze_enabled 2>/dev/null""",
                """settings delete global wifi_scan_throttle_enabled 2>/dev/null""",
                """settings delete global wifi_scan_background_throttle_interval 2>/dev/null""",
                """settings delete global ble_scan_background_throttle 2>/dev/null""",
                """settings delete secure thermal_service 2>/dev/null""",
                """settings delete secure thermal_throttle 2>/dev/null""",
                """settings delete secure thermal_control 2>/dev/null""",
                """settings delete secure therapeutic_mode 2>/dev/null""",
                """settings delete secure overheating_detection 2>/dev/null""",
                """settings delete system window_animation_scale 2>/dev/null""",
                """settings delete system transition_animation_scale 2>/dev/null""",
                """settings delete system animator_duration_scale 2>/dev/null""",
                """settings delete system font_weight_adjustment 2>/dev/null""",
                """device_config delete core_graphics force_gpu 2>/dev/null""",
                """device_config delete core_graphics skip_window_blur 2>/dev/null""",
                """device_config delete display_manager peak_refresh_rate 2>/dev/null""",
                """device_config delete display_manager refresh_rate 2>/dev/null""",
                """device_config delete activity_manager max_phantom_processes 2>/dev/null""",
                """cmd notification set_zen_mode 1 2>/dev/null""",
                """cmd power set-adaptive-power-saver enabled true 2>/dev/null""",
                """cmd power set-fixed-performance-mode-enabled false 2>/dev/null""",
                """echo "RuntimeControl: disabled""""
            )
        )

        val GAME_PULSE = OptimizationModule(
            id = "game_pulse",
            name = "GamePulse",
            description = "Enable game mode overlay, GPU driver optimization, and high FPS mode",
            iconPlaceholder = "ic_bolt",
            activeScript = sh(
                """settings put global game_mode_overlay 1 2>/dev/null""",
                """settings put global game_driver 1 2>/dev/null""",
                """settings put global game_driver_opt 1 2>/dev/null""",
                """settings put global game_default_frame_rate 120 2>/dev/null""",
                """settings put global background_restriction 1 2>/dev/null""",
                """cmd game set --mode 1 --angle 1 --fps 120 2>/dev/null""",
                """cmd power set-fixed-performance-mode-enabled true 2>/dev/null""",
                """echo "GamePulse: applied""""
            ),
            disableScript = sh(
                """settings delete global game_mode_overlay 2>/dev/null""",
                """settings delete global game_driver 2>/dev/null""",
                """settings delete global game_driver_opt 2>/dev/null""",
                """settings delete global game_default_frame_rate 2>/dev/null""",
                """settings delete global background_restriction 2>/dev/null""",
                """cmd game set --mode 0 --angle 0 --fps 60 2>/dev/null""",
                """cmd power set-fixed-performance-mode-enabled false 2>/dev/null""",
                """echo "GamePulse: disabled""""
            )
        )

        val GPU_BOOST = OptimizationModule(
            id = "gpu_boost",
            name = "GPU Boost",
            description = "Force GPU rendering, Skia/Vulkan backend, and hardware composition",
            iconPlaceholder = "ic_bolt",
            activeScript = sh(
                """setprop debug.hwui.renderer skiavk 2>/dev/null""",
                """setprop debug.composition.type gpu 2>/dev/null""",
                """setprop persist.sys.composition.type gpu 2>/dev/null""",
                """setprop debug.sf.hw 1 2>/dev/null""",
                """setprop video.accelerate.hw 1 2>/dev/null""",
                """setprop debug.performance.tuning 1 2>/dev/null""",
                """setprop hwui.disable_vsync false 2>/dev/null""",
                """settings put global force_gpu_rendering 1 2>/dev/null""",
                """settings put global hwui.disable_msaa true 2>/dev/null""",
                """settings put global show_gpu_overlay_dialog 0 2>/dev/null""",
                """settings put system window_animation_scale 0.5 2>/dev/null""",
                """settings put system transition_animation_scale 0.5 2>/dev/null""",
                """settings put system animator_duration_scale 0.5 2>/dev/null""",
                """device_config put core_graphics force_vulkan true 2>/dev/null""",
                """device_config put core_graphics disable_hardware_overlays false 2>/dev/null""",
                """echo "GPU Boost: applied""""
            ),
            disableScript = sh(
                """setprop debug.hwui.renderer "" 2>/dev/null""",
                """setprop debug.composition.type "" 2>/dev/null""",
                """setprop persist.sys.composition.type "" 2>/dev/null""",
                """setprop debug.sf.hw "" 2>/dev/null""",
                """setprop video.accelerate.hw "" 2>/dev/null""",
                """setprop debug.performance.tuning "" 2>/dev/null""",
                """setprop hwui.disable_vsync "" 2>/dev/null""",
                """settings delete global force_gpu_rendering 2>/dev/null""",
                """settings delete global hwui.disable_msaa 2>/dev/null""",
                """settings delete global show_gpu_overlay_dialog 2>/dev/null""",
                """settings delete system window_animation_scale 2>/dev/null""",
                """settings delete system transition_animation_scale 2>/dev/null""",
                """settings delete system animator_duration_scale 2>/dev/null""",
                """device_config delete core_graphics force_vulkan 2>/dev/null""",
                """device_config delete core_graphics disable_hardware_overlays 2>/dev/null""",
                """echo "GPU Boost: disabled""""
            )
        )

        val AUDIO_TUNING = OptimizationModule(
            id = "audio_tuning",
            name = "Audio Tuning",
            description = "Optimize audio flinger for lower latency and cleaner output",
            iconPlaceholder = "ic_bolt",
            activeScript = sh(
                """setprop persist.audio.fluence.voicecall true 2>/dev/null""",
                """setprop persist.audio.fluence.voicerec true 2>/dev/null""",
                """setprop persist.audio.fluence.speaker true 2>/dev/null""",
                """setprop audio.deep_buffer.force true 2>/dev/null""",
                """setprop af.fast_track_multiplier 2 2>/dev/null""",
                """setprop audio.offload.disable 0 2>/dev/null""",
                """settings put global audio_safemedia_behavior 0 2>/dev/null""",
                """echo "Audio Tuning: applied""""
            ),
            disableScript = sh(
                """setprop persist.audio.fluence.voicecall "" 2>/dev/null""",
                """setprop persist.audio.fluence.voicerec "" 2>/dev/null""",
                """setprop persist.audio.fluence.speaker "" 2>/dev/null""",
                """setprop audio.deep_buffer.force "" 2>/dev/null""",
                """setprop af.fast_track_multiplier "" 2>/dev/null""",
                """setprop audio.offload.disable "" 2>/dev/null""",
                """settings delete global audio_safemedia_behavior 2>/dev/null""",
                """echo "Audio Tuning: disabled""""
            )
        )

        val HYPER_PERF = OptimizationModule(
            id = "hyper_perf",
            name = "Hyper Performance",
            description = "Comprehensive CPU, GPU, memory, and I/O performance tuning",
            iconPlaceholder = "ic_bolt",
            activeScript = sh(
                """settings put global force_gpu_rendering 1 2>/dev/null""",
                """settings put global power_save_mode 0 2>/dev/null""",
                """settings put global sustained_performance_mode 1 2>/dev/null""",
                """settings put global app_standby_enabled 0 2>/dev/null""",
                """settings put global cached_apps_freezer_enabled 0 2>/dev/null""",
                """settings put global doze_enabled 0 2>/dev/null""",
                """settings put global adaptive_battery_management_enabled 0 2>/dev/null""",
                """settings put global background_restriction 0 2>/dev/null""",
                """settings put system window_animation_scale 0 2>/dev/null""",
                """settings put system transition_animation_scale 0 2>/dev/null""",
                """settings put system animator_duration_scale 0 2>/dev/null""",
                """setprop debug.hwui.renderer skiavk 2>/dev/null""",
                """setprop debug.composition.type gpu 2>/dev/null""",
                """setprop debug.sf.hw 1 2>/dev/null""",
                """setprop video.accelerate.hw 1 2>/dev/null""",
                """setprop debug.performance.tuning 1 2>/dev/null""",
                """setprop profiler.force_disable_err_rpt 1 2>/dev/null""",
                """setprop profiler.force_disable_ulog 1 2>/dev/null""",
                """device_config put activity_manager max_phantom_processes 1024 2>/dev/null""",
                """device_config put runtime_native use_svelte false 2>/dev/null""",
                """device_config put surface_flinger_native_boot force_gpu true 2>/dev/null""",
                """device_config put surface_flinger_native_boot use_max_frame_rate true 2>/dev/null""",
                """device_config put core_graphics force_gpu true 2>/dev/null""",
                """device_config put core_graphics use_skia true 2>/dev/null""",
                """device_config put display_manager peak_refresh_rate 120 2>/dev/null""",
                """device_config put display_manager refresh_rate 120 2>/dev/null""",
                """device_config put lmkd_native min_gpu_mem 0 2>/dev/null""",
                """cmd power set-fixed-performance-mode-enabled true 2>/dev/null""",
                """echo "HyperPerf: applied""""
            ),
            disableScript = sh(
                """settings delete global force_gpu_rendering 2>/dev/null""",
                """settings delete global power_save_mode 2>/dev/null""",
                """settings delete global sustained_performance_mode 2>/dev/null""",
                """settings delete global app_standby_enabled 2>/dev/null""",
                """settings delete global cached_apps_freezer_enabled 2>/dev/null""",
                """settings delete global doze_enabled 2>/dev/null""",
                """settings delete global adaptive_battery_management_enabled 2>/dev/null""",
                """settings delete global background_restriction 2>/dev/null""",
                """settings delete system window_animation_scale 2>/dev/null""",
                """settings delete system transition_animation_scale 2>/dev/null""",
                """settings delete system animator_duration_scale 2>/dev/null""",
                """setprop debug.hwui.renderer "" 2>/dev/null""",
                """setprop debug.composition.type "" 2>/dev/null""",
                """setprop debug.sf.hw "" 2>/dev/null""",
                """setprop video.accelerate.hw "" 2>/dev/null""",
                """setprop debug.performance.tuning "" 2>/dev/null""",
                """setprop profiler.force_disable_err_rpt "" 2>/dev/null""",
                """setprop profiler.force_disable_ulog "" 2>/dev/null""",
                """device_config delete activity_manager max_phantom_processes 2>/dev/null""",
                """device_config delete runtime_native use_svelte 2>/dev/null""",
                """device_config delete surface_flinger_native_boot force_gpu 2>/dev/null""",
                """device_config delete surface_flinger_native_boot use_max_frame_rate 2>/dev/null""",
                """device_config delete core_graphics force_gpu 2>/dev/null""",
                """device_config delete core_graphics use_skia 2>/dev/null""",
                """device_config delete display_manager peak_refresh_rate 2>/dev/null""",
                """device_config delete display_manager refresh_rate 2>/dev/null""",
                """device_config delete lmkd_native min_gpu_mem 2>/dev/null""",
                """cmd power set-fixed-performance-mode-enabled false 2>/dev/null""",
                """echo "HyperPerf: disabled""""
            )
        )

        val ALL = listOf(
            FRAME_PACING, GOOD_PING, PERF_EXT, RUNTIME_CONTROL,
            GAME_PULSE, GPU_BOOST, AUDIO_TUNING, HYPER_PERF
        )

        fun fromId(id: String): OptimizationModule? = ALL.find { it.id == id }
    }
}
