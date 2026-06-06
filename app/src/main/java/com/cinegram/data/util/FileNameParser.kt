package com.cinegram.data.util

import java.util.regex.Pattern

object FileNameParser {
    private val YEAR_PATTERN = Pattern.compile("\\b(19|20)\\d{2}\\b")
    
    private val CLEAN_PATTERNS = listOf(
        "\\b(1080p|720p|480p|2160p|4k|bluray|web-dl|webdl|hdtv|x264|x265|hevc|dd5\\.1|dual|audio|multi|sub|eng|ita|fre|spa|ger|rus)\\b.*",
        "[\\[\\](){}_.]"
    )

    data class ParsedInfo(
        val title: String,
        val year: String?
    )

    fun parse(fileName: String): ParsedInfo {
        val nameWithoutExtension = fileName.substringBeforeLast(".")
        
        var year: String? = null
        val yearMatcher = YEAR_PATTERN.matcher(nameWithoutExtension)
        if (yearMatcher.find()) {
            year = yearMatcher.group()
        }

        var cleanTitle = nameWithoutExtension
        
        CLEAN_PATTERNS.forEach { regex ->
            cleanTitle = cleanTitle.replace(regex.toRegex(RegexOption.IGNORE_CASE), " ")
        }
        
        cleanTitle = cleanTitle.replace("\\s+".toRegex(), " ").trim()
        
        if (cleanTitle.isEmpty()) {
            cleanTitle = nameWithoutExtension
        }

        return ParsedInfo(
            title = cleanTitle,
            year = year
        )
    }
}
