package com.cinegram.data.local.db.dao

import androidx.room.*
import com.cinegram.data.local.db.entity.MediaEntity
import com.cinegram.data.local.db.entity.MediaFileEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface MediaDao {
    @Query("SELECT * FROM media_items")
    fun getAllMediaItems(): Flow<List<MediaEntity>>

    @Query("SELECT * FROM media_items WHERE id = :id")
    suspend fun getMediaItemById(id: String): MediaEntity?

    @Query("SELECT * FROM media_files WHERE mediaId = :mediaId")
    suspend fun getFilesForMedia(mediaId: String): List<MediaFileEntity>

    @Query("SELECT * FROM media_files WHERE path = :path")
    suspend fun getFileByPath(path: String): MediaFileEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertMediaItem(mediaItem: MediaEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertMediaFile(mediaFile: MediaFileEntity)

    @Transaction
    suspend fun insertMediaWithFiles(mediaItem: MediaEntity, files: List<MediaFileEntity>) {
        insertMediaItem(mediaItem)
        files.forEach { insertMediaFile(it) }
    }

    @Delete
    suspend fun deleteMediaItem(mediaItem: MediaEntity)

    @Query("DELETE FROM media_files WHERE path = :path")
    suspend fun deleteMediaFileByPath(path: String)
    
    @Query("SELECT path FROM media_files")
    suspend fun getAllFilePaths(): List<String>
    
    @Query("DELETE FROM media_items WHERE id NOT IN (SELECT DISTINCT mediaId FROM media_files)")
    suspend fun pruneOrphanedMediaItems()
}
