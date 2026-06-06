package com.cinegram.data.local.db

import androidx.room.Database
import androidx.room.RoomDatabase
import com.cinegram.data.local.db.dao.MediaDao
import com.cinegram.data.local.db.dao.WatchProgressDao
import com.cinegram.data.local.db.entity.MediaEntity
import com.cinegram.data.local.db.entity.MediaFileEntity
import com.cinegram.data.local.db.entity.WatchProgressEntity

@Database(
    entities = [
        MediaEntity::class,
        MediaFileEntity::class,
        WatchProgressEntity::class
    ],
    version = 1,
    exportSchema = false
)
abstract class CinegramDatabase : RoomDatabase() {
    abstract fun mediaDao(): MediaDao
    abstract fun watchProgressDao(): WatchProgressDao
}
