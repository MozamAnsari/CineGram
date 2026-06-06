package com.cinegram.domain.model

data class WatchProgress(
    val mediaId: String,
    val filePath: String,
    val lastPosition: Long,
    val duration: Long,
    val lastUpdated: Long
)
