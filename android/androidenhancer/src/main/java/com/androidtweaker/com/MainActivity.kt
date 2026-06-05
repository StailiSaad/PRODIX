package com.androidtweaker.com

import android.Manifest
import android.os.Build
import android.os.Bundle
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.navigation.compose.rememberNavController
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import com.topjohnwu.superuser.Shell
import dagger.hilt.android.AndroidEntryPoint
import com.androidtweaker.com.data.local.PreferencesSnapshot
import com.androidtweaker.com.data.local.appDataStore
import com.androidtweaker.com.data.local.snapshotFlow
import com.androidtweaker.com.data.local.updateSnapshot
import com.androidtweaker.com.ui.navigation.AppNavHost
import com.androidtweaker.com.ui.theme.AppTheme
import javax.inject.Inject
import com.androidtweaker.com.data.repository.AppRepository
import com.androidtweaker.com.system.root.RootIpc
import androidx.compose.foundation.isSystemInDarkTheme

@OptIn(ExperimentalMaterial3Api::class)
@AndroidEntryPoint
class MainActivity : AppCompatActivity() {

    @Inject
    lateinit var repository: AppRepository

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        
        setContent {
            AppRoot(repository)
        }
    }
}

@Composable
private fun AppRoot(repository: AppRepository) {
    val context = LocalContext.current
    val dataStore = remember { context.appDataStore }
    val preferencesFlow = remember { dataStore.snapshotFlow() }
    val preferences by preferencesFlow.collectAsState(initial = PreferencesSnapshot())

    val isRootAvailable = remember { mutableStateOf<Boolean?>(null) }
    val navController = rememberNavController()
    val snackbarHostState = remember { SnackbarHostState() }

    // Request notification permission on Android 13+
    val permissionLauncher = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        rememberLauncherForActivityResult(
            contract = ActivityResultContracts.RequestPermission(),
            onResult = { /* Handle permission result if needed */ }
        )
    } else {
        null
    }

    LaunchedEffect(Unit) {
        val root = withContext(Dispatchers.IO) {
            try {
                withTimeout(5000) {
                    Shell.getShell().isRoot
                }
            } catch (_: Exception) {
                false
            }
        }

        val snapshot = dataStore.snapshotFlow().first()
        // Also authorized via ADB (WRITE_SECURE_SETTINGS) or Shizuku
        var adbGranted = snapshot.adbWriteSecureGranted
        val shizukuGranted = try {
            val checkSelfPerm = Class.forName("rikka.shizuku.Shizuku")
                .getMethod("checkSelfPermission")
            checkSelfPerm.invoke(null) as Int == 0
        } catch (_: Exception) { false }
        // Persist Shizuku grant to DataStore so future checks don't need reflection
        if (shizukuGranted && !adbGranted) {
            dataStore.updateSnapshot { it.copy(adbWriteSecureGranted = true) }
            adbGranted = true
        }
        isRootAvailable.value = root || adbGranted || shizukuGranted

        if (root) {
            RootIpc.init(context)
            if (snapshot.serviceEnabled) {
                repository.startService()
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissionLauncher?.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    val useDarkTheme = when (preferences.themeMode) {
        1 -> false
        2 -> true
        else -> isSystemInDarkTheme()
    }

    AppTheme(
        darkTheme = useDarkTheme,
        pureBlack = if (useDarkTheme) preferences.pureBlackTheme else false
    ) {
        AppNavHost(
            navController = navController,
            snackbarHostState = snackbarHostState,
            isRootAvailable = isRootAvailable.value == true
        )
    }
}

@Composable
private fun RootAccessErrorDialog(onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                text = stringResource(R.string.root_access_not_found),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
        },
        text = {
            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = stringResource(R.string.root_access_not_found_message),
                    style = MaterialTheme.typography.bodyMedium
                )
                Text(
                    text = stringResource(R.string.root_access_not_found_optimization_hint),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.primary
                )
                Text(
                    text = stringResource(R.string.root_access_not_found_adb_title),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = stringResource(R.string.root_access_not_found_adb_step1),
                    style = MaterialTheme.typography.bodySmall
                )
                Text(
                    text = stringResource(R.string.root_access_not_found_adb_step2),
                    style = MaterialTheme.typography.bodySmall
                )
                Text(
                    text = stringResource(R.string.root_access_not_found_adb_step3),
                    style = MaterialTheme.typography.bodySmall,
                    fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace
                )
                Text(
                    text = stringResource(R.string.root_access_not_found_adb_step4),
                    style = MaterialTheme.typography.bodySmall
                )
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text(
                    text = stringResource(R.string.root_access_not_found_dismiss),
                    fontWeight = FontWeight.Bold
                )
            }
        }
    )
}
