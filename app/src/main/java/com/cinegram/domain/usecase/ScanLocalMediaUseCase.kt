package com.cinegram.domain.usecase

import com.cinegram.domain.repository.MediaRepository
import javax.inject.Inject

class ScanLocalMediaUseCase @Inject constructor(
    private val repository: MediaRepository
) {
    suspend operator fun invoke(apiKey: String) {
        repository.scanAndSyncLocalMedia(apiKey)
    }
}
