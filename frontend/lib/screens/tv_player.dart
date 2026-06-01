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
  final String? watchPartyRoomId;
  final bool isHost;

  const TvPlayerScreen({
    super.key,
    this.media,
    this.mediaItem,
    this.channelId,
    this.messageId,
    this.streamUrl,
    this.watchPartyRoomId,
    this.isHost = false,
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

  final List<String> _subtitleOptions = ['Off', 'English [SRT]', 'Spanish [SRT]', 'French [VTT]', 'Subtitle Styling Customizer'];
  final List<String> _audioOptions = ['English [Stereo]', 'Spanish [Dolby 5.1]', 'French [Stereo]', 'Director Commentary'];
  final List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  // Toast notifications
  String? _toastMessage;
  Timer? _toastTimer;

  // Sync Watch Progress Timer
  Timer? _progressSyncTimer;

  // Subtitle customizer states
  bool _showSubtitleStylesSheet = false;
  double _subtitleFontSize = 24.0;
  String _subtitleColorName = 'White';
  double _subtitleBackgroundOpacity = 0.4;
  double _subtitleOutlineWeight = 2.0;
  List<dynamic> _currentSubtitleTracks = [];
  String _activeSubtitleText = '';

  // Smart Skip & Autoplay states
  bool _showSkipIntro = false;
  bool _showNextEpisodeCountdown = false;
  int _nextEpisodeCountdownSeconds = 5;
  Timer? _autoplayTimer;
  bool _didTriggerAutoplay = false;
  late FocusNode _skipIntroFocusNode;
  late FocusNode _nextEpisodeFocusNode;

  // Watch Party states
  String? _watchPartyRoomId;
  bool _isWatchPartyHost = false;
  Timer? _watchPartySyncTimer;
  List<Map<String, dynamic>> _floatingEmojis = [];
  Timer? _emojiTicker;
  final List<String> _reactionEmojis = ['❤️', '😂', '😮', '🔥'];
  late FocusNode _subtitleStylesFocusNode;
  late FocusNode _emojiReactionFocusNode;

  // Focus nodes for D-pad Navigation
  late FocusNode _screenFocusNode;
  late FocusNode _backFocusNode;
  late FocusNode _subtitlesFocusNode;
  late FocusNode _audioFocusNode;
  late FocusNode _speedFocusNode;
  late FocusNode _rewindFocusNode;
  late FocusNode _playPauseFocusNode;
  late FocusNode _forwardFocusNode;
  late FocusNode _highlightFocusNode;
  late FocusNode _dialogCopyFocusNode;
  late FocusNode _dialogDismissFocusNode;

  // Highlight/Scissors state variables
  bool _showHighlightDialog = false;
  String _highlightShareCode = '';
  bool _isCreatingHighlight = false;

  // Unified metadata fields mapping both models
  late int _mediaId;
  late String _title;
  late String _mediaType;
  late String _releaseYear;
  late String _durationInfo;

  bool get _isAnySheetOpen =>
      _showSubtitlesSheet ||
      _showAudioSheet ||
      _showSpeedSheet ||
      _showSubtitleStylesSheet ||
      _showHighlightDialog;

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
      if (_controller.value.isInitialized && _controller.value.isPlaying && _watchPartyRoomId == null) {
        _syncProgress();
      }
    });

    _watchPartyRoomId = widget.watchPartyRoomId;
    _isWatchPartyHost = widget.isHost;
    if (_watchPartyRoomId != null) {
      _startWatchPartySync();
    }

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
    _highlightFocusNode = FocusNode(debugLabel: "TvHighlightButton");
    _dialogCopyFocusNode = FocusNode(debugLabel: "TvHighlightDialogCopyButton");
    _dialogDismissFocusNode = FocusNode(debugLabel: "TvHighlightDialogDismissButton");
    _subtitleStylesFocusNode = FocusNode(debugLabel: "TvSubtitleStylesButton");
    _emojiReactionFocusNode = FocusNode(debugLabel: "TvEmojiReactionButton");
    _skipIntroFocusNode = FocusNode(debugLabel: "TvSkipIntroButton");
    _nextEpisodeFocusNode = FocusNode(debugLabel: "TvNextEpisodeButton");
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
      final String? resolvedChannelId = widget.channelId ?? widget.mediaItem?.channelId;
      final String? resolvedMessageId = widget.messageId ?? widget.mediaItem?.messageId;

      if (widget.streamUrl != null && widget.streamUrl!.isNotEmpty) {
        streamUrl = widget.streamUrl!;
      } else if (resolvedChannelId != null && resolvedMessageId != null) {
        streamUrl = '${ApiService.baseUrl}/stream?channelId=$resolvedChannelId&messageId=$resolvedMessageId';
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
      _updateSubtitles();
      _checkSmartSkip();
      setState(() {});
    }
  }

  void _checkSmartSkip() {
    if (!_controller.value.isInitialized) return;
    final pos = _controller.value.position;
    final dur = _controller.value.duration;

    // 1. Skip Intro Window (5s to 90s)
    if (pos.inSeconds >= 5 && pos.inSeconds <= 90) {
      if (!_showSkipIntro) {
        setState(() {
          _showSkipIntro = true;
        });
      }
    } else {
      if (_showSkipIntro) {
        setState(() {
          _showSkipIntro = false;
        });
      }
    }

    // 2. Outro Autoplay Window (last 30s)
    if (dur.inSeconds > 90 && dur.inSeconds - pos.inSeconds <= 30) {
      if (!_showNextEpisodeCountdown && !_didTriggerAutoplay) {
        _startAutoplayCountdown();
      }
    } else {
      if (pos.inSeconds < dur.inSeconds - 45) {
        // Reset if sought backwards
        if (_didTriggerAutoplay || _showNextEpisodeCountdown) {
          setState(() {
            _didTriggerAutoplay = false;
            _showNextEpisodeCountdown = false;
            _autoplayTimer?.cancel();
          });
        }
      }
    }
  }

  void _startAutoplayCountdown() {
    setState(() {
      _showNextEpisodeCountdown = true;
      _nextEpisodeCountdownSeconds = 5;
    });
    
    // Autofocus the next episode countdown D-pad button
    _nextEpisodeFocusNode.requestFocus();
    
    _autoplayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_nextEpisodeCountdownSeconds > 1) {
            _nextEpisodeCountdownSeconds--;
          } else {
            _autoplayTimer?.cancel();
            _triggerAutoplay();
          }
        });
      } else {
        _autoplayTimer?.cancel();
      }
    });
  }

  void _triggerAutoplay() {
    if (_didTriggerAutoplay) return;
    _didTriggerAutoplay = true;
    _autoplayTimer?.cancel();
    
    // Find next episode dynamically
    final nextIndex = mockMediaDatabase.indexWhere((x) => x.id == widget.mediaItem?.id) + 1;
    if (nextIndex < mockMediaDatabase.length) {
      final nextItem = mockMediaDatabase[nextIndex];
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => TvPlayerScreen(
            mediaItem: nextItem,
            watchPartyRoomId: _watchPartyRoomId,
            isHost: _isWatchPartyHost,
          ),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Autoplay: Launching next episode: ${nextItem.title}"),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    } else {
      Navigator.pop(context);
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
    _watchPartySyncTimer?.cancel();
    _emojiTicker?.cancel();
    _autoplayTimer?.cancel();

    _screenFocusNode.dispose();
    _backFocusNode.dispose();
    _subtitlesFocusNode.dispose();
    _audioFocusNode.dispose();
    _speedFocusNode.dispose();
    _rewindFocusNode.dispose();
    _playPauseFocusNode.dispose();
    _forwardFocusNode.dispose();
    _highlightFocusNode.dispose();
    _dialogCopyFocusNode.dispose();
    _dialogDismissFocusNode.dispose();
    _subtitleStylesFocusNode.dispose();
    _emojiReactionFocusNode.dispose();
    _skipIntroFocusNode.dispose();
    _nextEpisodeFocusNode.dispose();

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

  void _createHighlightClip() async {
    _resetControlsTimer();
    if (!_controller.value.isInitialized) return;

    setState(() {
      _isCreatingHighlight = true;
      _showHighlightDialog = true;
      _highlightShareCode = '';
    });

    // Request focus on the dialog copy button once it appears
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _dialogCopyFocusNode.requestFocus();
      }
    });

    final end = _controller.value.position;
    Duration start = end - const Duration(seconds: 15);
    if (start.isNegative) {
      start = Duration.zero;
    }

    try {
      final result = await ApiService.createHighlight(
        mediaId: _mediaId.toString(),
        startTime: start.inMilliseconds,
        endTime: end.inMilliseconds,
      );

      if (mounted) {
        setState(() {
          _highlightShareCode = result['code'] ?? 'CINE99';
          _isCreatingHighlight = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _highlightShareCode = 'ERR500';
          _isCreatingHighlight = false;
        });
      }
    }
  }

  Widget _buildHighlightOverlay() {
    return Positioned.fill(
      child: Stack(
        children: [
          // Dark background dim
          Container(
            color: Colors.black.withOpacity(0.75),
          ),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 500,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F12).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withOpacity(0.4),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with Amber Scissors
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37).withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.content_cut_rounded,
                              color: Color(0xFFD4AF37),
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            "HIGHLIGHT CREATED",
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "A 15-second digital highlight clip has been indexed.\nUse the 6-digit TV lookup code below to watch or share.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      
                      // 6-digit Code Box / Spinner
                      _isCreatingHighlight
                          ? const Column(
                              children: [
                                SpinKitFadingCircle(
                                  color: Color(0xFFD4AF37),
                                  size: 50.0,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "Generating Code...",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFD4AF37).withOpacity(0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                _highlightShareCode,
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFD4AF37),
                                  fontSize: 44,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 10,
                                ),
                              ),
                            ),
                      
                      const SizedBox(height: 32),
                      
                      // D-pad focusable buttons
                      Row(
                        children: [
                          Expanded(
                            child: TvFocusButton(
                              focusNode: _dialogDismissFocusNode,
                              onPressed: () {
                                setState(() {
                                  _showHighlightDialog = false;
                                });
                                _playPauseFocusNode.requestFocus();
                              },
                              child: Center(
                                child: Text(
                                  "DISMISS",
                                  style: GoogleFonts.dmSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TvFocusButton(
                              focusNode: _dialogCopyFocusNode,
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _highlightShareCode));
                                _showToast("Code copied: $_highlightShareCode");
                                setState(() {
                                  _showHighlightDialog = false;
                                });
                                _playPauseFocusNode.requestFocus();
                              },
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.copy_rounded, color: Colors.black, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      "COPY CODE",
                                      style: GoogleFonts.dmSans(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
      _showSubtitleStylesSheet = false;
      _showHighlightDialog = false;
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
                onSelected: (opt) async {
                  if (opt == 'Subtitle Styling Customizer') {
                    setState(() {
                      _showSubtitlesSheet = false;
                      _showSubtitleStylesSheet = true;
                    });
                    return;
                  }
                  setState(() {
                    _selectedSubtitle = opt;
                  });
                  if (opt == 'Off') {
                    setState(() {
                      _currentSubtitleTracks = [];
                      _activeSubtitleText = '';
                    });
                  } else {
                    final lang = opt.contains('Spanish') ? 'es' : opt.contains('French') ? 'fr' : 'en';
                    final tracks = await ApiService.fetchSubtitleTracks(widget.streamUrl ?? 'http://cinegram.io/movie.mp4', lang);
                    setState(() {
                      _currentSubtitleTracks = tracks;
                    });
                  }
                  setState(() {
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

              // SUBTITLE STYLE DRAWER
              _buildSubtitleStylesDrawer(),

              // SUBTITLE DYNAMIC DISPLAY
              if (_selectedSubtitle != 'Off' && _activeSubtitleText.isNotEmpty)
                Positioned(
                  bottom: _showControls ? 140.0 : 48.0,
                  left: 64.0,
                  right: 64.0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(_subtitleBackgroundOpacity),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Stack(
                        children: [
                          if (_subtitleOutlineWeight > 0.0)
                            Text(
                              _activeSubtitleText,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: _subtitleFontSize,
                                fontWeight: FontWeight.bold,
                                foreground: Paint()
                                  ..style = PaintingStyle.stroke
                                  ..strokeWidth = _subtitleOutlineWeight
                                  ..color = Colors.black,
                              ),
                            ),
                          Text(
                            _activeSubtitleText,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: _subtitleFontSize,
                              fontWeight: FontWeight.bold,
                              color: _subtitleColorName == 'White'
                                  ? Colors.white
                                  : _subtitleColorName == 'Gold'
                                      ? const Color(0xFFFFD700)
                                      : _subtitleColorName == 'Mint'
                                          ? Colors.greenAccent
                                          : Colors.cyanAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ⏩ SMART SKIP INTRO OVERLAY
              if (_showSkipIntro)
                Positioned(
                  bottom: _showControls ? 200.0 : 100.0,
                  right: 48.0,
                  child: Focus(
                    focusNode: _skipIntroFocusNode,
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          (event.logicalKey == LogicalKeyboardKey.enter ||
                           event.logicalKey == LogicalKeyboardKey.select)) {
                        _controller.seekTo(const Duration(seconds: 90));
                        setState(() {
                          _showSkipIntro = false;
                        });
                        _screenFocusNode.requestFocus();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Builder(
                      builder: (context) {
                        final bool hasFocus = Focus.of(context).hasFocus;
                        return GestureDetector(
                          onTap: () {
                            _controller.seekTo(const Duration(seconds: 90));
                            setState(() {
                              _showSkipIntro = false;
                            });
                            _screenFocusNode.requestFocus();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                            decoration: BoxDecoration(
                              color: hasFocus 
                                  ? Theme.of(context).primaryColor.withOpacity(0.9) 
                                  : Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(30.0),
                              border: Border.all(
                                color: hasFocus ? Colors.white : Theme.of(context).primaryColor, 
                                width: 2.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).primaryColor.withOpacity(hasFocus ? 0.6 : 0.2),
                                  blurRadius: 15.0,
                                  spreadRadius: 2.0,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.fast_forward_rounded, 
                                  color: hasFocus ? Colors.black : Colors.white, 
                                  size: 20.0,
                                ),
                                const SizedBox(width: 8.0),
                                Text(
                                  "SKIP INTRO",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: hasFocus ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13.0,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    ),
                  ),
                ),

              // 🧸 SMART NEXT EPISODE COUNTDOWN OVERLAY
              if (_showNextEpisodeCountdown)
                Positioned(
                  bottom: _showControls ? 200.0 : 100.0,
                  right: 48.0,
                  child: Focus(
                    focusNode: _nextEpisodeFocusNode,
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          (event.logicalKey == LogicalKeyboardKey.enter ||
                           event.logicalKey == LogicalKeyboardKey.select)) {
                        _triggerAutoplay();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Builder(
                      builder: (context) {
                        final bool hasFocus = Focus.of(context).hasFocus;
                        return GestureDetector(
                          onTap: _triggerAutoplay,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 260.0,
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F0F12).withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20.0),
                              border: Border.all(
                                color: hasFocus ? Theme.of(context).primaryColor : Colors.white12, 
                                width: 2.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 20.0,
                                  spreadRadius: 2.0,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.queue_play_next_rounded, color: Colors.orangeAccent, size: 20.0),
                                    const SizedBox(width: 8.0),
                                    Text(
                                      "UP NEXT IN $_nextEpisodeCountdownSeconds...",
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.orangeAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11.0,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  "Subsequent Episode",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.0,
                                  ),
                                ),
                                const SizedBox(height: 12.0),
                                SizedBox(
                                  width: double.infinity,
                                  height: 36.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: hasFocus ? Theme.of(context).primaryColor : Colors.white.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      "PLAY NOW",
                                      style: GoogleFonts.plusJakartaSans(
                                        color: hasFocus ? Colors.black : Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11.5,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    ),
                  ),
                ),

              // WATCH PARTY REACTION BAR
              if (_watchPartyRoomId != null && _showControls)
                Positioned(
                  bottom: 220.0,
                  left: 64.0,
                  right: 64.0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "SEND REACTION: ",
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.0,
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          ..._reactionEmojis.map((emoji) {
                            return Focus(
                              focusNode: emoji == '❤️' ? _emojiReactionFocusNode : null,
                              child: Builder(
                                builder: (context) {
                                  final bool hasFocus = Focus.of(context).hasFocus;
                                  return InkWell(
                                    onTap: () => _sendWatchPartyEmoji(emoji),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.symmetric(horizontal: 6.0),
                                      padding: const EdgeInsets.all(8.0),
                                      decoration: BoxDecoration(
                                        color: hasFocus ? Theme.of(context).primaryColor.withOpacity(0.2) : Colors.transparent,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: hasFocus ? Theme.of(context).primaryColor : Colors.transparent, width: 1.5),
                                      ),
                                      child: Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 22.0),
                                      ),
                                    ),
                                  );
                                }
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ),

              // FLOATING EMOJI ANIMATION SYSTEM
              ..._floatingEmojis.map((item) {
                return Positioned(
                  bottom: 120.0 + item['y'],
                  left: MediaQuery.of(context).size.width / 2 + item['x'],
                  child: Opacity(
                    opacity: item['opacity'],
                    child: Text(
                      item['emoji'],
                      style: const TextStyle(fontSize: 48.0),
                    ),
                  ),
                );
              }).toList(),

              if (_showHighlightDialog)
                _buildHighlightOverlay(),
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
                const SizedBox(width: 24),

                // TV D-pad Focusable Highlight Scissors Button
                TvFocusButton(
                  focusNode: _highlightFocusNode,
                  onPressed: _createHighlightClip,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.content_cut_rounded, color: Theme.of(context).primaryColor, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "HIGHLIGHT",
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
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
  void _startWatchPartySync() {
    _watchPartySyncTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (mounted && _controller.value.isInitialized) {
        _syncWatchPartyRoom();
      }
    });
  }

  Future<void> _syncWatchPartyRoom() async {
    if (_watchPartyRoomId == null) return;
    try {
      if (_isWatchPartyHost) {
        final room = await ApiService.updateWatchPartyRoom(
          _watchPartyRoomId!,
          playheadMs: _controller.value.position.inMilliseconds,
          state: _controller.value.isPlaying ? 'playing' : 'paused',
        );
        _handleRoomSyncData(room);
      } else {
        final room = await ApiService.getWatchPartyRoom(_watchPartyRoomId!);
        _handleRoomSyncData(room);
      }
    } catch (e) {
      developer.log("Error syncing watch party room coordinates", error: e, name: "TvPlayerScreen");
    }
  }

  int _lastHandledReactionTime = 0;
  void _handleRoomSyncData(Map<String, dynamic> room) {
    if (room.isEmpty) return;
    
    if (!_isWatchPartyHost) {
      final hostState = room['state'] ?? 'paused';
      final hostPlayhead = room['playheadMs'] as int? ?? 0;
      
      if (hostState == 'playing' && !_controller.value.isPlaying) {
        _controller.play();
      } else if (hostState == 'paused' && _controller.value.isPlaying) {
        _controller.pause();
      }
      
      final diff = (hostPlayhead - _controller.value.position.inMilliseconds).abs();
      if (diff > 1500) {
        _controller.seekTo(Duration(milliseconds: hostPlayhead));
      }
    }

    final reactions = List<dynamic>.from(room['reactions'] ?? []);
    for (final reaction in reactions) {
      final time = reaction['time'] as int? ?? 0;
      final emoji = reaction['emoji'] as String? ?? '';
      if (time > _lastHandledReactionTime && emoji.isNotEmpty) {
        _triggerFloatingEmoji(emoji);
        _lastHandledReactionTime = time;
      }
    }
  }

  Future<void> _sendWatchPartyEmoji(String emoji) async {
    if (_watchPartyRoomId == null) return;
    try {
      final room = await ApiService.updateWatchPartyRoom(_watchPartyRoomId!, reactionEmoji: emoji);
      _handleRoomSyncData(room);
      _triggerFloatingEmoji(emoji);
    } catch (e) {
      developer.log("Error sending emoji reaction", error: e, name: "TvPlayerScreen");
    }
  }

  void _triggerFloatingEmoji(String emoji) {
    final randomX = (50.0 - (100.0 * (DateTime.now().millisecond % 10) / 10.0));
    setState(() {
      _floatingEmojis.add({
        'emoji': emoji,
        'x': randomX,
        'y': 0.0,
        'opacity': 1.0,
        'time': DateTime.now().millisecondsSinceEpoch,
      });
    });
    _startEmojiTicker();
  }

  void _startEmojiTicker() {
    if (_emojiTicker != null && _emojiTicker!.isActive) return;
    _emojiTicker = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      bool updated = false;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      setState(() {
        _floatingEmojis.removeWhere((item) {
          final age = now - (item['time'] as int);
          if (age > 2000) {
            return true;
          }
          item['y'] = (age / 2000.0) * 400.0;
          item['opacity'] = 1.0 - (age / 2000.0);
          updated = true;
          return false;
        });
      });
      
      if (_floatingEmojis.isEmpty) {
        timer.cancel();
      }
    });
  }

  void _updateSubtitles() {
    if (_selectedSubtitle == 'Off' || _currentSubtitleTracks.isEmpty) {
      _activeSubtitleText = '';
      return;
    }
    final double currentSec = _controller.value.position.inMilliseconds / 1000.0;
    String newText = '';
    for (final track in _currentSubtitleTracks) {
      final double start = (track['startTime'] as num).toDouble();
      final double end = (track['endTime'] as num).toDouble();
      if (currentSec >= start && currentSec <= end) {
        newText = track['text'] ?? '';
        break;
      }
    }
    _activeSubtitleText = newText;
  }

  Widget _buildSubtitleStylesDrawer() {
    final primaryColor = Theme.of(context).primaryColor;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      right: _showSubtitleStylesSheet ? 0 : -340,
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
                left: BorderSide(color: primaryColor, width: 1.5),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "SUBTITLE STYLE",
                      style: GoogleFonts.cinzel(
                        color: primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                      onPressed: () {
                        setState(() {
                          _showSubtitleStylesSheet = false;
                        });
                      },
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 20, thickness: 1),
                const SizedBox(height: 12),
                
                Expanded(
                  child: ListView(
                    children: [
                      Text("FONT SIZE", style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [18.0, 22.0, 26.0, 32.0].map((size) {
                          final isSel = _subtitleFontSize == size;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _subtitleFontSize = size;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel ? primaryColor.withOpacity(0.2) : Colors.white.withOpacity(0.04),
                                border: Border.all(color: isSel ? primaryColor : Colors.white12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text("${size.toInt()}px", style: GoogleFonts.plusJakartaSans(color: isSel ? primaryColor : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      Text("TEXT COLOR", style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: {
                          'White': Colors.white,
                          'Gold': const Color(0xFFFFD700),
                          'Mint': Colors.greenAccent,
                          'Cyan': Colors.cyanAccent
                        }.entries.map((entry) {
                          final isSel = _subtitleColorName == entry.key;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _subtitleColorName = entry.key;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel ? entry.value.withOpacity(0.2) : Colors.white.withOpacity(0.04),
                                border: Border.all(color: isSel ? entry.value : Colors.white12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(entry.key, style: GoogleFonts.plusJakartaSans(color: isSel ? entry.value : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      Text("BACKGROUND BOX OPACITY", style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [0.0, 0.2, 0.4, 0.6].map((op) {
                          final isSel = _subtitleBackgroundOpacity == op;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _subtitleBackgroundOpacity = op;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel ? primaryColor.withOpacity(0.2) : Colors.white.withOpacity(0.04),
                                border: Border.all(color: isSel ? primaryColor : Colors.white12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text("${(op * 100).toInt()}%", style: GoogleFonts.plusJakartaSans(color: isSel ? primaryColor : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      Text("TEXT OUTLINE WEIGHT", style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [0.0, 1.0, 2.0, 3.0].map((ow) {
                          final isSel = _subtitleOutlineWeight == ow;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _subtitleOutlineWeight = ow;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel ? primaryColor.withOpacity(0.2) : Colors.white.withOpacity(0.04),
                                border: Border.all(color: isSel ? primaryColor : Colors.white12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text("${ow.toInt()}px", style: GoogleFonts.plusJakartaSans(color: isSel ? primaryColor : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
