package com.cinegram.di

import android.content.Context
import androidx.room.Room
import com.cinegram.data.local.db.CinegramDatabase
import com.cinegram.data.local.db.dao.MediaDao
import com.cinegram.data.local.db.dao.WatchProgressDao
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): CinegramDatabase {
        return Room.databaseBuilder(
            context,
            CinegramDatabase::class.java,
            "cinegram.db"
        ).build()
    }

    @Provides
    fun provideMediaDao(db: CinegramDatabase): MediaDao {
        return db.mediaDao()
    }

    @Provides
    fun provideWatchProgressDao(db: CinegramDatabase): WatchProgressDao {
        return db.watchProgressDao()
    }
}
