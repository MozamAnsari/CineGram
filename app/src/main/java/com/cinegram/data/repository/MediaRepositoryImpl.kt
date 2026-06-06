package com.cinegram.data.repository

import com.cinegram.data.local.db.dao.MediaDao
import com.cinegram.data.local.db.dao.WatchProgressDao
import com.cinegram.data.local.db.entity.MediaEntity
import com.cinegram.data.local.db.entity.MediaFileEntity
import com.cinegram.data.local.scanner.MediaStoreScanner
import com.cinegram.data.remote.api.TmdbService
import com.cinegram.data.util.FileNameParser
import com.cinegram.domain.model.MediaFile
import com.cinegram.domain.model.MediaItem
import com.cinegram.domain.repository.MediaRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.security.MessageDigest
import javax.inject.Inject

class MediaRepositoryImpl @Inject constructor(
    private val mediaDao: MediaDao,
    private val watchProgressDao: WatchProgressDao,
    private val mediaStoreScanner: MediaStoreScanner,
    private val tmdbService: TmdbService
) : MediaRepository {

    override fun getLibraryFlow(): Flow<List<MediaItem>> {
        return mediaDao.getAllMediaItems().map { entities ->
            entities.map { entity ->
                val files = mediaDao.getFilesForMedia(entity.id).map { it.toDomain() }
                val progress = files.firstOrNull()?.let { file ->
                    watchProgressDao.getProgressForFile(file.path)?.toDomain()
                }
                entity.toDomain(files, progress)
            }
        }
    }

    override suspend fun getMediaItemById(id: String): MediaItem? {
        val entity = mediaDao.getMediaItemById(id) ?: return null
        val files = mediaDao.getFilesForMedia(id).map { it.toDomain() }
        val progress = files.firstOrNull()?.let { file ->
            watchProgressDao.getProgressForFile(file.path)?.toDomain()
        }
        return entity.toDomain(files, progress)
    }

    override suspend fun getFileProgress(filePath: String): com.cinegram.domain.model.WatchProgress? {
        return watchProgressDao.getProgressForFile(filePath)?.toDomain()
    }

    override suspend fun scanAndSyncLocalMedia(apiKey: String) {
        val localFiles = mediaStoreScanner.scanLocalVideos()
        if (localFiles.isEmpty()) return

        for (file in localFiles) {
            val existingFile = mediaDao.getFileByPath(file.path)
            if (existingFile != null) {
                continue
            }

            val parsedInfo = FileNameParser.parse(file.name)
            var mediaEntity: MediaEntity? = null
            
            if (apiKey.isNotBlank() && apiKey != "YOUR_TMDB_API_KEY_HERE") {
                try {
                    val response = tmdbService.searchMovie(query = parsedInfo.title, apiKey = apiKey)
                    val bestMatch = response.results.firstOrNull()
                    
                    if (bestMatch != null) {
                        mediaEntity = MediaEntity(
                            id = bestMatch.id.toString(),
                            title = bestMatch.title,
                            overview = bestMatch.overview,
                            posterPath = bestMatch.poster_path?.let { "https://image.tmdb.org/t/p/w500$it" },
                            backdropPath = bestMatch.backdrop_path?.let { "https://image.tmdb.org/t/p/w1280$it" },
                            releaseDate = bestMatch.release_date,
                            voteAverage = bestMatch.vote_average,
                            matched = true
                        )
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }

            if (mediaEntity == null) {
                val cleanId = generateHash(parsedInfo.title)
                mediaEntity = MediaEntity(
                    id = cleanId,
                    title = parsedInfo.title,
                    overview = "Local video file: ${file.name}",
                    posterPath = null,
                    backdropPath = null,
                    releaseDate = parsedInfo.year,
                    voteAverage = null,
                    matched = false
                )
            }

            val fileEntity = MediaFileEntity.fromDomain(file, mediaEntity.id)
            mediaDao.insertMediaWithFiles(mediaEntity, listOf(fileEntity))
        }

        val localFilePaths = localFiles.map { it.path }.toSet()
        val cachedFilePaths = mediaDao.getAllFilePaths()
        for (cachedPath in cachedFilePaths) {
            if (cachedPath !in localFilePaths) {
                mediaDao.deleteMediaFileByPath(cachedPath)
                watchProgressDao.deleteProgressForFile(cachedPath)
            }
        }
        mediaDao.pruneOrphanedMediaItems()
    }

    private fun generateHash(input: String): String {
        return MessageDigest.getInstance("MD5")
            .digest(input.toByteArray())
            .joinToString("") { "%02x".format(it) }
    }
}
