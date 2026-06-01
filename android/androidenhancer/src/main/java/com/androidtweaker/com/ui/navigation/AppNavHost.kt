package com.androidtweaker.com.ui.navigation

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExperimentalMaterial3ExpressiveApi
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import com.androidtweaker.com.R
import com.androidtweaker.com.ui.components.LoadingIndicatorDialog
import com.androidtweaker.com.ui.screens.about.AboutScreen
import com.androidtweaker.com.ui.screens.about.AboutViewModel
import com.androidtweaker.com.ui.screens.home.HomeScreen
import com.androidtweaker.com.ui.screens.home.HomeViewModel
import com.androidtweaker.com.ui.screens.per_app_mode.PerAppModeScreen
import com.androidtweaker.com.ui.screens.per_app_mode.PerAppModeViewModel
import com.androidtweaker.com.ui.screens.optimization.OptimizationScreen
import com.androidtweaker.com.ui.screens.optimization.OptimizationViewModel
import com.androidtweaker.com.ui.screens.settings.SettingsScreen
import com.androidtweaker.com.ui.screens.settings.SettingsViewModel
import com.androidtweaker.com.ui.theme.Primary
import kotlinx.coroutines.delay

@OptIn(ExperimentalMaterial3ExpressiveApi::class, ExperimentalMaterial3Api::class)
@Composable
fun AppNavHost(
    navController: NavHostController,
    snackbarHostState: SnackbarHostState
) {
    val homeViewModel: HomeViewModel = viewModel()
    val aboutViewModel: AboutViewModel = viewModel()
    val modeChangeViewModel: PerAppModeViewModel = viewModel()
    val settingsViewModel: SettingsViewModel = viewModel()
    val optimizationViewModel: OptimizationViewModel = viewModel()

    val aboutState by aboutViewModel.state.collectAsStateWithLifecycle()
    val modeChangeState by modeChangeViewModel.state.collectAsStateWithLifecycle()
    val settingsState by settingsViewModel.state.collectAsStateWithLifecycle()
    val optimizationState by optimizationViewModel.state.collectAsStateWithLifecycle()
    val homeState by homeViewModel.uiState.collectAsStateWithLifecycle()

    var showLoading by remember { mutableStateOf(false) }

    LaunchedEffect(showLoading) {
        if (showLoading) {
            delay(3000)
            showLoading = false
        }
    }

    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = navBackStackEntry?.destination
    val showBottomBar = currentDestination?.route in listOf(
        AppDestination.Home.route,
        AppDestination.Optimization.route,
        AppDestination.PerAppMode.route,
        AppDestination.Settings.route
    )

    val scrollBehavior = TopAppBarDefaults.pinnedScrollBehavior()

    Scaffold(
        modifier = Modifier.nestedScroll(scrollBehavior.nestedScrollConnection),
        topBar = {
            val route = currentDestination?.route
            val showTopBar = route in listOf(
                AppDestination.About.route,
                AppDestination.PerAppMode.route,
                AppDestination.Optimization.route,
                AppDestination.Settings.route
            )
            if (showTopBar) {
                val title = when (route) {
                    AppDestination.About.route -> stringResource(R.string.about)
                    AppDestination.PerAppMode.route -> stringResource(R.string.per_app_mode)
                    AppDestination.Optimization.route -> stringResource(R.string.optimization_title)
                    AppDestination.Settings.route -> stringResource(R.string.settings)
                    else -> ""
                }
                val showBack = route == AppDestination.About.route
                TopAppBar(
                    title = {
                        Text(
                            text = title,
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold
                        )
                    },
                    scrollBehavior = scrollBehavior,
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = MaterialTheme.colorScheme.surface,
                        scrolledContainerColor = MaterialTheme.colorScheme.surfaceContainer
                    ),
                    navigationIcon = {
                        if (showBack) {
                            IconButton(onClick = { navController.navigateUp() }) {
                                Icon(
                                    painter = painterResource(R.drawable.ic_arrow_back),
                                    contentDescription = stringResource(R.string.navigate_back)
                                )
                            }
                        }
                    }
                )
            }
        },
        bottomBar = {
            AnimatedVisibility(
                visible = showBottomBar,
                enter = slideInVertically(initialOffsetY = { it }),
                exit = slideOutVertically(targetOffsetY = { it })
            ) {
                BottomNavBar(
                    currentRoute = currentDestination?.route ?: AppDestination.Home.route,
                    onNavigate = { route ->
                        navController.navigate(route) {
                            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    }
                )
            }
        },
        snackbarHost = { SnackbarHost(hostState = snackbarHostState) }
    ) { padding ->
        NavHost(
            navController = navController,
            startDestination = AppDestination.Home.route,
            modifier = Modifier.padding(padding)
        ) {
            composable(AppDestination.Home.route) {
                HomeScreen(
                    state = homeState,
                    onModeSelected = homeViewModel::setMode,
                    onOpenPerAppMode = { navController.navigate(AppDestination.PerAppMode.route) },
                    onOpenOptimization = { navController.navigate(AppDestination.Optimization.route) },
                    onToggleService = { enabled ->
                        showLoading = true
                        homeViewModel.toggleService(enabled)
                    }
                )
            }
            composable(AppDestination.About.route) {
                AboutScreen(state = aboutState)
            }
            composable(AppDestination.Settings.route) {
                SettingsScreen(
                    state = settingsState,
                    onStartOnBootChanged = settingsViewModel::setStartOnBoot,
                    onTouchBoostEnabledChanged = settingsViewModel::setTouchBoostEnabled,
                    onLanguageModeChanged = settingsViewModel::setLanguageMode,
                    onThemeModeChanged = settingsViewModel::setThemeMode,
                    onPureBlackThemeChanged = settingsViewModel::setPureBlackTheme,
                    onUseDynamicThemeChanged = settingsViewModel::setUseDynamicTheme
                )
            }
            composable(AppDestination.PerAppMode.route) {
                PerAppModeScreen(
                    state = modeChangeState,
                    onSetModeOverride = modeChangeViewModel::setModeOverride,
                    onRemoveModeOverride = modeChangeViewModel::removeModeOverride,
                )
            }
            composable(AppDestination.Optimization.route) {
                OptimizationScreen(
                    state = optimizationState,
                    onToggleModule = optimizationViewModel::toggleModule,
                    onDismissAdbGrant = optimizationViewModel::dismissAdbGrantDialog,
                    onConfirmAdbGrant = optimizationViewModel::confirmAdbGrantApplied
                )
            }
        }
    }

    LoadingIndicatorDialog(visible = showLoading)
}

@Composable
private fun BottomNavBar(
    currentRoute: String,
    onNavigate: (String) -> Unit
) {
    val items = listOf(
        NavItem(AppDestination.Home.route, R.drawable.ic_home, "Accueil"),
        NavItem(AppDestination.Optimization.route, R.drawable.ic_bolt, "Tweaks"),
        NavItem(AppDestination.PerAppMode.route, R.drawable.ic_apps, "Applications"),
        NavItem(AppDestination.Settings.route, R.drawable.ic_settings, "Paramètres"),
    )

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 12.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(64.dp)
                .clip(RoundedCornerShape(24.dp))
                .background(MaterialTheme.colorScheme.surfaceContainerHigh.copy(alpha = 0.95f))
                .padding(horizontal = 8.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            items.forEach { item ->
                val selected = currentRoute == item.route
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(16.dp))
                        .then(
                            if (selected) Modifier.background(Primary.copy(alpha = 0.12f))
                            else Modifier
                        )
                        .clickable { onNavigate(item.route) }
                        .padding(vertical = 6.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(2.dp)
                ) {
                    Icon(
                        painter = painterResource(item.iconRes),
                        contentDescription = null,
                        tint = if (selected) Primary else MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(24.dp)
                    )
                    Text(
                        text = item.label,
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
                        color = if (selected) Primary else MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        fontSize = 10.sp
                    )
                }
            }
        }
    }
}

private data class NavItem(
    val route: String,
    val iconRes: Int,
    val label: String
)
