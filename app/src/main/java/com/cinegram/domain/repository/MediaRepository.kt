package com.cinegram.domain.repository

import com.cinegram.domain.model.MediaItem
import kotlinx.coroutines.flow.Flow

interface MediaRepository {
    fun getLibraryFlow(): Flow<List<MediaItem>>
    suspend fun getMediaItemById(id: String): MediaItem?
    suspend fun scanAndSyncLocalMedia(apiKey: String)
    suspend fun getFileProgress(filePath: String): com.cinegram.domain.model.WatchProgress?
}
