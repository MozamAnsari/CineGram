package com.cinegram.data.repository

import com.cinegram.data.local.db.dao.WatchProgressDao
import com.cinegram.data.local.db.entity.WatchProgressEntity
import com.cinegram.domain.model.WatchProgress
import com.cinegram.domain.repository.WatchProgressRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject

class WatchProgressRepositoryImpl @Inject constructor(
    private val watchProgressDao: WatchProgressDao
) : WatchProgressRepository {

    override suspend fun saveWatchProgress(progress: WatchProgress) {
        watchProgressDao.insertProgress(WatchProgressEntity.fromDomain(progress))
    }

    override suspend fun getWatchProgressForFile(filePath: String): WatchProgress? {
        return watchProgressDao.getProgressForFile(filePath)?.toDomain()
    }

    override fun getWatchProgressForMediaFlow(mediaId: String): Flow<List<WatchProgress>> {
        return watchProgressDao.getProgressForMediaFlow(mediaId).map { entities ->
            entities.map { it.toDomain() }
        }
    }
}
