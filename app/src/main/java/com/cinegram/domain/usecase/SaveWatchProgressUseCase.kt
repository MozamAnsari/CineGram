package com.cinegram.domain.usecase

import com.cinegram.domain.model.WatchProgress
import com.cinegram.domain.repository.WatchProgressRepository
import javax.inject.Inject

class SaveWatchProgressUseCase @Inject constructor(
    private val repository: WatchProgressRepository
) {
    suspend operator fun invoke(progress: WatchProgress) {
        repository.saveWatchProgress(progress)
    }
}
