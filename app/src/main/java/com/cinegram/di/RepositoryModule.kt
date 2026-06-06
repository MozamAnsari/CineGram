package com.cinegram.di

import com.cinegram.data.repository.MediaRepositoryImpl
import com.cinegram.data.repository.WatchProgressRepositoryImpl
import com.cinegram.domain.repository.MediaRepository
import com.cinegram.domain.repository.WatchProgressRepository
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {

    @Binds
    @Singleton
    abstract fun bindMediaRepository(
        mediaRepositoryImpl: MediaRepositoryImpl
    ): MediaRepository

    @Binds
    @Singleton
    abstract fun bindWatchProgressRepository(
        watchProgressRepositoryImpl: WatchProgressRepositoryImpl
    ): WatchProgressRepository
}
