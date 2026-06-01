package com.androidtweaker.com.ui.screens.about

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import com.androidtweaker.com.R
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class AboutViewModel @Inject constructor() : ViewModel() {

    private val _state = MutableStateFlow(AboutState())
    val state: StateFlow<AboutState> = _state
        .stateIn(viewModelScope, SharingStarted.Eagerly, AboutState())

    init {
        viewModelScope.launch {
            _state.value = AboutState(
                actions = listOf(
                    AboutAction(
                        titleRes = R.string.prodix_name,
                        subtitleRes = R.string.prodix_desc,
                        uri = "https://github.com/StailiSaad",
                        type = AboutActionType.DEVELOPER
                    ),
                    AboutAction(
                        titleRes = R.string.prodix_channel,
                        subtitleRes = R.string.prodix_channel_desc,
                        uri = "https://github.com/StailiSaad",
                        type = AboutActionType.CHANNEL
                    ),
                    AboutAction(
                        titleRes = R.string.prodix_thanks_looper,
                        subtitleRes = R.string.prodix_thanks_looper_desc,
                        uri = null,
                        type = AboutActionType.CREDITS
                    )
                )
            )
        }
    }
}
