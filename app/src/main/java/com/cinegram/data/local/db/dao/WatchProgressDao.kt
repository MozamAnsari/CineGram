package com.cinegram.data.local.db.dao

import androidx.room.*
import com.cinegram.data.local.db.entity.WatchProgressEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface WatchProgressDao {
    @Query("SELECT * FROM watch_progress WHERE filePath = :filePath")
    suspend fun getProgressForFile(filePath: String): WatchProgressEntity?

    @Query("SELECT * FROM watch_progress WHERE mediaId = :mediaId")
    fun getProgressForMediaFlow(mediaId: String): Flow<List<WatchProgressEntity>>

    @Query("SELECT * FROM watch_progress WHERE mediaId = :mediaId")
    suspend fun getProgressForMedia(mediaId: String): List<WatchProgressEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertProgress(progress: WatchProgressEntity)

    @Query("DELETE FROM watch_progress WHERE filePath = :filePath")
    suspend fun deleteProgressForFile(filePath: String)
}
