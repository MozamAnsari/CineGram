package com.cinegram.data.local.db.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import com.cinegram.domain.model.MediaFile

@Entity(
    tableName = "media_files",
    foreignKeys = [
        ForeignKey(
            entity = MediaEntity::class,
            parentColumns = ["id"],
            childColumns = ["mediaId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index(value = ["mediaId"])]
)
data class MediaFileEntity(
    @PrimaryKey val path: String,
    val mediaId: String,
    val name: String,
    val size: Long,
    val duration: Long,
    val resolution: String?,
    val mimeType: String?,
    val dateAdded: Long
) {
    fun toDomain(): MediaFile {
        return MediaFile(
            path = path,
            name = name,
            size = size,
            duration = duration,
            resolution = resolution,
            mimeType = mimeType,
            dateAdded = dateAdded
        )
    }

    companion object {
        fun fromDomain(domain: MediaFile, mediaId: String): MediaFileEntity {
            return MediaFileEntity(
                path = domain.path,
                mediaId = mediaId,
                name = domain.name,
                size = domain.size,
                duration = domain.duration,
                resolution = domain.resolution,
                mimeType = domain.mimeType,
                dateAdded = domain.dateAdded
            )
        }
    }
}
