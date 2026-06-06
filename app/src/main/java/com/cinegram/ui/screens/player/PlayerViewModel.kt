package com.cinegram.ui.screens.player

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.cinegram.domain.model.WatchProgress
import com.cinegram.domain.usecase.GetFileProgressUseCase
import com.cinegram.domain.usecase.SaveWatchProgressUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class PlayerState(
    val initialPosition: Long = 0,
    val isLoaded: Boolean = false
)

@HiltViewModel
class PlayerViewModel @Inject constructor(
    private val getFileProgressUseCase: GetFileProgressUseCase,
    private val saveWatchProgressUseCase: SaveWatchProgressUseCase
) : ViewModel() {

    private val _state = MutableStateFlow(PlayerState())
    val state: StateFlow<PlayerState> = _state.asStateFlow()

    fun loadInitialProgress(filePath: String) {
        viewModelScope.launch {
            val progress = getFileProgressUseCase(filePath)
            _state.value = PlayerState(
                initialPosition = progress?.lastPosition ?: 0,
                isLoaded = true
            )
        }
    }

    fun saveProgress(mediaId: String, filePath: String, currentPosition: Long, duration: Long) {
        viewModelScope.launch {
            if (duration > 0) {
                val progress = WatchProgress(
                    mediaId = mediaId,
                    filePath = filePath,
                    lastPosition = currentPosition,
                    duration = duration,
                    lastUpdated = System.currentTimeMillis()
                )
                saveWatchProgressUseCase(progress)
            }
        }
    }
}
