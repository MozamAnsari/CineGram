package com.cinegram.domain.repository

import com.cinegram.domain.model.WatchProgress
import kotlinx.coroutines.flow.Flow

interface WatchProgressRepository {
    suspend fun saveWatchProgress(progress: WatchProgress)
    suspend fun getWatchProgressForFile(filePath: String): WatchProgress?
    fun getWatchProgressForMediaFlow(mediaId: String): Flow<List<WatchProgress>>
}
