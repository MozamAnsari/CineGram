import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExternalPlayer {
  final String name;
  final String package;
  final String icon;

  const ExternalPlayer({
    required this.name,
    required this.package,
    required this.icon,
  });

  Map<String, String> toMap() {
    return {
      'name': name,
      'package': package,
      'icon': icon,
    };
  }
}

class ExternalPlayerService {
  static const MethodChannel _channel = MethodChannel('cinegram/external_player');

  static const String _useExternalPlayerKey = 'use_external_player';
  static const String _selectedPlayerPackageKey = 'selected_external_player_package';
  static const String _selectedPlayerNameKey = 'selected_external_player_name';

  /// Standard simulated players for non-Android / Desktop / Dev environments
  static const List<ExternalPlayer> mockPlayers = [
    ExternalPlayer(
      name: "System Default Player",
      package: "android.intent.action.VIEW",
      icon: "default",
    ),
    ExternalPlayer(
      name: "VLC Media Player",
      package: "org.videolan.vlc",
      icon: "vlc",
    ),
    ExternalPlayer(
      name: "MX Player",
      package: "com.mxtech.videoplayer.ad",
      icon: "mx",
    ),
    ExternalPlayer(
      name: "Nova Video Player",
      package: "org.nova.video",
      icon: "nova",
    ),
    ExternalPlayer(
      name: "Kodi",
      package: "org.xbmc.kodi",
      icon: "kodi",
    ),
  ];

  /// Detects all video players on the mobile device.
  /// Falls back to simulated list on non-Android platforms.
  static Future<List<Map<String, String>>> detectPlayers() async {
    if (kIsWeb || !Platform.isAndroid) {
      debugPrint('[ExternalPlayerService] Non-Android platform. Returning simulated players.');
      return mockPlayers.map((p) => p.toMap()).toList();
    }

    try {
      final List<dynamic>? players = await _channel.invokeMethod<List<dynamic>>('detectPlayers');
      if (players != null) {
        return players.map((p) => Map<String, String>.from(p as Map)).toList();
      }
    } catch (e) {
      debugPrint('[ExternalPlayerService] Failed to detect native players: $e. Using fallback list.');
    }

    return mockPlayers.map((p) => p.toMap()).toList();
  }

  /// Launches a video URL/file path in the selected external player.
  static Future<bool> launchPlayer(String? packageName, String videoUrl, String title) async {
    debugPrint('[ExternalPlayerService] Launching $videoUrl in package $packageName (Title: "$title")');
    
    if (kIsWeb || !Platform.isAndroid) {
      debugPrint('[ExternalPlayerService] Simulation Mode: Video successfully opened in external player $packageName!');
      return true;
    }

    try {
      final bool? success = await _channel.invokeMethod<bool>('launchPlayer', {
        'packageName': packageName,
        'videoUrl': videoUrl,
        'title': title,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('[ExternalPlayerService] Error launching external player: $e');
      return false;
    }
  }

  /// Get status of whether "Always use external player" settings toggle is enabled
  static Future<bool> isExternalPlayerEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_useExternalPlayerKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Set status of whether "Always use external player" settings toggle is enabled
  static Future<void> setExternalPlayerEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_useExternalPlayerKey, enabled);
    } catch (e) {
      debugPrint('[ExternalPlayerService] Error saving external player toggle state: $e');
    }
  }

  /// Get package name of currently selected external player
  static Future<String?> getSelectedPlayerPackage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_selectedPlayerPackageKey);
    } catch (e) {
      return null;
    }
  }

  /// Set package name of currently selected external player
  static Future<void> setSelectedPlayerPackage(String? package) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (package == null) {
        await prefs.remove(_selectedPlayerPackageKey);
      } else {
        await prefs.setString(_selectedPlayerPackageKey, package);
      }
    } catch (e) {
      debugPrint('[ExternalPlayerService] Error saving selected player package: $e');
    }
  }

  /// Get friendly name of currently selected external player
  static Future<String?> getSelectedPlayerName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_selectedPlayerNameKey) ?? "System Default Player";
    } catch (e) {
      return "System Default Player";
    }
  }

  /// Set friendly name of currently selected external player
  static Future<void> setSelectedPlayerName(String? name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (name == null) {
        await prefs.remove(_selectedPlayerNameKey);
      } else {
        await prefs.setString(_selectedPlayerNameKey, name);
      }
    } catch (e) {
      debugPrint('[ExternalPlayerService] Error saving selected player name: $e');
    }
  }
}
