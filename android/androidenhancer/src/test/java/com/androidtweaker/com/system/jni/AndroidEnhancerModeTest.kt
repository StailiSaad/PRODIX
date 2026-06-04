package com.androidtweaker.com.system.jni

import org.junit.Assert.assertEquals
import org.junit.Test

class AndroidEnhancerModeTest {

    @Test
    fun `fromCode returns AUTO for unknown codes`() {
        assertEquals(AndroidEnhancerMode.AUTO, AndroidEnhancerMode.fromCode(-1))
        assertEquals(AndroidEnhancerMode.AUTO, AndroidEnhancerMode.fromCode(99))
        assertEquals(AndroidEnhancerMode.AUTO, AndroidEnhancerMode.fromCode(Int.MAX_VALUE))
    }

    @Test
    fun `fromCode returns correct mode for valid codes`() {
        assertEquals(AndroidEnhancerMode.AUTO, AndroidEnhancerMode.fromCode(0))
        assertEquals(AndroidEnhancerMode.POWERSAVER, AndroidEnhancerMode.fromCode(1))
        assertEquals(AndroidEnhancerMode.BALANCED, AndroidEnhancerMode.fromCode(2))
        assertEquals(AndroidEnhancerMode.PERFORMANCE, AndroidEnhancerMode.fromCode(3))
        assertEquals(AndroidEnhancerMode.GAMING, AndroidEnhancerMode.fromCode(4))
    }

    @Test
    fun `all modes have unique codes`() {
        val codes = AndroidEnhancerMode.entries.map { it.code }.distinct()
        assertEquals(AndroidEnhancerMode.entries.size, codes.size)
    }

    @Test
    fun `AUTO is the first entry with code 0`() {
        assertEquals(0, AndroidEnhancerMode.AUTO.code)
    }
}
