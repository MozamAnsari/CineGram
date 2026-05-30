import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cinegram/models/media.dart';
import 'package:cinegram/models/media_item.dart';
import 'package:cinegram/services/api_service.dart';
import 'package:cinegram/services/download_manager.dart';

class TvPlayerScreen extends StatefulWidget {
  final Media? media;
  final MediaItem? mediaItem;
  final String? channelId;
  final String? messageId;
  final String? streamUrl;

  const TvPlayerScreen({
    super.key,
    this.media,
    this.mediaItem,
    this.channelId,
    this.messageId,
    this.streamUrl,
  });

  @override
  State<TvPlayerScreen> createState() => _TvPlayerScreenState();
}

class _TvPlayerScreenState extends State<TvPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isError = false;
  String _errorMessage = '';
  bool _showControls = true;
  Timer? _controlsTimer;

  // Double tap skipping indicators
  bool _showLeftSkipIndicator = false;
  bool _showRightSkipIndicator = false;
  Timer? _skipLeftTimer;
  Timer? _skipRightTimer;

  // Track selectors
  bool _showSubtitlesSheet = false;
  bool _showAudioSheet = false;
  bool _showSpeedSheet = false;

  String _selectedSubtitle = 'Off';
  String _selectedAudio = 'English [Stereo]';
  double _playbackSpeed = 1.0;

  final List<String> _subtitleOptions = ['Off', 'English [SRT]', 'Spanish [SRT]', 'French [VTT]'];
  final List<String> _audioOptions = ['English [Stereo]', 'Spanish [Dolby 5.1]', 'French [Stereo]', 'Director Commentary'];
  final List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  // Toast notifications
  String? _toastMessage;
  Timer? _toastTimer;

  // Sync Watch Progress Timer
  Timer? _progressSyncTimer;

  // Focus nodes for D-pad Navigation
  late FocusNode _screenFocusNode;
  late FocusNode _backFocusNode;
  late FocusNode _subtitlesFocusNode;
  late FocusNode _audioFocusNode;
  late FocusNode _speedFocusNode;
  late FocusNode _rewindFocusNode;
  late FocusNode _playPauseFocusNode;
  late FocusNode _forwardFocusNode;

  // Unified metadata fields mapping both models
  late int _mediaId;
  late String _title;
  late String _mediaType;
  late String _releaseYear;
  late String _durationInfo;

  bool get _isAnySheetOpen => _showSubtitlesSheet || _showAudioSheet || _showSpeedSheet;

  @override
  void initState() {
    super.initState();
    _mapMetadata();
    _initFocusNodes();
    _initController();
    _startControlsTimer();

    // TV Widescreen Horizontal and Immersive Locks
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Sync progress periodically
    _progressSyncTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_controller.value.isInitialized && _controller.value.isPlaying) {
        _syncProgress();
      }
    });

    // Request initial screen focus for D-pad capture
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _screenFocusNode.requestFocus();
    });
  }

  void _mapMetadata() {
    if (widget.media != null) {
      final m = widget.media!;
      _mediaId = m.id;
      _title = m.title;
      _mediaType = m.mediaType;
      _releaseYear = m.releaseYear;
      _durationInfo = m.runtime != null ? "${m.runtime} MIN" : "N/A";
    } else if (widget.mediaItem != null) {
      final mi = widget.mediaItem!;
      // Parse a numeric id or use a fallback hashed id
      _mediaId = int.tryParse(mi.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999;
      _title = mi.title;
      _mediaType = mi.type;
      _releaseYear = mi.year;
      _durationInfo = mi.duration;
    } else {
      _mediaId = 100;
      _title = "Cinegram Presentation";
      _mediaType = "Movie";
      _releaseYear = "2026";
      _durationInfo = "120 MIN";
    }
  }

  void _initFocusNodes() {
    _screenFocusNode = FocusNode(debugLabel: "TvPlayerScreenRoot");
    _backFocusNode = FocusNode(debugLabel: "TvBackButton");
    _subtitlesFocusNode = FocusNode(debugLabel: "TvSubtitlesButton");
    _audioFocusNode = FocusNode(debugLabel: "TvAudioButton");
    _speedFocusNode = FocusNode(debugLabel: "TvSpeedButton");
    _rewindFocusNode = FocusNode(debugLabel: "TvRewindButton");
    _playPauseFocusNode = FocusNode(debugLabel: "TvPlayPauseButton");
    _forwardFocusNode = FocusNode(debugLabel: "TvForwardButton");
  }

  void _initController() {
    String streamUrl = '';
    String? localPath;
    final String mediaId = widget.mediaItem?.id ?? (widget.media != null ? 'm${widget.media!.id}' : '');
    
    // Check if the movie is downloaded in the Local Vault
    if (mediaId.isNotEmpty) {
      final downloadedTask = DownloadManager().getTask(mediaId);
      if (downloadedTask != null && downloadedTask.status == 'completed') {
        localPath = downloadedTask.localPath;
        developer.log('Found downloaded vault copy! Playing offline from: $localPath', name: 'TvPlayerScreen');
      }
    }

    if (localPath == null) {
      if (widget.streamUrl != null && widget.streamUrl!.isNotEmpty) {
        streamUrl = widget.streamUrl!;
      } else if (widget.channelId != null && widget.messageId != null) {
        streamUrl = '${ApiService.baseUrl}/stream?channelId=${widget.channelId}&messageId=${widget.messageId}';
      } else if (widget.media != null && widget.media!.streamUrl != null && widget.media!.streamUrl!.isNotEmpty) {
        streamUrl = widget.media!.streamUrl!;
      } else {
        // Standard public fallback video stream for mock testing on TV
        streamUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
      }
      developer.log('Initializing TV stream player with URL: $streamUrl', name: 'TvPlayerScreen');
    }

    if (localPath != null) {
      _controller = VideoPlayerController.file(File(localPath));
    } else {
      _controller = VideoPlayerController.networkUrl(Uri.parse(streamUrl));
    }

    _controller.initialize().then((_) {
      if (mounted) {
        setState(() {
          _isError = false;
        });
        _controller.play();
      }
    }).catchError((error) {
      developer.log('Error initializing video player on TV', name: 'TvPlayerScreen', error: error);
      if (mounted) {
        setState(() {
          _isError = true;
          _errorMessage = error.toString();
        });
      }
    });

    _controller.addListener(_videoListener);
  }

  void _videoListener() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _syncProgress();

    _progressSyncTimer?.cancel();
    _controlsTimer?.cancel();
    _skipLeftTimer?.cancel();
    _skipRightTimer?.cancel();
    _toastTimer?.cancel();

    _screenFocusNode.dispose();
    _backFocusNode.dispose();
    _subtitlesFocusNode.dispose();
    _audioFocusNode.dispose();
    _speedFocusNode.dispose();
    _rewindFocusNode.dispose();
    _playPauseFocusNode.dispose();
    _forwardFocusNode.dispose();

    _controller.removeListener(_videoListener);
    _controller.dispose();

    // Re-enable usual orientations and navigation when leaving TV screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    super.dispose();
  }

  void _syncProgress() {
    if (_controller.value.isInitialized) {
      ApiService.syncWatchProgress(
        mediaId: _mediaId,
        position: _controller.value.position,
        duration: _controller.value.duration,
      );
    }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && _controller.value.isPlaying && !_isAnySheetOpen) {
        setState(() {
          _showControls = false;
        });
        // Bring focus back to the screen root for D-pad controls
        _screenFocusNode.requestFocus();
      }
    });
  }

  void _resetControlsTimer() {
    if (mounted) {
      setState(() {
        _showControls = true;
      });
      _startControlsTimer();
    }
  }

  void _togglePlayPause() {
    _resetControlsTimer();
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _syncProgress();
      } else {
        _controller.play();
      }
    });
  }

  void _seekForward10s() {
    _resetControlsTimer();
    if (_controller.value.isInitialized) {
      final current = _controller.value.position;
      final target = current + const Duration(seconds: 10);
      _controller.seekTo(Duration(milliseconds: target.inMilliseconds.clamp(0, _controller.value.duration.inMilliseconds)));

      _skipRightTimer?.cancel();
      setState(() {
        _showRightSkipIndicator = true;
      });
      _skipRightTimer = Timer(const Duration(milliseconds: 1000), () {
        if (mounted) setState(() => _showRightSkipIndicator = false);
      });
    }
  }

  void _seekBackward10s() {
    _resetControlsTimer();
    if (_controller.value.isInitialized) {
      final current = _controller.value.position;
      final target = current - const Duration(seconds: 10);
      _controller.seekTo(Duration(milliseconds: target.inMilliseconds.clamp(0, _controller.value.duration.inMilliseconds)));

      _skipLeftTimer?.cancel();
      setState(() {
        _showLeftSkipIndicator = true;
      });
      _skipLeftTimer = Timer(const Duration(milliseconds: 1000), () {
        if (mounted) setState(() => _showLeftSkipIndicator = false);
      });
    }
  }

  void _showHUDAndFocusTop() {
    _resetControlsTimer();
    _subtitlesFocusNode.requestFocus();
  }

  void _showHUDAndFocusBottom() {
    _resetControlsTimer();
    _playPauseFocusNode.requestFocus();
  }

  void _closeAllSheets() {
    setState(() {
      _showSubtitlesSheet = false;
      _showAudioSheet = false;
      _showSpeedSheet = false;
    });
    // Request focus back onto the root screen or controls
    if (_showControls) {
      _playPauseFocusNode.requestFocus();
    } else {
      _screenFocusNode.requestFocus();
    }
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() {
      _toastMessage = message;
    });
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _toastMessage = null;
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String _formatRemaining(Duration position, Duration duration) {
    final remaining = duration - position;
    if (remaining.isNegative) return '0:00';
    return '-${_formatDuration(remaining)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isError) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _buildErrorView(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _screenFocusNode,
        autofocus: true,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (event is KeyDownEvent) {
            final key = event.logicalKey;
            developer.log("D-pad/Keyboard key: ${key.keyLabel}", name: "TvPlayerScreen");

            // Intercept direct actions if controls are hidden
            if (!_showControls && !_isAnySheetOpen) {
              if (key == LogicalKeyboardKey.arrowLeft) {
                _seekBackward10s();
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.arrowRight) {
                _seekForward10s();
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.arrowUp) {
                _showHUDAndFocusTop();
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.arrowDown) {
                _showHUDAndFocusBottom();
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.select ||
                  key == LogicalKeyboardKey.enter ||
                  key == LogicalKeyboardKey.space ||
                  key == LogicalKeyboardKey.numpadEnter) {
                _togglePlayPause();
                return KeyEventResult.handled;
              }
            } else if (_showControls && !_isAnySheetOpen) {
              // Direct seek via D-pad Arrow Keys is always useful even if bottom panel is open
              // but we only do it if the focus is NOT currently on other navigations or let focus handle it.
              if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
                setState(() {
                  _showControls = false;
                });
                _screenFocusNode.requestFocus();
                return KeyEventResult.handled;
              }
            } else if (_isAnySheetOpen) {
              if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
                _closeAllSheets();
                return KeyEventResult.handled;
              }
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: () {
            _resetControlsTimer();
          },
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // 1. VIDEO VIEWPORT
              Center(
                child: _controller.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      )
                    : SpinKitDoubleBounce(
                        color: Theme.of(context).primaryColor,
                        size: 80.0,
                      ),
              ),

              // 2. BUFFERING OVERLAY
              if (_controller.value.isInitialized && _controller.value.isBuffering)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SpinKitCircle(
                        color: Theme.of(context).primaryColor,
                        size: 60.0,
                      ),
                      SizedBox(height: 16),
                      Text(
                        "BUFFERING ULTRA HD FEED...",
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

              // 3. DIRECT D-PAD SEEK SKIP OVERLAYS
              if (_showLeftSkipIndicator)
                Center(
                  child: Padding(
                    padding: EdgeInsets.only(right: MediaQuery.of(context).size.width * 0.4),
                    child: _buildSkipIndicator("-10 SEC", Icons.fast_rewind_rounded),
                  ),
                ),
              if (_showRightSkipIndicator)
                Center(
                  child: Padding(
                    padding: EdgeInsets.only(left: MediaQuery.of(context).size.width * 0.4),
                    child: _buildSkipIndicator("+10 SEC", Icons.fast_forward_rounded),
                  ),
                ),

              // 4. TOAST NOTIFICATIONS
              if (_toastMessage != null)
                Positioned(
                  top: 100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _buildToastNotification(_toastMessage!),
                  ),
                ),

              // 5. IMMERSIVE WIDESCREEN HUD CONTROLS
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 350),
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: Stack(
                    children: [
                      // Dark gradient luxury vignette overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.9),
                                Colors.transparent,
                                Colors.transparent,
                                Colors.black.withOpacity(0.95),
                              ],
                              stops: const [0.0, 0.3, 0.7, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // TOP HUD BAR
                      _buildTopHUD(),

                      // BOTTOM HUD BAR & TIMELINE
                      _buildBottomHUD(),
                    ],
                  ),
                ),
              ),

              // 6. RIGHT-SLIDING TV SETTINGS OVERLAYS
              _buildSettingsDrawer(
                title: "SELECT SUBTITLES",
                isOpen: _showSubtitlesSheet,
                options: _subtitleOptions,
                selectedOption: _selectedSubtitle,
                onSelected: (opt) {
                  setState(() {
                    _selectedSubtitle = opt;
                    _showSubtitlesSheet = false;
                  });
                  _showToast("Subtitles: $opt");
                  _playPauseFocusNode.requestFocus();
                },
                onClose: _closeAllSheets,
              ),

              _buildSettingsDrawer(
                title: "SELECT AUDIO TRACK",
                isOpen: _showAudioSheet,
                options: _audioOptions,
                selectedOption: _selectedAudio,
                onSelected: (opt) {
                  setState(() {
                    _selectedAudio = opt;
                    _showAudioSheet = false;
                  });
                  _showToast("Audio Track: $opt");
                  _playPauseFocusNode.requestFocus();
                },
                onClose: _closeAllSheets,
              ),

              _buildSettingsDrawer(
                title: "PLAYBACK SPEED",
                isOpen: _showSpeedSheet,
                options: _speedOptions.map((e) => "${e}x").toList(),
                selectedOption: "${_playbackSpeed}x",
                onSelected: (opt) {
                  final double speed = double.parse(opt.replaceAll("x", ""));
                  _controller.setPlaybackSpeed(speed);
                  setState(() {
                    _playbackSpeed = speed;
                    _showSpeedSheet = false;
                  });
                  _showToast("Playback Speed: $opt");
                  _playPauseFocusNode.requestFocus();
                },
                onClose: _closeAllSheets,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TOP HUD BAR BUILDER
  // ==========================================
  Widget _buildTopHUD() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      top: _showControls ? 0 : -140,
      left: 0,
      right: 0,
      child: Container(
        height: 120,
        padding: const EdgeInsets.fromLTRB(40, 30, 40, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.9),
              Colors.black.withOpacity(0.6),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Side - Premium Movie/Show Title & Info Badges
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _title,
                    style: GoogleFonts.cinzel(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.4)),
                        ),
                        child: Text(
                          _mediaType.toUpperCase(),
                          style: GoogleFonts.dmSans(
                            color: Theme.of(context).primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _releaseYear,
                        style: GoogleFonts.dmSans(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "•",
                        style: TextStyle(color: Colors.white.withOpacity(0.4)),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _durationInfo,
                        style: GoogleFonts.dmSans(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          "4K ATMOS",
                          style: TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),

            // Right Side - Settings and track selection D-pad buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TvFocusButton(
                  focusNode: _subtitlesFocusNode,
                  onPressed: () {
                    _resetControlsTimer();
                    setState(() {
                      _showSubtitlesSheet = true;
                    });
                  },
                  child: Row(
                    children: [
                      Icon(Icons.subtitles_rounded, color: Theme.of(context).primaryColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _selectedSubtitle == 'Off' ? 'Subtitles' : _selectedSubtitle,
                        style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                TvFocusButton(
                  focusNode: _audioFocusNode,
                  onPressed: () {
                    _resetControlsTimer();
                    setState(() {
                      _showAudioSheet = true;
                    });
                  },
                  child: Row(
                    children: [
                      Icon(Icons.audiotrack_rounded, color: Theme.of(context).primaryColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _selectedAudio.length > 18 ? '${_selectedAudio.substring(0, 15)}...' : _selectedAudio,
                        style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                TvFocusButton(
                  focusNode: _backFocusNode,
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // BOTTOM HUD BAR BUILDER
  // ==========================================
  Widget _buildBottomHUD() {
    final position = _controller.value.position;
    final duration = _controller.value.duration;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      bottom: _showControls ? 0 : -180,
      left: 0,
      right: 0,
      child: Container(
        height: 160,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.95),
              Colors.black.withOpacity(0.75),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 1. TIMELINE & DURATION LABELS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: duration.inMilliseconds > 0
                            ? position.inMilliseconds / duration.inMilliseconds
                            : 0.0,
                        backgroundColor: Colors.white.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                        minHeight: 6,
                      ),
                    ),
                  ),
                ),
                Text(
                  _formatRemaining(position, duration),
                  style: GoogleFonts.dmSans(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. BOTTOM ACTION BUTTON ROW
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Playback Speed Toggle Button (TV focusable)
                TvFocusButton(
                  focusNode: _speedFocusNode,
                  onPressed: () {
                    _resetControlsTimer();
                    setState(() {
                      _showSpeedSheet = true;
                    });
                  },
                  child: Row(
                    children: [
                      Icon(Icons.speed_rounded, color: Theme.of(context).primaryColor, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        "${_playbackSpeed}x",
                        style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 40),

                // Seek 10s Backward Button
                TvFocusButton(
                  focusNode: _rewindFocusNode,
                  onPressed: _seekBackward10s,
                  child: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 24),

                // Large Main Luxury Play/Pause
                TvFocusButton(
                  focusNode: _playPauseFocusNode,
                  autofocus: true,
                  onPressed: _togglePlayPause,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Icon(
                      _controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Theme.of(context).primaryColor,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                // Seek 10s Forward Button
                TvFocusButton(
                  focusNode: _forwardFocusNode,
                  onPressed: _seekForward10s,
                  child: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 40),

                // Remote D-pad control guide badge
                Text(
                  "D-PAD [▲▼] HUD  •  [◀▶] SEEK",
                  style: GoogleFonts.dmSans(
                    color: Colors.white24,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // RIGHT-SLIDING TV DRAWER
  // ==========================================
  Widget _buildSettingsDrawer({
    required String title,
    required bool isOpen,
    required List<String> options,
    required String selectedOption,
    required Function(String) onSelected,
    required VoidCallback onClose,
  }) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      right: isOpen ? 0 : -340,
      top: 0,
      bottom: 0,
      width: 320,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xEE0C0C14),
              border: Border(
                left: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header of Drawer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.cinzel(
                        color: Theme.of(context).primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                      onPressed: onClose,
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 20, thickness: 1),
                const SizedBox(height: 12),

                // Options List with autofocus capability
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final opt = options[index];
                      final isSel = opt == selectedOption;
                      return TvFocusListItem(
                        label: opt,
                        isSelected: isSel,
                        autofocus: index == 0 && isOpen, // autofocus the first item of selection
                        onTap: () => onSelected(opt),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Guidance Info
                Text(
                  "Use D-PAD [▲▼] to choose, [SELECT] to set",
                  style: GoogleFonts.dmSans(
                    color: Colors.white24,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // DECORATIVE UTILITIES & OVERLAYS
  // ==========================================
  Widget _buildSkipIndicator(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.15),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 26),
          const SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.dmSans(
              color: Theme.of(context).primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToastNotification(String text) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.35), width: 1.2),
          ),
          child: Text(
            text,
            style: GoogleFonts.dmSans(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Theme.of(context).primaryColor,
              size: 70,
            ),
            const SizedBox(height: 20),
            Text(
              "TV PLAYBACK ERROR",
              style: GoogleFonts.cinzel(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Connection to the gateway MTProto stream could not be resolved.\nPlease verify the host backend is active.",
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TvFocusButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text("Go Back", style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                TvFocusButton(
                  autofocus: true,
                  onPressed: () {
                    setState(() {
                      _isError = false;
                      _errorMessage = '';
                    });
                    _controller.removeListener(_videoListener);
                    _controller.dispose();

                    // Re-initialize with high-quality fallback demo
                    _controller = VideoPlayerController.networkUrl(
                      Uri.parse('https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4'),
                    )..initialize().then((_) {
                        if (mounted) {
                          setState(() {});
                          _controller.play();
                        }
                      }).catchError((err) {
                        if (mounted) {
                          setState(() {
                            _isError = true;
                            _errorMessage = err.toString();
                          });
                        }
                      });
                    _controller.addListener(_videoListener);
                  },
                  child: Row(
                    children: [
                      Icon(Icons.play_circle_outline_rounded, color: Theme.of(context).primaryColor, size: 18),
                      const SizedBox(width: 8),
                      Text("Play Demo Feed", style: GoogleFonts.dmSans(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TV-FRIENDLY BUTTON WIDGET WITH PREMIUM D-PAD FOCUS HIGHLIGHT AND HOVER STATES
// ============================================================================
class TvFocusButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final bool autofocus;

  const TvFocusButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  State<TvFocusButton> createState() => _TvFocusButtonState();
}

class _TvFocusButtonState extends State<TvFocusButton> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.space ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _isFocused ? Theme.of(context).primaryColor.withOpacity(0.18) : Colors.white.withOpacity(0.04),
            border: Border.all(
              color: _isFocused ? Theme.of(context).primaryColor : Colors.white.withOpacity(0.12),
              width: _isFocused ? 2.0 : 1.0,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.25),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: widget.child,
        ),
      ),
    );
  }
}

// ============================================================================
// TV-FRIENDLY SELECTOR LIST ITEM FOR SIDE BAR DRAWER
// ============================================================================
class TvFocusListItem extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool autofocus;

  const TvFocusListItem({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  State<TvFocusListItem> createState() => _TvFocusListItemState();
}

class _TvFocusListItemState extends State<TvFocusListItem> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.space ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _isFocused
                ? Theme.of(context).primaryColor.withOpacity(0.2)
                : widget.isSelected
                    ? Theme.of(context).primaryColor.withOpacity(0.08)
                    : Colors.transparent,
            border: Border.all(
              color: _isFocused
                  ? Theme.of(context).primaryColor
                  : widget.isSelected
                      ? Theme.of(context).primaryColor.withOpacity(0.4)
                      : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: GoogleFonts.dmSans(
                    color: _isFocused
                        ? Theme.of(context).primaryColor
                        : widget.isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.white70,
                    fontWeight: widget.isSelected || _isFocused ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
              if (widget.isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: Theme.of(context).primaryColor,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
