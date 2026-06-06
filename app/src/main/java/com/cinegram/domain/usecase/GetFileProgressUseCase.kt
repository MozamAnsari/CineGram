package com.cinegram.domain.usecase

import com.cinegram.domain.model.WatchProgress
import com.cinegram.domain.repository.MediaRepository
import javax.inject.Inject

class GetFileProgressUseCase @Inject constructor(
    private val repository: MediaRepository
) {
    suspend operator fun invoke(filePath: String): WatchProgress? {
        return repository.getFileProgress(filePath)
    }
}
