package com.cinegram.domain.model

data class MediaFile(
    val path: String,
    val name: String,
    val size: Long,
    val duration: Long,
    val resolution: String?,
    val mimeType: String?,
    val dateAdded: Long
)
