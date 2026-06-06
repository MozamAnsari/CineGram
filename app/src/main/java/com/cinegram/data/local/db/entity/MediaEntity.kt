package com.cinegram.data.local.db.entity

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.cinegram.domain.model.MediaItem

@Entity(tableName = "media_items")
data class MediaEntity(
    @PrimaryKey val id: String,
    val title: String,
    val overview: String?,
    val posterPath: String?,
    val backdropPath: String?,
    val releaseDate: String?,
    val voteAverage: Double?,
    val matched: Boolean
) {
    fun toDomain(files: List<com.cinegram.domain.model.MediaFile>, progress: com.cinegram.domain.model.WatchProgress?): MediaItem {
        return MediaItem(
            id = id,
            title = title,
            overview = overview,
            posterPath = posterPath,
            backdropPath = backdropPath,
            releaseDate = releaseDate,
            voteAverage = voteAverage,
            matched = matched,
            mediaFiles = files,
            watchProgress = progress
        )
    }

    companion object {
        fun fromDomain(domain: MediaItem): MediaEntity {
            return MediaEntity(
                id = domain.id,
                title = domain.title,
                overview = domain.overview,
                posterPath = domain.posterPath,
                backdropPath = domain.backdropPath,
                releaseDate = domain.releaseDate,
                voteAverage = domain.voteAverage,
                matched = domain.matched
            )
        }
    }
}
