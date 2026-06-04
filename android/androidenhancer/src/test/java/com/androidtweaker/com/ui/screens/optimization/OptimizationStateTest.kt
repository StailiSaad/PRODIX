package com.androidtweaker.com.ui.screens.optimization

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OptimizationStateTest {

    @Test
    fun `default state has all modules disabled`() {
        val state = OptimizationState()
        assertFalse(state.framePacing)
        assertFalse(state.goodPing)
        assertFalse(state.perfExt)
        assertFalse(state.runtimeControl)
        assertFalse(state.gamePulse)
        assertFalse(state.gpuBoost)
        assertFalse(state.audioTuning)
        assertFalse(state.hyperPerf)
    }

    @Test
    fun `default state has no applying, no result, no log`() {
        val state = OptimizationState()
        assertEquals(null, state.isApplying)
        assertEquals(null, state.lastResult)
        assertTrue(state.liveLog.isEmpty())
        assertFalse(state.showAdbGrantDialog)
    }

    @Test
    fun `isEnabled returns correct value for each module`() {
        val state = OptimizationState(
            framePacing = true,
            goodPing = false,
            perfExt = true,
            runtimeControl = false,
            gamePulse = true,
            gpuBoost = false,
            audioTuning = true,
            hyperPerf = false
        )

        assertTrue(state.isEnabled("frame_pacing"))
        assertFalse(state.isEnabled("good_ping"))
        assertTrue(state.isEnabled("perf_ext"))
        assertFalse(state.isEnabled("runtime_control"))
        assertTrue(state.isEnabled("game_pulse"))
        assertFalse(state.isEnabled("gpu_boost"))
        assertTrue(state.isEnabled("audio_tuning"))
        assertFalse(state.isEnabled("hyper_perf"))
    }

    @Test
    fun `isEnabled returns false for unknown module`() {
        val state = OptimizationState()
        assertFalse(state.isEnabled("unknown_module"))
        assertFalse(state.isEnabled(""))
    }

    @Test
    fun `withToggled returns new instance without mutating original`() {
        val original = OptimizationState()
        val toggled = original.withToggled("frame_pacing", true)

        assertFalse(original.framePacing)
        assertTrue(toggled.framePacing)
    }

    @Test
    fun `withToggled toggles each module correctly`() {
        val state = OptimizationState()

        val testCases = listOf(
            "frame_pacing" to OptimizationState::framePacing,
            "good_ping" to OptimizationState::goodPing,
            "perf_ext" to OptimizationState::perfExt,
            "runtime_control" to OptimizationState::runtimeControl,
            "game_pulse" to OptimizationState::gamePulse,
            "gpu_boost" to OptimizationState::gpuBoost,
            "audio_tuning" to OptimizationState::audioTuning,
            "hyper_perf" to OptimizationState::hyperPerf
        )

        for ((id, prop) in testCases) {
            val result = state.withToggled(id, true)
            assertTrue("Module $id should be enabled", prop.get(result))
        }
    }

    @Test
    fun `withToggled returns same instance for unknown module`() {
        val state = OptimizationState()
        val result = state.withToggled("unknown", true)
        assertEquals(state, result)
    }

    @Test
    fun `copy creates independent instance`() {
        val state1 = OptimizationState(framePacing = true, lastResult = "OK")
        val state2 = state1.copy(lastResult = null)

        assertTrue(state1.framePacing)
        assertEquals("OK", state1.lastResult)
        assertFalse(state2.framePacing)
        assertEquals(null, state2.lastResult)
    }
}
