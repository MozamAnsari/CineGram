package com.cinegram.data.remote.api

import retrofit2.http.GET
import retrofit2.http.Query

interface TmdbService {
    @GET("search/movie")
    suspend fun searchMovie(
        @Query("query") query: String,
        @Query("api_key") apiKey: String,
        @Query("language") language: String = "en-US",
        @Query("page") page: Int = 1
    ): TmdbSearchResponse
}

data class TmdbSearchResponse(
    val results: List<TmdbMovieDto>
)

data class TmdbMovieDto(
    val id: Long,
    val title: String,
    val overview: String?,
    val poster_path: String?,
    val backdrop_path: String?,
    val release_date: String?,
    val vote_average: Double?
)
