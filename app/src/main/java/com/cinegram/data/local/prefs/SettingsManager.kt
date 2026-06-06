package com.cinegram.data.local.prefs

import android.content.Context
import android.content.SharedPreferences
import com.cinegram.BuildConfig
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SettingsManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val prefs: SharedPreferences = context.getSharedPreferences("cinegram_prefs", Context.MODE_PRIVATE)

    companion object {
        private const val KEY_TMDB_API_KEY = "tmdb_api_key"
    }

    fun getTmdbApiKey(): String {
        val userKey = prefs.getString(KEY_TMDB_API_KEY, "")
        if (!userKey.isNullOrBlank()) {
            return userKey
        }
        return BuildConfig.TMDB_API_KEY
    }

    fun saveTmdbApiKey(key: String) {
        prefs.edit().putString(KEY_TMDB_API_KEY, key.trim()).apply()
    }
}
