package com.cinegram.ui.screens.detail

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.cinegram.domain.model.MediaItem
import com.cinegram.domain.repository.MediaRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class DetailState(
    val mediaItem: MediaItem? = null,
    val isLoading: Boolean = false,
    val error: String? = null
)

@HiltViewModel
class DetailViewModel @Inject constructor(
    private val mediaRepository: MediaRepository
) : ViewModel() {

    private val _state = MutableStateFlow(DetailState())
    val state: StateFlow<DetailState> = _state.asStateFlow()

    fun loadMediaItem(id: String) {
        viewModelScope.launch {
            _state.value = DetailState(isLoading = true)
            try {
                val item = mediaRepository.getMediaItemById(id)
                if (item != null) {
                    _state.value = DetailState(mediaItem = item)
                } else {
                    _state.value = DetailState(error = "Media item not found.")
                }
            } catch (e: Exception) {
                _state.value = DetailState(error = e.localizedMessage)
            }
        }
    }
}
