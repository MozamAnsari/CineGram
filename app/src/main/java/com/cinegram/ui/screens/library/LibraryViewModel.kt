package com.cinegram.ui.screens.library

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.cinegram.domain.model.MediaItem
import com.cinegram.domain.usecase.GetLibraryUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

enum class FilterType {
    ALL, MATCHED, UNMATCHED
}

data class LibraryState(
    val searchResults: List<MediaItem> = emptyList(),
    val searchQuery: String = "",
    val activeFilter: FilterType = FilterType.ALL
)

@HiltViewModel
class LibraryViewModel @Inject constructor(
    private val getLibraryUseCase: GetLibraryUseCase
) : ViewModel() {

    private val _searchQuery = MutableStateFlow("")
    private val _activeFilter = MutableStateFlow(FilterType.ALL)
    
    val state: StateFlow<LibraryState> = combine(
        getLibraryUseCase(),
        _searchQuery,
        _activeFilter
    ) { libraryItems, query, filter ->
        val filtered = libraryItems.filter { item ->
            val matchesFilter = when (filter) {
                FilterType.ALL -> true
                FilterType.MATCHED -> item.matched
                FilterType.UNMATCHED -> !item.matched
            }
            val matchesQuery = item.title.contains(query, ignoreCase = true) ||
                    (item.overview?.contains(query, ignoreCase = true) ?: false)
            
            matchesFilter && matchesQuery
        }
        LibraryState(searchResults = filtered, searchQuery = query, activeFilter = filter)
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = LibraryState()
    )

    fun onSearchQueryChanged(query: String) {
        _searchQuery.value = query
    }

    fun onFilterChanged(filter: FilterType) {
        _activeFilter.value = filter
    }
}
