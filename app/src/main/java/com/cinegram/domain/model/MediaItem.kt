package com.cinegram.domain.model

data class MediaItem(
    val id: String,
    val title: String,
    val overview: String?,
    val posterPath: String?,
    val backdropPath: String?,
    val releaseDate: String?,
    val voteAverage: Double?,
    val matched: Boolean,
    val mediaFiles: List<MediaFile> = emptyList(),
    val watchProgress: WatchProgress? = null
)
