package com.androidtweaker.com.ui.navigation

sealed class AppDestination(val route: String) {
    data object Home : AppDestination("home")
    data object About : AppDestination("about")
    data object PerAppMode : AppDestination("per_app_mode")
    data object Settings : AppDestination("settings")
    data object Optimization : AppDestination("optimization")
}

