package com.cinegram.data.local.db.entity

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.cinegram.domain.model.WatchProgress

@Entity(tableName = "watch_progress")
data class WatchProgressEntity(
    @PrimaryKey val filePath: String,
    val mediaId: String,
    val lastPosition: Long,
    val duration: Long,
    val lastUpdated: Long
) {
    fun toDomain(): WatchProgress {
        return WatchProgress(
            mediaId = mediaId,
            filePath = filePath,
            lastPosition = lastPosition,
            duration = duration,
            lastUpdated = lastUpdated
        )
    }

    companion object {
        fun fromDomain(domain: WatchProgress): WatchProgressEntity {
            return WatchProgressEntity(
                mediaId = domain.mediaId,
                filePath = domain.filePath,
                lastPosition = domain.lastPosition,
                duration = domain.duration,
                lastUpdated = domain.lastUpdated
            )
        }
    }
}
