package com.cinegram.data.local.scanner

import android.content.Context
import android.provider.MediaStore
import com.cinegram.domain.model.MediaFile
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject

class MediaStoreScanner @Inject constructor(
    @ApplicationContext private val context: Context
) {
    fun scanLocalVideos(): List<MediaFile> {
        val videoFiles = mutableListOf<MediaFile>()
        
        val uri = MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Video.Media.DATA,
            MediaStore.Video.Media.DISPLAY_NAME,
            MediaStore.Video.Media.SIZE,
            MediaStore.Video.Media.DURATION,
            MediaStore.Video.Media.RESOLUTION,
            MediaStore.Video.Media.MIME_TYPE,
            MediaStore.Video.Media.DATE_ADDED
        )
        
        val cursor = context.contentResolver.query(
            uri,
            projection,
            null,
            null,
            "${MediaStore.Video.Media.DATE_ADDED} DESC"
        )
        
        cursor?.use { c ->
            val dataIndex = c.getColumnIndexOrThrow(MediaStore.Video.Media.DATA)
            val nameIndex = c.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME)
            val sizeIndex = c.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE)
            val durationIndex = c.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)
            val resolutionIndex = c.getColumnIndexOrThrow(MediaStore.Video.Media.RESOLUTION)
            val mimeTypeIndex = c.getColumnIndexOrThrow(MediaStore.Video.Media.MIME_TYPE)
            val dateAddedIndex = c.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_ADDED)
            
            while (c.moveToNext()) {
                val path = c.getString(dataIndex) ?: continue
                val name = c.getString(nameIndex) ?: path.substringAfterLast("/")
                val size = c.getLong(sizeIndex)
                val duration = c.getLong(durationIndex)
                val resolution = c.getString(resolutionIndex)
                val mimeType = c.getString(mimeTypeIndex)
                val dateAdded = c.getLong(dateAddedIndex)
                
                videoFiles.add(
                    MediaFile(
                        path = path,
                        name = name,
                        size = size,
                        duration = duration,
                        resolution = resolution,
                        mimeType = mimeType,
                        dateAdded = dateAdded
                    )
                )
            }
        }
        
        return videoFiles
    }
}
