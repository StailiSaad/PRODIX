package com.androidtweaker.com.ui.screens.home

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.androidtweaker.com.R
import com.androidtweaker.com.system.jni.AndroidEnhancerMode
import com.androidtweaker.com.ui.theme.Accent
import com.androidtweaker.com.ui.theme.Error as ThemeError
import com.androidtweaker.com.ui.theme.NeonGray
import com.androidtweaker.com.ui.theme.Primary
import com.androidtweaker.com.ui.theme.Secondary
import com.androidtweaker.com.ui.theme.Success

private val performanceModes = listOf(
    AndroidEnhancerMode.POWERSAVER,
    AndroidEnhancerMode.BALANCED,
    AndroidEnhancerMode.PERFORMANCE,
    AndroidEnhancerMode.GAMING
)

@Composable
fun HomeScreen(
    state: HomeState,
    onModeSelected: (AndroidEnhancerMode) -> Unit,
    onOpenPerAppMode: () -> Unit,
    onOpenOptimization: () -> Unit,
    onToggleService: ((Boolean) -> Unit)? = null
) {
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        item { HeaderSection(serviceEnabled = state.serviceEnabled, onToggleService = onToggleService) }

        if (onToggleService == null) {
            item { NonRootBanner() }
        }

        item { HeroCard(currentMode = state.mode, onModeSelected = onModeSelected) }

        item { ModeGrid(currentMode = state.mode, onModeSelected = onModeSelected) }

        item {
            PerAppModeCard(
                onOpen = onOpenPerAppMode,
                modifier = Modifier.fillMaxWidth()
            )
        }

        item {
            OptimizationCard(
                onOpen = onOpenOptimization,
                modifier = Modifier.fillMaxWidth()
            )
        }

        item { Spacer(modifier = Modifier.height(16.dp)) }
    }
}

@Composable
private fun HeaderSection(
    serviceEnabled: Boolean,
    onToggleService: ((Boolean) -> Unit)?
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = "Android Tweaker",
                style = MaterialTheme.typography.displayLarge,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface
            )
            Text(
                text = "Optimisation intelligente du système",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        if (onToggleService != null) {
            Switch(
                checked = serviceEnabled,
                onCheckedChange = onToggleService
            )
        }
    }
}

@Composable
private fun HeroCard(
    currentMode: AndroidEnhancerMode,
    onModeSelected: (AndroidEnhancerMode) -> Unit
) {
    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(28.dp),
        colors = CardDefaults.elevatedCardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainer
        ),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 8.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            Primary.copy(alpha = 0.12f),
                            Accent.copy(alpha = 0.06f),
                            MaterialTheme.colorScheme.surfaceContainer
                        )
                    ),
                    shape = RoundedCornerShape(28.dp)
                )
                .padding(28.dp)
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(64.dp)
                        .clip(RoundedCornerShape(20.dp))
                        .background(Primary.copy(alpha = 0.15f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        painter = painterResource(R.drawable.ic_bolt),
                        contentDescription = null,
                        tint = Primary,
                        modifier = Modifier.size(32.dp)
                    )
                }

                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Text(
                        text = "Mode Intelligent",
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = currentMode.description(),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                        lineHeight = 22.sp
                    )
                }

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    AndroidEnhancerMode.entries.forEach { mode ->
                        val selected = mode == currentMode
                        val bgColor by animateColorAsState(
                            targetValue = if (selected) mode.color() else MaterialTheme.colorScheme.surfaceContainerHigh,
                            animationSpec = tween(300),
                            label = "chip_bg"
                        )
                        val textColor by animateColorAsState(
                            targetValue = if (selected) Color.White else MaterialTheme.colorScheme.onSurfaceVariant,
                            animationSpec = tween(300),
                            label = "chip_text"
                        )

                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(12.dp))
                                .background(bgColor)
                                .clickable { onModeSelected(mode) }
                                .padding(horizontal = 14.dp, vertical = 8.dp)
                        ) {
                            Text(
                                text = mode.displayName(),
                                style = MaterialTheme.typography.labelLarge,
                                fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
                                color = textColor
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun NonRootBanner() {
    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.elevatedCardColors(
            containerColor = MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.3f)
        ),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                painter = painterResource(R.drawable.ic_power_settings_new),
                contentDescription = null,
                tint = MaterialTheme.colorScheme.error,
                modifier = Modifier.size(24.dp)
            )
            Text(
                text = "Root requis — les optimisations système nécessitent un accès root. Passez en mode ADB ou activez le root.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun ModeGrid(
    currentMode: AndroidEnhancerMode,
    onModeSelected: (AndroidEnhancerMode) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        performanceModes.chunked(2).forEach { row ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                row.forEach { mode ->
                    ModeCard(
                        mode = mode,
                        selected = mode == currentMode,
                        onClick = { onModeSelected(mode) },
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }
    }
}

@Composable
private fun ModeCard(
    mode: AndroidEnhancerMode,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val elevation by animateFloatAsState(
        targetValue = if (selected) 8f else 2f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "card_elevation"
    )
    val borderAlpha by animateFloatAsState(
        targetValue = if (selected) 1f else 0f,
        animationSpec = tween(300),
        label = "border_alpha"
    )

    ElevatedCard(
        onClick = onClick,
        modifier = modifier.aspectRatio(1f),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.elevatedCardColors(
            containerColor = if (selected) mode.color().copy(alpha = 0.12f)
            else MaterialTheme.colorScheme.surfaceContainer
        ),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = elevation.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(2.dp)
                .clip(RoundedCornerShape(18.dp))
                .background(
                    if (selected) mode.color().copy(alpha = borderAlpha * 0.15f)
                    else Color.Transparent
                )
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(
                            if (selected) mode.color().copy(alpha = 0.2f)
                            else MaterialTheme.colorScheme.surfaceContainerHigh
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        painter = painterResource(mode.iconRes()),
                        contentDescription = null,
                        tint = if (selected) mode.color() else MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(24.dp)
                    )
                }

                Spacer(modifier = Modifier.height(8.dp))

                Text(
                    text = mode.displayName(),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
                    color = if (selected) mode.color() else MaterialTheme.colorScheme.onSurface,
                    textAlign = TextAlign.Center
                )
            }

            if (selected) {
                Box(
                    modifier = Modifier
                        .matchParentSize()
                        .clip(RoundedCornerShape(18.dp))
                        .background(
                            Brush.horizontalGradient(
                                colors = listOf(
                                    mode.color().copy(alpha = borderAlpha * 0.3f),
                                    Color.Transparent,
                                    mode.color().copy(alpha = borderAlpha * 0.3f)
                                )
                            )
                        )
                )
            }
        }
    }
}

@Composable
private fun PerAppModeCard(
    onOpen: () -> Unit,
    modifier: Modifier = Modifier
) {
    ElevatedCard(
        onClick = onOpen,
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.elevatedCardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainer
        ),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 4.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(Secondary.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    painter = painterResource(R.drawable.ic_apps),
                    contentDescription = null,
                    tint = Secondary,
                    modifier = Modifier.size(24.dp)
                )
            }

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "Mode par application",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Text(
                    text = "Personnaliser les performances par application",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Icon(
                painter = painterResource(R.drawable.ic_chevron_right),
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(24.dp)
            )
        }
    }
}

@Composable
private fun OptimizationCard(
    onOpen: () -> Unit,
    modifier: Modifier = Modifier
) {
    ElevatedCard(
        onClick = onOpen,
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.elevatedCardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainer
        ),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 4.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(Accent.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    painter = painterResource(R.drawable.ic_bolt),
                    contentDescription = null,
                    tint = Accent,
                    modifier = Modifier.size(24.dp)
                )
            }

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = stringResource(R.string.optimization_title),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Text(
                    text = stringResource(R.string.optimization_home_hint),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Icon(
                painter = painterResource(R.drawable.ic_chevron_right),
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(24.dp)
            )
        }
    }
}

@Composable
private fun AndroidEnhancerMode.displayName(): String =
    when (this) {
        AndroidEnhancerMode.POWERSAVER -> "Eco"
        AndroidEnhancerMode.BALANCED -> "Équilibré"
        AndroidEnhancerMode.PERFORMANCE -> "Turbo"
        AndroidEnhancerMode.GAMING -> "Gaming"
        AndroidEnhancerMode.AUTO -> "Auto"
    }

@Composable
private fun AndroidEnhancerMode.description(): String =
    when (this) {
        AndroidEnhancerMode.AUTO -> "L'application analyse automatiquement\nles performances du système et applique\nles optimisations adaptées."
        AndroidEnhancerMode.POWERSAVER -> "Économie d'énergie maximale\npour prolonger l'autonomie."
        AndroidEnhancerMode.BALANCED -> "Équilibre parfait entre\nperformances et autonomie."
        AndroidEnhancerMode.PERFORMANCE -> "Performances maximales\npour les applications exigeantes."
        AndroidEnhancerMode.GAMING -> "Optimisation gaming\npour une expérience de jeu fluide."
    }

private fun AndroidEnhancerMode.color() = when (this) {
    AndroidEnhancerMode.POWERSAVER -> Success
    AndroidEnhancerMode.BALANCED -> Primary
    AndroidEnhancerMode.PERFORMANCE -> Accent
    AndroidEnhancerMode.GAMING -> ThemeError
    AndroidEnhancerMode.AUTO -> Primary
}

private fun AndroidEnhancerMode.iconRes() = when (this) {
    AndroidEnhancerMode.POWERSAVER -> R.drawable.ic_brightness_2
    AndroidEnhancerMode.BALANCED -> R.drawable.ic_description
    AndroidEnhancerMode.PERFORMANCE -> R.drawable.ic_bolt
    AndroidEnhancerMode.GAMING -> R.drawable.ic_campaign
    AndroidEnhancerMode.AUTO -> R.drawable.ic_bolt
}
