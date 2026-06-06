package com.cinegram.ui.screens.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.cinegram.data.local.db.CinegramDatabase
import com.cinegram.data.local.prefs.SettingsManager
import com.cinegram.domain.usecase.ScanLocalMediaUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SettingsState(
    val tmdbApiKey: String = "",
    val isScanning: Boolean = false,
    val infoMessage: String? = null
)

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val settingsManager: SettingsManager,
    private val scanLocalMediaUseCase: ScanLocalMediaUseCase,
    private val database: CinegramDatabase
) : ViewModel() {

    private val _state = MutableStateFlow(SettingsState())
    val state: StateFlow<SettingsState> = _state.asStateFlow()

    init {
        loadSettings()
    }

    fun loadSettings() {
        val apiKey = settingsManager.getTmdbApiKey()
        _state.value = SettingsState(tmdbApiKey = apiKey)
    }

    fun saveApiKey(key: String) {
        settingsManager.saveTmdbApiKey(key)
        _state.value = _state.value.copy(tmdbApiKey = key, infoMessage = "API Key saved successfully!")
    }

    fun clearInfoMessage() {
        _state.value = _state.value.copy(infoMessage = null)
    }

    fun triggerRescan() {
        viewModelScope.launch {
            _state.value = _state.value.copy(isScanning = true, infoMessage = "Scanning started...")
            try {
                scanLocalMediaUseCase(settingsManager.getTmdbApiKey())
                _state.value = _state.value.copy(infoMessage = "Scan completed successfully!")
            } catch (e: Exception) {
                _state.value = _state.value.copy(infoMessage = "Scan failed: ${e.localizedMessage}")
            } finally {
                _state.value = _state.value.copy(isScanning = false)
            }
        }
    }

    fun clearDatabaseCache() {
        viewModelScope.launch {
            _state.value = _state.value.copy(infoMessage = "Clearing cache...")
            try {
                database.clearAllTables()
                _state.value = _state.value.copy(infoMessage = "Cache cleared!")
            } catch (e: Exception) {
                _state.value = _state.value.copy(infoMessage = "Failed to clear cache: ${e.localizedMessage}")
            }
        }
    }
}
