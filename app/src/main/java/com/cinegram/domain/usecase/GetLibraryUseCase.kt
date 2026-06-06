package com.cinegram.domain.usecase

import com.cinegram.domain.model.MediaItem
import com.cinegram.domain.repository.MediaRepository
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject

class GetLibraryUseCase @Inject constructor(
    private val repository: MediaRepository
) {
    operator fun invoke(): Flow<List<MediaItem>> {
        return repository.getLibraryFlow()
    }
}
