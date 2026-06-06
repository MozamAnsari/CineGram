package com.cinegram.ui.screens.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.cinegram.data.local.prefs.SettingsManager
import com.cinegram.domain.model.MediaItem
import com.cinegram.domain.usecase.GetLibraryUseCase
import com.cinegram.domain.usecase.ScanLocalMediaUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import javax.inject.Inject

data class HomeState(
    val mediaItems: List<MediaItem> = emptyList(),
    val isScanning: Boolean = false,
    val errorMessage: String? = null
)

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val getLibraryUseCase: GetLibraryUseCase,
    private val scanLocalMediaUseCase: ScanLocalMediaUseCase,
    private val settingsManager: SettingsManager
) : ViewModel() {

    private val _state = MutableStateFlow(HomeState())
    val state: StateFlow<HomeState> = _state.asStateFlow()

    init {
        loadLibrary()
    }

    fun loadLibrary() {
        viewModelScope.launch {
            getLibraryUseCase().collectLatest { items ->
                _state.value = _state.value.copy(mediaItems = items)
            }
        }
    }

    fun scanLocalMedia() {
        viewModelScope.launch {
            _state.value = _state.value.copy(isScanning = true, errorMessage = null)
            try {
                val apiKey = settingsManager.getTmdbApiKey()
                scanLocalMediaUseCase(apiKey)
            } catch (e: Exception) {
                _state.value = _state.value.copy(errorMessage = e.localizedMessage)
            } finally {
                _state.value = _state.value.copy(isScanning = false)
            }
        }
    }
}
