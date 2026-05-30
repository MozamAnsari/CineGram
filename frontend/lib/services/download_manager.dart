import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';
import 'api_service.dart';

class DownloadTask {
  final String id;
  final String title;
  final String posterUrl;
  final String localPath;
  double progress; // 0.0 to 1.0
  int downloadedBytes;
  int totalBytes;
  String status; // 'pending', 'downloading', 'paused', 'completed', 'failed'
  String speed; // e.g. "1.5 MB/s"

  DownloadTask({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.localPath,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.status = 'pending',
    this.speed = '0 KB/s',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'posterUrl': posterUrl,
        'localPath': localPath,
        'progress': progress,
        'downloadedBytes': downloadedBytes,
        'totalBytes': totalBytes,
        'status': status,
      };

  factory DownloadTask.fromJson(Map<String, dynamic> json) => DownloadTask(
        id: json['id'] ?? '',
        title: json['title'] ?? 'Unknown Movie',
        posterUrl: json['posterUrl'] ?? '',
        localPath: json['localPath'] ?? '',
        progress: (json['progress'] ?? 0.0).toDouble(),
        downloadedBytes: json['downloadedBytes'] ?? 0,
        totalBytes: json['totalBytes'] ?? 0,
        status: json['status'] ?? 'pending',
      );
}

class DownloadManager with ChangeNotifier {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  static const String _prefKey = 'cinegram_downloads_catalog';
  final List<DownloadTask> _tasks = [];
  final Map<String, CancelToken> _cancelTokens = {};

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCatalog = prefs.getString(_prefKey);
      if (savedCatalog != null) {
        final List<dynamic> decoded = jsonDecode(savedCatalog);
        _tasks.clear();
        for (var item in decoded) {
          final task = DownloadTask.fromJson(item);
          // If the task was interrupted (left in 'downloading' or 'pending'), mark it 'paused'
          if (task.status == 'downloading' || task.status == 'pending') {
            task.status = 'paused';
          }
          // Double check if the local file actually exists for completed tasks
          if (task.status == 'completed') {
            final file = File(task.localPath);
            if (!await file.exists()) {
              task.status = 'failed';
            }
          }
          _tasks.add(task);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error initializing DownloadManager: $e');
    }
  }

  Future<void> _saveCatalog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_tasks.map((t) => t.toJson()).toList());
      await prefs.setString(_prefKey, encoded);
    } catch (e) {
      debugPrint('Error saving download catalog: $e');
    }
  }

  DownloadTask? getTask(String mediaId) {
    try {
      return _tasks.firstWhere((t) => t.id == mediaId);
    } catch (_) {
      return null;
    }
  }

  bool isDownloaded(String mediaId) {
    final task = getTask(mediaId);
    return task != null && task.status == 'completed';
  }

  Future<String> _getVaultDirectory() async {
    // Determine the best platform-agnostic storage directory
    String path;
    if (kIsWeb) {
      path = '/cinegram_vault';
    } else {
      // Relative vault for Simulators, Desktop & Mock sandbox operations
      path = './cinegram_vault';
      // In case we run in constrained paths, double check and fallback to system temp
      try {
        final dir = Directory(path);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      } catch (_) {
        path = '${Directory.systemTemp.path}/cinegram_vault';
      }
    }
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  Future<void> startDownload(MediaItem mediaItem, String channelId, String messageId) async {
    // 1. Avoid duplicate downloads
    final existing = getTask(mediaItem.id);
    if (existing != null) {
      if (existing.status == 'downloading') return;
      // Resume download
      existing.status = 'downloading';
      notifyListeners();
      _executeDownload(existing, channelId, messageId);
      return;
    }

    // 2. Resolve target paths
    final vaultDir = await _getVaultDirectory();
    final sanitizedTitle = mediaItem.title.replaceAll(RegExp(r'[^\w\s\-\.]'), '_');
    const fileExt = 'mp4';
    final localPath = '$vaultDir/${sanitizedTitle}_${mediaItem.id}.$fileExt';

    final task = DownloadTask(
      id: mediaItem.id,
      title: mediaItem.title,
      posterUrl: mediaItem.posterUrl,
      localPath: localPath,
      status: 'pending',
    );

    _tasks.add(task);
    await _saveCatalog();
    notifyListeners();

    task.status = 'downloading';
    notifyListeners();
    _executeDownload(task, channelId, messageId);
  }

  Future<void> _executeDownload(DownloadTask task, String channelId, String messageId) async {
    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;

    final tempPath = '${task.localPath}.tmp';
    final streamUrl = '${ApiService.baseUrl}/stream?channelId=$channelId&messageId=$messageId';

    final dio = Dio();
    DateTime lastProgressTime = DateTime.now();
    int lastProgressBytes = 0;

    try {
      debugPrint('Starting stream download for "${task.title}" from: $streamUrl');
      await dio.download(
        streamUrl,
        tempPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          final now = DateTime.now();
          final duration = now.difference(lastProgressTime);
          
          if (total != -1) {
            task.progress = received / total;
            task.downloadedBytes = received;
            task.totalBytes = total;
          } else {
            // Chunked encoding fallback
            task.downloadedBytes = received;
            task.progress = 0.5; // indefinite progress
          }

          // Calculate speed estimate every 500ms
          if (duration.inMilliseconds >= 500) {
            final bytesSent = received - lastProgressBytes;
            final speedBytesPerSec = (bytesSent * 1000) / duration.inMilliseconds;
            
            if (speedBytesPerSec > 1024 * 1024) {
              task.speed = '${(speedBytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
            } else {
              task.speed = '${(speedBytesPerSec / 1024).toStringAsFixed(0)} KB/s';
            }

            lastProgressTime = now;
            lastProgressBytes = received;
            notifyListeners();
          }
        },
      );

      // Successfully finished download, clean up temp file and finalize
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.rename(task.localPath);
      }

      task.status = 'completed';
      task.progress = 1.0;
      task.speed = '0 KB/s';
      _cancelTokens.remove(task.id);
      await _saveCatalog();
      notifyListeners();
      debugPrint('Download complete: "${task.title}" -> saved in local vault: ${task.localPath}');

    } catch (e) {
      _cancelTokens.remove(task.id);
      if (CancelToken.isCancel(e as DioException)) {
        task.status = 'paused';
        task.speed = 'Paused';
        debugPrint('Download paused by user: "${task.title}"');
      } else {
        task.status = 'failed';
        task.speed = 'Failed';
        debugPrint('Download error: $e');
      }
      await _saveCatalog();
      notifyListeners();
    }
  }

  void pauseDownload(String mediaId) {
    final token = _cancelTokens[mediaId];
    if (token != null) {
      token.cancel();
      _cancelTokens.remove(mediaId);
    }
    final task = getTask(mediaId);
    if (task != null) {
      task.status = 'paused';
      task.speed = 'Paused';
      notifyListeners();
      _saveCatalog();
    }
  }

  Future<void> deleteDownload(String mediaId) async {
    pauseDownload(mediaId);
    final task = getTask(mediaId);
    if (task != null) {
      try {
        final file = File(task.localPath);
        if (await file.exists()) {
          await file.delete();
        }
        final tempFile = File('${task.localPath}.tmp');
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        debugPrint('Error deleting download files: $e');
      }

      _tasks.removeWhere((t) => t.id == mediaId);
      await _saveCatalog();
      notifyListeners();
    }
  }
}
