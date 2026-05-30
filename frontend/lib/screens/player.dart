import 'dart:async';
import 'dart:ui';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cinegram/models/media.dart';
import 'package:cinegram/services/api_service.dart';
import 'package:cinegram/services/download_manager.dart';
import 'package:cinegram/services/external_player_service.dart';

class PlayerScreen extends StatefulWidget {
  final Media media;
  final String? channelId;
  final String? messageId;
  final String? streamUrl;

  const PlayerScreen({
    super.key,
    required this.media,
    this.channelId,
    this.messageId,
    this.streamUrl,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _controller;
  bool _isError = false;
  String _errorMessage = '';
  bool _showControls = true;
  Timer? _controlsTimer;

  // Smart Skip & Autoplay states
  bool _showSkipIntro = false;
  bool _showNextEpisodeCountdown = false;
  int _nextEpisodeCountdownSeconds = 5;
  Timer? _autoplayTimer;
  bool _didTriggerAutoplay = false;

  // Custom gestures volume and brightness states
  double _volume = 0.6;
  double _brightness = 0.8;
  bool _showVolumeHUD = false;
  bool _showBrightnessHUD = false;
  Timer? _hudTimer;

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

  // Picture in Picture simulation
  bool _isPiPActive = false;
  Offset _pipPosition = const Offset(20, 20);

  // Sync Watch Progress Timer
  Timer? _progressSyncTimer;

  // Highlight/Scissors state variables
  bool _showHighlightDialog = false;
  String _highlightShareCode = '';
  bool _isCreatingHighlight = false;

  @override
  void initState() {
    super.initState();
    _initController();
    _startControlsTimer();

    // Immersive full-screen and horizontal lock
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Periodically sync watch progress every 10 seconds
    _progressSyncTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_controller.value.isInitialized && _controller.value.isPlaying) {
        _syncProgress();
      }
    });
  }

  void _initController() {
    String streamUrl = '';
    if (widget.streamUrl != null && widget.streamUrl!.isNotEmpty) {
      streamUrl = widget.streamUrl!;
    } else if (widget.channelId != null && widget.messageId != null) {
      streamUrl = 'http://localhost:3000/stream?channelId=${widget.channelId}&messageId=${widget.messageId}';
    } else if (widget.media.streamUrl != null && widget.media.streamUrl!.isNotEmpty) {
      streamUrl = widget.media.streamUrl!;
    } else {
      // Premium public fallback video stream for mock testing
      streamUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
    }

    developer.log('Initializing stream player with URL: $streamUrl', name: 'PlayerScreen');

    _controller = VideoPlayerController.networkUrl(Uri.parse(streamUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isError = false;
            _volume = _controller.value.volume;
          });
          _controller.play();
        }
      }).catchError((error) {
        developer.log('Error initializing video player', name: 'PlayerScreen', error: error);
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

    // Find next episode dynamically from mock showcase database
    final list = Media.mockShowcaseList;
    final nextIndex = list.indexWhere((x) => x.id == widget.media.id) + 1;
    if (nextIndex < list.length) {
      final nextItem = list[nextIndex];
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            media: nextItem,
            channelId: widget.channelId,
            messageId: widget.messageId,
            streamUrl: widget.streamUrl,
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
    // Sync final watch progress on closing screen
    _syncProgress();

    _progressSyncTimer?.cancel();
    _controlsTimer?.cancel();
    _hudTimer?.cancel();
    _skipLeftTimer?.cancel();
    _skipRightTimer?.cancel();
    _toastTimer?.cancel();
    _autoplayTimer?.cancel();

    _controller.removeListener(_videoListener);
    _controller.dispose();

    // Re-enable typical portrait orientation and system UI
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
        mediaId: widget.media.id,
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

    final end = _controller.value.position;
    Duration start = end - const Duration(seconds: 15);
    if (start.isNegative) {
      start = Duration.zero;
    }

    try {
      final result = await ApiService.createHighlight(
        mediaId: widget.media.id.toString(),
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
          // Semi-transparent dim background
          GestureDetector(
            onTap: () {
              setState(() {
                _showHighlightDialog = false;
              });
            },
            child: Container(
              color: Colors.black.withOpacity(0.6),
            ),
          ),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  width: 380,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F12).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withOpacity(0.15),
                        blurRadius: 25,
                        spreadRadius: 2,
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
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37).withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.content_cut_rounded,
                              color: Color(0xFFD4AF37),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Highlight Captured",
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "A 15-second clip has been registered (from ${_formatDuration(_controller.value.position - const Duration(seconds: 15) < Duration.zero ? Duration.zero : _controller.value.position - const Duration(seconds: 15))} to ${_formatDuration(_controller.value.position)}). Share it using the code below:",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // 6-digit Code Box / Spinner
                      _isCreatingHighlight
                          ? const Column(
                              children: [
                                SpinKitFadingCircle(
                                  color: Color(0xFFD4AF37),
                                  size: 40.0,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  "Generating Code...",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFD4AF37).withOpacity(0.15),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _highlightShareCode,
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFD4AF37),
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 8,
                                ),
                              ),
                            ),
                      
                      const SizedBox(height: 24),
                      
                      // Mock "Copy Code" & "Dismiss" buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _showHighlightDialog = false;
                                });
                              },
                              child: Text(
                                "Dismiss",
                                style: GoogleFonts.dmSans(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD4AF37),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 4,
                                shadowColor: const Color(0xFFD4AF37).withOpacity(0.3),
                              ),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _highlightShareCode));
                                _showToast("Code copied to clipboard: $_highlightShareCode");
                                setState(() {
                                  _showHighlightDialog = false;
                                });
                              },
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: Text(
                                "Copy Code",
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
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
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted &&
          _controller.value.isPlaying &&
          !_showSubtitlesSheet &&
          !_showAudioSheet &&
          !_showSpeedSheet) {
        setState(() {
          _showControls = false;
        });
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
      final duration = _controller.value.duration;
      final clampedTarget = target < Duration.zero 
          ? Duration.zero 
          : (target > duration ? duration : target);
      _controller.seekTo(clampedTarget);

      _skipRightTimer?.cancel();
      setState(() {
        _showRightSkipIndicator = true;
      });
      _skipRightTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _showRightSkipIndicator = false);
      });
    }
  }

  void _seekBackward10s() {
    _resetControlsTimer();
    if (_controller.value.isInitialized) {
      final current = _controller.value.position;
      final target = current - const Duration(seconds: 10);
      final duration = _controller.value.duration;
      final clampedTarget = target < Duration.zero 
          ? Duration.zero 
          : (target > duration ? duration : target);
      _controller.seekTo(clampedTarget);

      _skipLeftTimer?.cancel();
      setState(() {
        _showLeftSkipIndicator = true;
      });
      _skipLeftTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _showLeftSkipIndicator = false);
      });
    }
  }

  void _adjustVolume(double delta) {
    _resetControlsTimer();
    setState(() {
      _volume = (_volume + delta).clamp(0.0, 1.0);
      _controller.setVolume(_volume);
      _showVolumeHUD = true;
    });
  }

  void _adjustBrightness(double delta) {
    _resetControlsTimer();
    setState(() {
      _brightness = (_brightness + delta).clamp(0.0, 1.0);
      _showBrightnessHUD = true;
    });
  }

  void _hideHUDWithDelay() {
    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showVolumeHUD = false;
          _showBrightnessHUD = false;
        });
      }
    });
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() {
      _toastMessage = message;
    });
    _toastTimer = Timer(const Duration(seconds: 2), () {
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

    if (_isPiPActive) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _buildPiPLayout(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _resetControlsTimer,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Video Viewport
            Center(
              child: _controller.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : const SpinKitDoubleBounce(
                      color: Color(0xFFD4AF37),
                      size: 60.0,
                    ),
            ),

            // Simulated Brightness Overlay (Dims pixels directly)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity((1.0 - _brightness).clamp(0.0, 0.9)),
                ),
              ),
            ),

            // Double Tap zones & gesture swipes
            _buildGestureZones(),

            // Buffering Indicator
            if (_controller.value.isInitialized && _controller.value.isBuffering)
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SpinKitCircle(
                      color: Color(0xFFD4AF37),
                      size: 50.0,
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Buffering stream...",
                      style: TextStyle(
                        color: Color(0xFFD4AF37),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),

            // Center double-tap skipped feedback overlays
            if (_showLeftSkipIndicator)
              Center(
                child: Padding(
                  padding: EdgeInsets.only(right: MediaQuery.of(context).size.width * 0.4),
                  child: _buildDoubleTapIndicator("-10s", Icons.fast_rewind_rounded),
                ),
              ),
            if (_showRightSkipIndicator)
              Center(
                child: Padding(
                  padding: EdgeInsets.only(left: MediaQuery.of(context).size.width * 0.4),
                  child: _buildDoubleTapIndicator("+10s", Icons.fast_forward_rounded),
                ),
              ),

            // Brightness / Volume HUDs
            if (_showBrightnessHUD)
              Positioned(
                left: 40,
                top: MediaQuery.of(context).size.height * 0.2,
                bottom: MediaQuery.of(context).size.height * 0.2,
                width: 50,
                child: _buildHUDSlider(
                  icon: Icons.light_mode_rounded,
                  value: _brightness,
                ),
              ),
            if (_showVolumeHUD)
              Positioned(
                right: 40,
                top: MediaQuery.of(context).size.height * 0.2,
                bottom: MediaQuery.of(context).size.height * 0.2,
                width: 50,
                child: _buildHUDSlider(
                  icon: _volume == 0
                      ? Icons.volume_off_rounded
                      : _volume < 0.5
                          ? Icons.volume_down_rounded
                          : Icons.volume_up_rounded,
                  value: _volume,
                ),
              ),

            // Toast Alert Overlay
            if (_toastMessage != null)
              Positioned(
                top: 80,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildToastNotification(_toastMessage!),
                ),
              ),

            // ⏩ SMART SKIP INTRO OVERLAY
            if (_showSkipIntro)
              Positioned(
                bottom: _showControls ? 140.0 : 64.0,
                right: 32.0,
                child: GestureDetector(
                  onTap: () {
                    _controller.seekTo(const Duration(seconds: 90));
                    setState(() {
                      _showSkipIntro = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(30.0),
                      border: Border.all(
                        color: Theme.of(context).primaryColor,
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).primaryColor.withOpacity(0.3),
                          blurRadius: 12.0,
                          spreadRadius: 1.0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.fast_forward_rounded,
                          color: Colors.white,
                          size: 18.0,
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          "SKIP INTRO",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12.0,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 🧸 SMART NEXT EPISODE COUNTDOWN OVERLAY
            if (_showNextEpisodeCountdown)
              Positioned(
                bottom: _showControls ? 140.0 : 64.0,
                right: 32.0,
                child: GestureDetector(
                  onTap: _triggerAutoplay,
                  child: Container(
                    width: 220.0,
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F12).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(
                        color: Theme.of(context).primaryColor.withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 16.0,
                          spreadRadius: 1.0,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.queue_play_next_rounded, color: Colors.orangeAccent, size: 18.0),
                            const SizedBox(width: 6.0),
                            Text(
                              "NEXT IN $_nextEpisodeCountdownSeconds...",
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 10.0,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6.0),
                        Text(
                          "Subsequent Episode",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.0,
                          ),
                        ),
                        const SizedBox(height: 10.0),
                        SizedBox(
                          width: double.infinity,
                          height: 32.0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "PLAY NOW",
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 10.5,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Immersive Video Controls
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Stack(
                  children: [
                    // Deep luxury vignette gradient
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.85),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withOpacity(0.9),
                            ],
                            stops: const [0.0, 0.25, 0.75, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Top Control Bar
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        child: _buildTopControlBar(),
                      ),
                    ),

                    // Center Control Buttons
                    Center(
                      child: _buildCenterControls(),
                    ),

                    // Bottom Control Bar & Timeline
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        child: _buildBottomControlBar(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Dialog / Selector overlays
            if (_showSubtitlesSheet)
              _buildSelectionSheet(
                title: "Subtitles",
                options: _subtitleOptions,
                selectedOption: _selectedSubtitle,
                onSelected: (opt) {
                  setState(() {
                    _selectedSubtitle = opt;
                    _showSubtitlesSheet = false;
                  });
                  _showToast("Subtitles set to: $opt");
                },
                onClose: () => setState(() => _showSubtitlesSheet = false),
              ),

            if (_showAudioSheet)
              _buildSelectionSheet(
                title: "Audio Track",
                options: _audioOptions,
                selectedOption: _selectedAudio,
                onSelected: (opt) {
                  setState(() {
                    _selectedAudio = opt;
                    _showAudioSheet = false;
                  });
                  _showToast("Audio Track set to: $opt");
                },
                onClose: () => setState(() => _showAudioSheet = false),
              ),

            if (_showSpeedSheet)
              _buildSelectionSheet(
                title: "Playback Speed",
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
                },
                onClose: () => setState(() => _showSpeedSheet = false),
              ),

            if (_showHighlightDialog)
              _buildHighlightOverlay(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // GESTURE ZONES
  // ==========================================
  Widget _buildGestureZones() {
    return Stack(
      children: [
        // Left side swipe panel (Brightness) + double tap (10s back)
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: MediaQuery.of(context).size.width * 0.35,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTap: _seekBackward10s,
            onVerticalDragUpdate: (details) {
              _adjustBrightness(-details.primaryDelta! / 250.0);
            },
            onVerticalDragStart: (_) => setState(() => _showBrightnessHUD = true),
            onVerticalDragEnd: (_) => _hideHUDWithDelay(),
          ),
        ),

        // Right side swipe panel (Volume) + double tap (10s forward)
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: MediaQuery.of(context).size.width * 0.35,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTap: _seekForward10s,
            onVerticalDragUpdate: (details) {
              _adjustVolume(-details.primaryDelta! / 250.0);
            },
            onVerticalDragStart: (_) => setState(() => _showVolumeHUD = true),
            onVerticalDragEnd: (_) => _hideHUDWithDelay(),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // HUD BUILDER
  // ==========================================
  Widget _buildHUDSlider({required IconData icon, required double value}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFD4AF37), size: 22),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: 5,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(2.5),
              ),
              child: FractionallySizedBox(
                heightFactor: value,
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37),
                    borderRadius: BorderRadius.circular(2.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withOpacity(0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${(value * 100).toInt()}%',
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TOP CONTROL BAR
  // ==========================================
  Widget _buildTopControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Back Button
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 8),

          // Title & Media Meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.media.title,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      widget.media.mediaType.toUpperCase(),
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFFD4AF37),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "•",
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.media.releaseYear,
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                    if (widget.media.runtime != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        "•",
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${widget.media.runtime} MIN",
                        style: GoogleFonts.dmSans(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // PiP Button
          IconButton(
            icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white70, size: 22),
            onPressed: () {
              setState(() {
                _isPiPActive = true;
                _showControls = false;
              });
              _showToast("Picture-in-Picture active");
            },
          ),
          const SizedBox(width: 4),

          // External Player Transition Button
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 22),
            onPressed: () {
              _togglePlayPause(); // Pause current playback
              _switchToExternalPlayer(context);
            },
          ),
          const SizedBox(width: 4),

          // Subtitles selector
          _buildActionButton(
            label: _selectedSubtitle == 'Off' ? 'Subtitles' : _selectedSubtitle,
            icon: Icons.subtitles_rounded,
            onPressed: () {
              _resetControlsTimer();
              setState(() {
                _showSubtitlesSheet = true;
              });
            },
          ),
          const SizedBox(width: 10),

          // Audio selector
          _buildActionButton(
            label: _selectedAudio.length > 15 ? '${_selectedAudio.substring(0, 12)}...' : _selectedAudio,
            icon: Icons.audiotrack_rounded,
            onPressed: () {
              _resetControlsTimer();
              setState(() {
                _showAudioSheet = true;
              });
            },
          ),
        ],
      ),
    );
  }

  void _switchToExternalPlayer(BuildContext context) async {
    String streamUrl = '';
    if (widget.streamUrl != null && widget.streamUrl!.isNotEmpty) {
      streamUrl = widget.streamUrl!;
    } else if (widget.channelId != null && widget.messageId != null) {
      streamUrl = '${ApiService.baseUrl}/stream?channelId=${widget.channelId}&messageId=${widget.messageId}';
    } else if (widget.media.streamUrl != null && widget.media.streamUrl!.isNotEmpty) {
      streamUrl = widget.media.streamUrl!;
    } else {
      streamUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
    }

    // Check if there is an offline download completion path
    final downloadedTask = DownloadManager().getTask(widget.media.id.toString());
    if (downloadedTask != null && downloadedTask.status == 'completed') {
      streamUrl = downloadedTask.localPath;
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (dialogContext) {
        return FutureBuilder<List<Map<String, String>>>(
          future: ExternalPlayerService.detectPlayers(),
          builder: (sheetContext, snapshot) {
            final players = snapshot.data ?? [];
            final isLoading = snapshot.connectionState == ConnectionState.waiting;
            final primaryColor = Theme.of(context).primaryColor;

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F12).withOpacity(0.95),
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.08), width: 1.0),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36.0,
                          height: 4.0,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20.0),
                      Text(
                        "SWITCH TO EXTERNAL PLAYER",
                        style: GoogleFonts.cinzel(
                          fontSize: 18.0,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        "Transition current playback of '${widget.media.title}' to a dedicated media app.",
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      if (isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 32.0),
                            child: CircularProgressIndicator(strokeWidth: 2.0),
                          ),
                        )
                      else if (players.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Text(
                            "No external players found.",
                            style: GoogleFonts.plusJakartaSans(color: Colors.white38),
                          ),
                        )
                      else
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.4,
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: players.length,
                            itemBuilder: (listContext, index) {
                              final p = players[index];
                              final name = p['name'] ?? 'Unknown Player';
                              final package = p['package'] ?? '';

                              IconData pIcon = Icons.play_circle_outline_rounded;
                              Color pIconColor = Colors.white60;

                              if (package.contains("vlc")) {
                                pIcon = Icons.play_circle_filled_rounded;
                                pIconColor = Colors.orangeAccent;
                              } else if (package.contains("mxtech")) {
                                pIcon = Icons.play_circle_filled_rounded;
                                pIconColor = Colors.blueAccent;
                              } else if (package.contains("nova")) {
                                pIcon = Icons.play_circle_filled_rounded;
                                pIconColor = Colors.greenAccent;
                              } else if (package.contains("kodi")) {
                                pIcon = Icons.dashboard_rounded;
                                pIconColor = Colors.cyanAccent;
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8.0),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                                ),
                                child: ListTile(
                                  leading: Icon(pIcon, color: pIconColor),
                                  title: Text(
                                    name,
                                    style: GoogleFonts.plusJakartaSans(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    package,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white30,
                                      fontSize: 10.0,
                                    ),
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_rounded, color: Colors.white30),
                                  onTap: () async {
                                    Navigator.pop(dialogContext);
                                    final ok = await ExternalPlayerService.launchPlayer(package, streamUrl, widget.media.title);
                                    if (ok && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text("Playing in $name..."),
                                          backgroundColor: primaryColor,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.white.withOpacity(0.08),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      onPressed: onPressed,
      icon: Icon(icon, color: const Color(0xFFD4AF37), size: 16),
      label: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ==========================================
  // CENTER PLAYBACK CONTROLS
  // ==========================================
  Widget _buildCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Skip 10s Back
        IconButton(
          iconSize: 45,
          icon: Icon(Icons.replay_10_rounded, color: Colors.white.withOpacity(0.8)),
          onPressed: _seekBackward10s,
        ),
        const SizedBox(width: 40),

        // Main Luxury Gold Play/Pause Button
        GestureDetector(
          onTap: _togglePlayPause,
          child: Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.6),
              border: Border.all(color: const Color(0xFFD4AF37), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withOpacity(0.25),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Icon(
              _controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: const Color(0xFFD4AF37),
              size: 40,
            ),
          ),
        ),
        const SizedBox(width: 40),

        // Skip 10s Forward
        IconButton(
          iconSize: 45,
          icon: Icon(Icons.forward_10_rounded, color: Colors.white.withOpacity(0.8)),
          onPressed: _seekForward10s,
        ),
      ],
    );
  }

  // ==========================================
  // BOTTOM CONTROL BAR
  // ==========================================
  Widget _buildBottomControlBar() {
    final position = _controller.value.position;
    final duration = _controller.value.duration;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Smooth Seeking Timeline Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFD4AF37),
              inactiveTrackColor: Colors.white.withOpacity(0.24),
              trackHeight: 3.5,
              thumbColor: const Color(0xFFD4AF37),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
              overlayColor: const Color(0xFFD4AF37).withOpacity(0.12),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
            ),
            child: Slider(
              value: position.inMilliseconds.toDouble().clamp(
                    0.0,
                    duration.inMilliseconds.toDouble(),
                  ),
              min: 0.0,
              max: duration.inMilliseconds.toDouble() > 0
                  ? duration.inMilliseconds.toDouble()
                  : 1.0,
              onChanged: (value) {
                _resetControlsTimer();
                _controller.seekTo(Duration(milliseconds: value.toInt()));
              },
            ),
          ),
          const SizedBox(height: 6),

          // Duration Labels & Settings
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Elapsed & Remaining timestamps
              Row(
                children: [
                  Text(
                    _formatDuration(position),
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "/",
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatRemaining(position, duration),
                    style: GoogleFonts.dmSans(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // Speed selector & Full screen mock
              Row(
                children: [
                  // Glowing Highlight Scissors Button
                  Container(
                    margin: const EdgeInsets.only(right: 14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4AF37).withOpacity(0.35),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.black.withOpacity(0.6),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.content_cut_rounded, color: Color(0xFFD4AF37), size: 16),
                        onPressed: _createHighlightClip,
                        tooltip: "Capture Highlight",
                      ),
                    ),
                  ),

                  // Playback Speed button
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.8),
                      backgroundColor: Colors.white.withOpacity(0.06),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      _resetControlsTimer();
                      setState(() {
                        _showSpeedSheet = true;
                      });
                    },
                    icon: const Icon(Icons.speed_rounded, color: Color(0xFFD4AF37), size: 14),
                    label: Text(
                      "${_playbackSpeed}x",
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Fullscreen toggle mock
                  Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white.withOpacity(0.8),
                    size: 24,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DOUBLE-TAP & UTILITY OVERLAYS
  // ==========================================
  Widget _buildDoubleTapIndicator(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFD4AF37), size: 22),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFFD4AF37),
              fontSize: 14,
              fontWeight: FontWeight.bold,
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
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4), width: 1),
          ),
          child: Text(
            text,
            style: GoogleFonts.dmSans(
              color: const Color(0xFFD4AF37),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionSheet({
    required String title,
    required List<String> options,
    required String selectedOption,
    required Function(String) onSelected,
    required VoidCallback onClose,
  }) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 300,
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: const Color(0xEE1C1C1C),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.35), width: 1.2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.dmSans(
                          color: const Color(0xFFD4AF37),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                        onPressed: onClose,
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final opt = options[index];
                      final isSel = opt == selectedOption;
                      return InkWell(
                        onTap: () => onSelected(opt),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                          color: isSel ? const Color(0xFFD4AF37).withOpacity(0.1) : Colors.transparent,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                opt,
                                style: GoogleFonts.dmSans(
                                  color: isSel ? const Color(0xFFD4AF37) : Colors.white70,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                              if (isSel)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFFD4AF37),
                                  size: 16,
                                )
                            ],
                          ),
                        ),
                      );
                    },
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
  // INTERACTIVE PIP MODE WIDGETS
  // ==========================================
  Widget _buildPiPLayout() {
    return Stack(
      children: [
        // Cinegram desktop luxury application mock underneath the PIP
        _buildDashboardMock(),

        // Simulated Dim Overlay
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              color: Colors.black.withOpacity((1.0 - _brightness).clamp(0.0, 0.9)),
            ),
          ),
        ),

        // Draggable floating PIP video player
        Positioned(
          left: _pipPosition.dx,
          top: _pipPosition.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                // Keep the picture-in-picture bounded nicely
                final size = MediaQuery.of(context).size;
                final double newX = (_pipPosition.dx + details.delta.dx).clamp(10.0, size.width - 330.0);
                final double newY = (_pipPosition.dy + details.delta.dy).clamp(10.0, size.height - 210.0);
                _pipPosition = Offset(newX, newY);
              });
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 320,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.8),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Video Viewport
                    Center(
                      child: _controller.value.isInitialized
                          ? AspectRatio(
                              aspectRatio: _controller.value.aspectRatio,
                              child: VideoPlayer(_controller),
                            )
                          : const SpinKitDoubleBounce(
                              color: Color(0xFFD4AF37),
                              size: 40.0,
                            ),
                    ),

                    // Floating PIP top controls
                    Positioned(
                      top: 6,
                      left: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              widget.media.title,
                              style: GoogleFonts.dmSans(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Restore fullscreen
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isPiPActive = false;
                                    });
                                  },
                                  child: const Icon(Icons.fullscreen_rounded, color: Color(0xFFD4AF37), size: 18),
                                ),
                                const SizedBox(width: 8),
                                // Stop playback and close
                                GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Icon(Icons.close, color: Colors.white70, size: 16),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Gold Mini timeline indicator at PIP bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _controller.value.isInitialized
                          ? LinearProgressIndicator(
                              value: _controller.value.position.inMilliseconds.toDouble() /
                                  (_controller.value.duration.inMilliseconds.toDouble() > 0
                                      ? _controller.value.duration.inMilliseconds.toDouble()
                                      : 1.0),
                              backgroundColor: Colors.white.withOpacity(0.1),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                              minHeight: 3,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardMock() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0C0C14), Color(0xFF030306)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.06),
                    blurRadius: 100.0,
                    spreadRadius: 100.0,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                            ),
                            child: const Icon(Icons.movie_filter_rounded, color: Color(0xFFD4AF37), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "CINEGRAM",
                            style: GoogleFonts.cinzel(
                              color: const Color(0xFFD4AF37),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white.withOpacity(0.06),
                            child: const Icon(Icons.search, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 10),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white.withOpacity(0.06),
                            child: const Icon(Icons.person, color: Colors.white, size: 16),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 30),
                  Text(
                    "Now Playing - Picture-in-Picture",
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: 360,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            widget.media.posterUrl,
                            width: 55,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 55,
                              height: 80,
                              color: Colors.grey[900],
                              child: const Icon(Icons.movie, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.media.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Streaming via MTProto Gateway",
                                style: GoogleFonts.dmSans(
                                  color: const Color(0xFFD4AF37),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD4AF37),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPiPActive = false;
                                  });
                                },
                                icon: const Icon(Icons.fullscreen, size: 16),
                                label: Text(
                                  "Restore Fullscreen",
                                  style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: Text(
                      "Drag the video container above to move it anywhere on the dashboard.",
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withOpacity(0.2),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PLAYBACK ERROR VIEW
  // ==========================================
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFD4AF37),
              size: 55,
            ),
            const SizedBox(height: 16),
            Text(
              "Playback Connection Failed",
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Could not resolve connection to the Telegram gateway stream.\nPlease ensure the backend MTProto server is active and online.",
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage,
                  style: GoogleFonts.sourceCodePro(
                    color: Colors.redAccent,
                    fontSize: 10,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD4AF37),
                    side: const BorderSide(color: Color(0xFFD4AF37)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text("Go Back"),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    // Re-initialize with high-quality online stream
                    setState(() {
                      _isError = false;
                      _errorMessage = '';
                    });
                    _controller.removeListener(_videoListener);
                    _controller.dispose();

                    // Force public stream
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
                  icon: const Icon(Icons.play_circle_outline, size: 16),
                  label: const Text("Play Demo Stream"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
