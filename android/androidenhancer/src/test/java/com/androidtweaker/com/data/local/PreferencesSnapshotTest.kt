package com.androidtweaker.com.data.local

import com.androidtweaker.com.system.jni.AndroidEnhancerMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PreferencesSnapshotTest {

    @Test
    fun `default serviceEnabled is false`() {
        val snapshot = PreferencesSnapshot()
        assertEquals(false, snapshot.serviceEnabled)
    }

    @Test
    fun `default startOnBoot is true`() {
        val snapshot = PreferencesSnapshot()
        assertEquals(true, snapshot.startOnBoot)
    }

    @Test
    fun `default mode is AUTO`() {
        val snapshot = PreferencesSnapshot()
        assertEquals(AndroidEnhancerMode.AUTO, snapshot.mode)
    }

    @Test
    fun `encodeApps produces valid JSON string`() {
        val apps = mapOf(
            "com.example.app1" to AndroidEnhancerMode.PERFORMANCE,
            "com.example.app2" to AndroidEnhancerMode.POWERSAVER
        )

        val encoded = PreferencesSnapshot.encodeApps(apps)
        assertTrue(encoded.contains("com.example.app1"))
        assertTrue(encoded.contains("3")) // PERFORMANCE.code
        assertTrue(encoded.contains("com.example.app2"))
        assertTrue(encoded.contains("1")) // POWERSAVER.code
    }

    @Test
    fun `encodeApps handles empty map`() {
        val encoded = PreferencesSnapshot.encodeApps(emptyMap())
        assertEquals("{}", encoded)
    }

    @Test
    fun `copy preserves fields correctly`() {
        val original = PreferencesSnapshot()
        val modified = original.copy(
            mode = AndroidEnhancerMode.PERFORMANCE,
            serviceEnabled = true,
            startOnBoot = false,
            touchBoostEnabled = false,
            apps = mapOf("com.test" to AndroidEnhancerMode.GAMING)
        )

        assertEquals(AndroidEnhancerMode.PERFORMANCE, modified.mode)
        assertEquals(true, modified.serviceEnabled)
        assertEquals(false, modified.startOnBoot)
        assertEquals(false, modified.touchBoostEnabled)
        assertEquals(mapOf("com.test" to AndroidEnhancerMode.GAMING), modified.apps)
    }

    @Test
    fun `mode round-trips correctly through copy`() {
        val modes = AndroidEnhancerMode.entries
        for (mode in modes) {
            val snapshot = PreferencesSnapshot().copy(mode = mode)
            assertEquals(mode, snapshot.mode)
        }
    }
}
