package com.androidtweaker.com.ui.screens.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import com.androidtweaker.com.data.repository.AppRepository
import com.androidtweaker.com.system.jni.AndroidEnhancerMode
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val repository: AppRepository
) : ViewModel() {

    private val modeUpdating = MutableStateFlow(false)

    val uiState: StateFlow<HomeState> = combine(
        repository.snapshot,
        repository.isRunning,
        repository.installedApps,
        modeUpdating
    ) { snapshot, running, apps, isUpdating ->
        HomeState(
            mode = snapshot.mode,
            apps = snapshot.apps,
            currentApp = snapshot.currentApp,
            accessibilityEnabled = snapshot.accessibilityEnabled,
            androidEnhancerRunning = running,
            installedApps = apps,
            isModeUpdating = isUpdating,
            serviceEnabled = snapshot.serviceEnabled
        )
    }.stateIn(
        viewModelScope,
        SharingStarted.Eagerly,
        HomeState()
    )

    fun setMode(mode: AndroidEnhancerMode) {
        viewModelScope.launch {
            modeUpdating.value = true
            try {
                val current = repository.snapshot.value
                if (!current.serviceEnabled) {
                    repository.setServiceEnabled(true)
                }
                repository.setMode(mode)
            } finally {
                modeUpdating.value = false
            }
        }
    }

    fun toggleService(enabled: Boolean) {
        viewModelScope.launch {
            repository.setServiceEnabled(enabled)
        }
    }

}
