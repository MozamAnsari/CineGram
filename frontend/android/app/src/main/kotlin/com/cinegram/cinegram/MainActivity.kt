package com.cinegram.cinegram

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "cinegram/external_player"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "detectPlayers" -> {
                    val players = detectVideoPlayers()
                    result.success(players)
                }
                "launchPlayer" -> {
                    val packageName = call.argument<String>("packageName")
                    val videoUrl = call.argument<String>("videoUrl")
                    val title = call.argument<String>("title")
                    
                    if (videoUrl == null) {
                        result.error("INVALID_ARGUMENTS", "Video URL is missing", null)
                        return@setMethodCallHandler
                    }
                    
                    val success = launchExternalPlayer(packageName, videoUrl, title)
                    result.success(success)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun detectVideoPlayers(): List<Map<String, String>> {
        val playersList = mutableListOf<Map<String, String>>()
        
        // Add System Default Option
        playersList.add(mapOf(
            "name" to "System Default Player",
            "package" to "android.intent.action.VIEW",
            "icon" to "default"
        ))

        try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(Uri.parse("http://localhost/dummy.mp4"), "video/*")
            }
            
            val pm = packageManager
            val activities = pm.queryIntentActivities(intent, 0)
            
            for (resolveInfo in activities) {
                val pName = resolveInfo.activityInfo.packageName
                // Skip ourselves
                if (pName == packageName) continue

                val label = resolveInfo.loadLabel(pm).toString()
                
                // Avoid duplicates in case of multiple activity handlers inside same package
                if (playersList.none { it["package"] == pName }) {
                    playersList.add(mapOf(
                        "name" to label,
                        "package" to pName,
                        "icon" to getBrandIconType(pName)
                    ))
                }
            }
        } catch (e: Exception) {
            // Fallback: If querying fails, inject popular packages
            val knownPlayers = listOf(
                "org.videolan.vlc" to "VLC Media Player",
                "com.mxtech.videoplayer.ad" to "MX Player",
                "com.mxtech.videoplayer.pro" to "MX Player Pro",
                "org.nova.video" to "Nova Video Player",
                "org.xbmc.kodi" to "Kodi",
                "com.brouken.player" to "Just Player"
            )
            
            for ((pkg, name) in knownPlayers) {
                if (isPackageInstalled(pkg)) {
                    playersList.add(mapOf(
                        "name" to name,
                        "package" to pkg,
                        "icon" to getBrandIconType(pkg)
                    ))
                }
            }
        }

        return playersList
    }

    private fun getBrandIconType(packageName: String): String {
        return when {
            packageName.contains("videolan.vlc") -> "vlc"
            packageName.contains("mxtech.videoplayer") -> "mx"
            packageName.contains("nova.video") -> "nova"
            packageName.contains("kodi") -> "kodi"
            packageName.contains("brouken.player") -> "justplayer"
            else -> "generic"
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun launchExternalPlayer(packageName: String?, videoUrl: String, title: String?): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(Uri.parse(videoUrl), "video/*")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                
                if (!packageName.isNullOrEmpty() && packageName != "android.intent.action.VIEW") {
                    setPackage(packageName)
                }

                // Add stream title for standard players
                putExtra("title", title ?: "Cinegram Stream")
                
                // Specific Extras for MX Player
                putExtra("title", title ?: "Cinegram Stream")
                putExtra("sticky", false)
                
                // Specific Extras for VLC
                putExtra("title", title ?: "Cinegram Stream")
                putExtra("from_start", true)
            }
            
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
}
