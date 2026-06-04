package com.androidtweaker.com.ui.screens.settings

import org.junit.Assert.assertEquals
import org.junit.Test

class SettingsStateTest {

    @Test
    fun `fromLocaleTag returns FOLLOW_SYSTEM for empty tag`() {
        assertEquals(LanguageMode.FOLLOW_SYSTEM, LanguageMode.fromLocaleTag(""))
    }

    @Test
    fun `fromLocaleTag returns FRENCH for fr tag`() {
        assertEquals(LanguageMode.FRENCH, LanguageMode.fromLocaleTag("fr"))
    }

    @Test
    fun `fromLocaleTag returns ENGLISH for en tag`() {
        assertEquals(LanguageMode.ENGLISH, LanguageMode.fromLocaleTag("en"))
    }

    @Test
    fun `fromLocaleTag ignores region suffix`() {
        assertEquals(LanguageMode.FRENCH, LanguageMode.fromLocaleTag("fr-FR"))
        assertEquals(LanguageMode.ENGLISH, LanguageMode.fromLocaleTag("en-US"))
        assertEquals(LanguageMode.ENGLISH, LanguageMode.fromLocaleTag("en-GB"))
    }

    @Test
    fun `fromLocaleTag falls back to FOLLOW_SYSTEM for unknown tags`() {
        assertEquals(LanguageMode.FOLLOW_SYSTEM, LanguageMode.fromLocaleTag("de"))
        assertEquals(LanguageMode.FOLLOW_SYSTEM, LanguageMode.fromLocaleTag("es"))
        assertEquals(LanguageMode.FOLLOW_SYSTEM, LanguageMode.fromLocaleTag("zh"))
    }

    @Test
    fun `FRENCH localeTag is fr`() {
        assertEquals("fr", LanguageMode.FRENCH.localeTag)
    }

    @Test
    fun `ENGLISH localeTag is en`() {
        assertEquals("en", LanguageMode.ENGLISH.localeTag)
    }

    @Test
    fun `FOLLOW_SYSTEM localeTag is empty`() {
        assertEquals("", LanguageMode.FOLLOW_SYSTEM.localeTag)
    }
}
