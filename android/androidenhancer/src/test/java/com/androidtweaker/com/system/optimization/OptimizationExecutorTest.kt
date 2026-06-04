package com.androidtweaker.com.system.optimization

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OptimizationExecutorTest {

    @Test
    fun `OptimizationModule ALL contains all 8 modules`() {
        assertEquals(8, OptimizationModule.ALL.size)
    }

    @Test
    fun `OptimizationModule ALL has no duplicate IDs`() {
        val ids = OptimizationModule.ALL.map { it.id }
        assertEquals(ids.size, ids.distinct().size)
    }

    @Test
    fun `fromId finds module by id`() {
        val module = OptimizationModule.fromId("frame_pacing")
        assertTrue(module != null)
        assertEquals("Frame Pacing", module?.name)
    }

    @Test
    fun `fromId returns null for unknown id`() {
        assertEquals(null, OptimizationModule.fromId("unknown"))
        assertEquals(null, OptimizationModule.fromId(""))
    }

    @Test
    fun `all modules have non-empty name and description`() {
        for (module in OptimizationModule.ALL) {
            assertTrue("Module ${module.id} should have non-empty name", module.name.isNotEmpty())
            assertTrue("Module ${module.id} should have non-empty description", module.description.isNotEmpty())
        }
    }

    @Test
    fun `all modules have non-empty activeScript and disableScript`() {
        for (module in OptimizationModule.ALL) {
            assertTrue("Module ${module.id} should have non-empty activeScript", module.activeScript.isNotEmpty())
            assertTrue("Module ${module.id} should have non-empty disableScript", module.disableScript.isNotEmpty())
        }
    }

    @Test
    fun `sh function replaces section sign with dollar sign`() {
        // Test the private sh function indirectly through script content
        // Scripts use § as $ placeholder, and sh() replaces them
        // Verify by checking scripts contain the expected pattern
        val framePacing = OptimizationModule.FRAME_PACING
        // The active script should have been processed by sh() so § should be $
        assertFalse("Script should not contain § after transformation", framePacing.activeScript.contains("§"))
        assertTrue("Script should contain $ after transformation", framePacing.activeScript.contains("$"))
    }

    @Test
    fun `summarize produces readable descriptions for setprop commands`() {
        val result = invokeSummarize("setprop debug.sf.hw 1 2>/dev/null")
        assertEquals("Setting debug.sf.hw …", result)
    }

    @Test
    fun `summarize produces readable descriptions for settings commands`() {
        val result = invokeSummarize("settings put global force_gpu_rendering 1 2>/dev/null")
        assertEquals("Setting global force_gpu_rendering …", result)

        val systemResult = invokeSummarize("settings put system window_animation_scale 0 2>/dev/null")
        assertEquals("Setting system window_animation_scale …", systemResult)

        val secureResult = invokeSummarize("settings put secure thermal_service disabled 2>/dev/null")
        assertEquals("Setting secure thermal_service …", secureResult)

        val deleteResult = invokeSummarize("settings delete global app_standby_enabled 2>/dev/null")
        assertEquals("Resetting app_standby_enabled …", deleteResult)
    }

    @Test
    fun `summarize handles device_config commands`() {
        val putResult = invokeSummarize("device_config put runtime_native use_svelte false 2>/dev/null")
        assertEquals("Configuring use_svelte …", putResult)

        val deleteResult = invokeSummarize("device_config delete activity_manager max_phantom_processes 2>/dev/null")
        assertEquals("Resetting device_config max_phantom_processes …", deleteResult)
    }

    @Test
    fun `summarize handles cmd commands`() {
        val result = invokeSummarize("cmd power set-fixed-performance-mode-enabled true 2>/dev/null")
        assertEquals("Running system command …", result)
    }

    @Test
    fun `ExecuteResult stores success and results correctly`() {
        val results = listOf(
            CommandResult("Test 1", true, 0),
            CommandResult("Test 2", false, 1)
        )
        val execResult = ExecuteResult(success = false, results = results)
        assertFalse(execResult.success)
        assertEquals(2, execResult.results.size)
        assertEquals("Test 1", execResult.results[0].summary)
        assertEquals(true, execResult.results[0].success)
        assertEquals(0, execResult.results[0].exitCode)
    }

    @Test
    fun `ExecuteResult with all successful commands is success`() {
        val results = listOf(
            CommandResult("Test 1", true, 0),
            CommandResult("Test 2", true, 0)
        )
        val execResult = ExecuteResult(success = true, results = results)
        assertTrue(execResult.success)
    }

    private fun invokeSummarize(cmd: String): String {
        val method = OptimizationExecutor::class.java.getDeclaredMethod(
            "summarize", String::class.java
        )
        method.isAccessible = true
        return method.invoke(OptimizationExecutor, cmd) as String
    }
}
