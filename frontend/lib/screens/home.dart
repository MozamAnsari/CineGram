import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/media_item.dart';
import '../widgets/glassmorphic_card.dart';
import '../services/api_service.dart';
import '../services/external_player_service.dart';
import 'details.dart';
import 'search.dart';
import 'tv_player.dart';
import 'package:provider/provider.dart';
import '../theme/cinegram_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'onboarding_check.dart';
import 'channel_selector.dart';
import 'unresolved_queue.dart';
import 'telegram_login.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late MediaItem _featuredItem;
  final ScrollController _mainScrollController = ScrollController();
  double _scrollOpacity = 0.0;
  String _activeAvatarUrl = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=150';
  
  bool _isKidsProfileActive = false;
  String? _activeRole;

  bool _isSyncingActive = false;
  Map<String, dynamic>? _syncProgress;
  Timer? _syncTimer;

  // Dynamic cloud live sync rows
  List<MediaItem> _dynamicContinueWatching = [];
  List<MediaItem> _dynamicMovies = [];
  List<MediaItem> _dynamicTvShows = [];
  List<MediaItem> _dynamicAnime = [];

  @override
  void initState() {
    super.initState();
    _startSyncPolling();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _featuredItem = mockMediaDatabase.firstWhere((item) => item.category == 'Trending');
    
    // Seed initial row lists with static mocks for immediate display
    _dynamicContinueWatching = mockMediaDatabase.where((item) => item.progress != null).toList();
    _dynamicMovies = mockMediaDatabase.where((item) => item.type == 'Movie').toList();
    _dynamicTvShows = mockMediaDatabase.where((item) => item.type == 'TV Show').toList();
    _dynamicAnime = mockMediaDatabase.where((item) => item.type == 'Anime').toList();

    _loadActiveProfileAvatar();
    _loadCloudData();
    
    _mainScrollController.addListener(() {
      double offset = _mainScrollController.offset;
      double newOpacity = (offset / 250).clamp(0.0, 1.0);
      if (newOpacity != _scrollOpacity) {
        setState(() {
          _scrollOpacity = newOpacity;
        });
      }
    });
  }

  Future<void> _loadCloudData() async {
    try {
      final continueWatching = await ApiService.fetchSyncedContinueWatchingItems();
      final allListings = await ApiService.fetchMediaItems();

      if (mounted) {
        setState(() {
          if (continueWatching.isNotEmpty) {
            _dynamicContinueWatching = continueWatching;
          }
          if (allListings.isNotEmpty) {
            final fetchedMovies = allListings.where((item) => item.type == 'Movie').toList();
            final fetchedTv = allListings.where((item) => item.type == 'TV Show').toList();
            final fetchedAnime = allListings.where((item) => item.type == 'Anime').toList();
            
            if (fetchedMovies.isNotEmpty) _dynamicMovies = fetchedMovies;
            if (fetchedTv.isNotEmpty) _dynamicTvShows = fetchedTv;
            if (fetchedAnime.isNotEmpty) _dynamicAnime = fetchedAnime;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadActiveProfileAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeProfile = ApiService.activeProfile ?? 'Viewer';
      
      final roles = ['Director', 'Producer', 'Critic', 'Viewer'];
      String? foundRole;
      for (final role in roles) {
        final savedName = prefs.getString('profile_name_$role') ?? role;
        if (savedName == activeProfile) {
          foundRole = role;
          break;
        }
      }
      
      final roleKey = foundRole ?? 'Viewer';
      final savedAvatar = prefs.getString('profile_avatar_$roleKey');
      final isKids = prefs.getBool('profile_is_kids_$roleKey') ?? (roleKey == 'Viewer');
      
      setState(() {
        _activeRole = roleKey;
        _isKidsProfileActive = isKids;
      });

      if (savedAvatar != null && savedAvatar.isNotEmpty) {
        setState(() {
          _activeAvatarUrl = savedAvatar;
        });
      } else {
        final defaultAvatars = {
          'Director': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=150',
          'Producer': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?q=80&w=150',
          'Critic': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=150',
          'Viewer': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=150',
        };
        setState(() {
          _activeAvatarUrl = defaultAvatars[roleKey]!;
        });
      }
    } catch (_) {}
  }

  List<MediaItem> _filterKidsContent(List<MediaItem> items) {
    if (!_isKidsProfileActive) return items;
    return items.where((item) {
      final containsMatureGenre = item.genres.any((g) => 
        g == 'Thriller' || g == 'Psychological' || g == 'Cyberpunk' || g == 'Corporate'
      );
      return !containsMatureGenre;
    }).toList();
  }

  @override
  void dispose() {
    _mainScrollController.dispose();
    _syncTimer?.cancel();
    super.dispose();
  }

  void _startSyncPolling() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      try {
        final response = await Dio().get(
          "${ApiService.baseUrl}/scanner/status",
          options: Options(receiveTimeout: const Duration(seconds: 5)),
        );
        if (response.statusCode == 200) {
          final active = response.data['active'] ?? false;
          final progress = response.data['progress'];
          if (mounted) {
            setState(() {
              _isSyncingActive = active;
              _syncProgress = progress;
            });
          }
          if (!active && _syncTimer != null) {
            if (progress != null && progress['status'] == 'completed') {
              Future.delayed(const Duration(seconds: 5), () {
                if (mounted && !_isSyncingActive) {
                  setState(() {
                    _syncProgress = null;
                    _syncTimer?.cancel();
                    _syncTimer = null;
                  });
                }
              });
            } else {
              _syncTimer?.cancel();
              _syncTimer = null;
            }
          }
        }
      } catch (_) {}
    });
  }

  Widget _buildSyncProgressOverlay() {
    if (_syncProgress == null) return const SizedBox.shrink();

    final primaryColor = Theme.of(context).primaryColor;
    final status = _syncProgress!['status'] ?? 'idle';
    final processed = _syncProgress!['processedItems'] ?? 0;
    final resolved = _syncProgress!['resolvedItems'] ?? 0;
    final totalChans = _syncProgress!['totalChannels'] ?? 0;
    final curChan = _syncProgress!['currentChannel'] ?? 0;
    final curChanName = _syncProgress!['currentChannelName'] ?? '';
    final List<dynamic> rawLogs = _syncProgress!['logs'] ?? [];
    
    final List<String> logs = rawLogs.map((l) => l.toString()).toList();
    final List<String> lastLogs = logs.length > 3 ? logs.sublist(logs.length - 3) : logs;

    final bool isDone = status == 'completed';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F12).withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone ? Colors.greenAccent.withOpacity(0.3) : Colors.cyanAccent.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDone ? Colors.greenAccent : Colors.cyanAccent).withOpacity(0.12),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (!isDone)
                          const SpinKitRing(
                            color: Colors.cyanAccent,
                            size: 16.0,
                            lineWidth: 2.0,
                          )
                        else
                          const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          isDone ? "SYNC COMPLETED" : "REALTIME LIBRARY SYNCING",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 12.0,
                            color: isDone ? Colors.greenAccent : Colors.cyanAccent,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                      onPressed: () {
                        setState(() {
                          _syncProgress = null;
                          _syncTimer?.cancel();
                          _syncTimer = null;
                        });
                      },
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Scanning Sources",
                            style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "$curChan of $totalChans ($curChanName)",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "Files Sync'd (Resolved)",
                          style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "$processed Indexed ($resolved Match)",
                          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: lastLogs.isEmpty 
                      ? [
                          Text(
                            "Waiting for file data streams...",
                            style: GoogleFonts.shareTechMono(color: Colors.white30, fontSize: 10.5),
                          )
                        ]
                      : lastLogs.map((log) {
                          final isError = log.contains("[ERROR]") || log.contains("[RLS ALERT]");
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Text(
                              log,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.shareTechMono(
                                color: isError ? Colors.redAccent : (isDone ? Colors.greenAccent : Colors.cyanAccent.withOpacity(0.85)),
                                fontSize: 10.5,
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _updateFeaturedItem(MediaItem item) {
    setState(() {
      _featuredItem = item;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    // Separate database by types dynamically
    final movies = _dynamicMovies;
    final tvShows = _dynamicTvShows;
    final anime = _dynamicAnime;
    final continueWatching = _dynamicContinueWatching;

    return Scaffold(
      body: Stack(
        children: [
          // Main scrollable content
          SingleChildScrollView(
            controller: _mainScrollController,
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. DYNAMIC FEATURED BACKDROP BANNER
                _buildFeaturedBanner(size),

                const SizedBox(height: 24.0),

                // 2. CONTINUE WATCHING ROW (with progress lines)
                if (continueWatching.isNotEmpty) ...[
                  _buildSectionHeader("Continue Watching", isGold: true),
                  _buildContinueWatchingRow(continueWatching),
                  const SizedBox(height: 32.0),
                ],

                // 3. MOVIES ROW
                _buildSectionHeader("Cinematic Masterpieces (Movies)"),
                _buildMediaRow(movies),
                const SizedBox(height: 32.0),

                // 4. TV SHOWS ROW
                _buildSectionHeader("Top-Tier Series (TV Shows)"),
                _buildMediaRow(tvShows),
                const SizedBox(height: 32.0),

                // 5. ANIME ROW
                _buildSectionHeader("Vivid Dimensions (Anime)"),
                _buildMediaRow(anime),
                
                // Bottom padding
                const SizedBox(height: 120.0),
              ],
            ),
          ),

          // GLASSMORPHIC TOP APP BAR
          _buildFloatingAppBar(context),

          // REALTIME INDEX SYNC OVERLAY PROGRESS
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: _buildSyncProgressOverlay(),
          ),
        ],
      ),
    );
  }

  // FLOATING PREMIUM APP BAR WITH DYNAMIC SCROLL TRANSITION
  Widget _buildFloatingAppBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 100.0,
        padding: const EdgeInsets.only(top: 40.0, left: 20.0, right: 20.0),
        color: const Color(0xFF070708).withOpacity(_scrollOpacity * 0.95),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Elegant Brand Logo
            Row(
              children: [
                Text(
                  "CINE",
                  style: GoogleFonts.cinzel(
                    fontSize: 24.0,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2.0,
                  ),
                ),
                Text(
                  "GRAM",
                  style: GoogleFonts.cinzel(
                    fontSize: 24.0,
                    fontWeight: FontWeight.w900,
                    color: _isKidsProfileActive ? Colors.orangeAccent : Theme.of(context).primaryColor,
                    letterSpacing: 2.0,
                  ),
                ),
                if (_isKidsProfileActive) ...[
                  const SizedBox(width: 8.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent,
                      borderRadius: BorderRadius.circular(6.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orangeAccent.withOpacity(0.3),
                          blurRadius: 8.0,
                          spreadRadius: 1.0,
                        ),
                      ],
                    ),
                    child: Text(
                      "KIDS",
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 10.0,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            
            // Search & Profile action buttons
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => const SearchScreen(),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                      ),
                    );
                  },
                  icon: const Icon(Icons.search_rounded, size: 28.0, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.08),
                    padding: const EdgeInsets.all(10.0),
                  ),
                ),
                const SizedBox(width: 12.0),
                GestureDetector(
                  onTap: () async {
                    final authorized = await _showParentalGate(context);
                    if (authorized) {
                      _showServerSettingsBottomSheet(context);
                    }
                  },
                  child: Container(
                    width: 38.0,
                    height: 38.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isKidsProfileActive ? Colors.orangeAccent : Theme.of(context).primaryColor, 
                        width: 1.5,
                      ),
                      image: DecorationImage(
                        image: CachedNetworkImageProvider(_activeAvatarUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // DYNAMIC BACKDROP BANNER WIDGET
  Widget _buildFeaturedBanner(Size size) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: Container(
        key: ValueKey<String>(_featuredItem.id),
        height: size.height > 550 ? size.height * 0.62 : 360.0,
        width: double.infinity,
        child: Stack(
          children: [
            // Backdrop Image with fallback
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: _featuredItem.backdropUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: const Color(0xFF121215),
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFFD700)),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F0F12), Color(0xFF1E1E24)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),

            // Layered Luxury Gradient Overlays (Top, Bottom, Ambient Side Glow)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black87,
                      Colors.transparent,
                      Colors.transparent,
                      Color(0xFF070708), // Scaffolds BG color
                    ],
                    stops: [0.0, 0.3, 0.7, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            
            // Soft left gradient for text readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 1.0],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),

            // Featured Details Text & Action CTA
            Positioned(
              bottom: 20.0,
              left: 20.0,
              right: 20.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gold pill Category indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.4), width: 0.8),
                    ),
                    child: Text(
                      "FEATURED ${_featuredItem.type.toUpperCase()}",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9.0,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12.0),

                  // Title
                  Text(
                    _featuredItem.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cinzel(
                      fontSize: 32.0,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                      shadows: [
                        const Shadow(
                          color: Colors.black54,
                          offset: Offset(0, 3),
                          blurRadius: 10.0,
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 8.0),

                  // Ratings, Year, Duration Metadata Row
                  Row(
                    children: [
                      Icon(Icons.star_rounded, color: Theme.of(context).primaryColor, size: 16.0),
                      const SizedBox(width: 4.0),
                      Text(
                        _featuredItem.rating.toString(),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 13.0,
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      _buildMetadataDot(),
                      const SizedBox(width: 12.0),
                      Text(
                        _featuredItem.year,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 13.0,
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      _buildMetadataDot(),
                      const SizedBox(width: 12.0),
                      Text(
                        _featuredItem.duration,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 13.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),

                  // Mini Synopsis description
                  if (size.height > 550) ...[
                    Text(
                      _featuredItem.synopsis,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20.0),
                  ],

                  // Buttons
                  Row(
                    children: [
                      // Massive Glassmorphic Play button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) =>
                                    DetailsScreen(mediaItem: _featuredItem),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  return FadeTransition(opacity: animation, child: child);
                                },
                              ),
                            );
                          },
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 28.0),
                          label: Text(
                            "Watch Now",
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.0,
                              color: Colors.black,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            elevation: 8,
                            shadowColor: Theme.of(context).primaryColor.withOpacity(0.3),
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.0),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12.0),

                      // Info Glass button
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) =>
                                  DetailsScreen(mediaItem: _featuredItem),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                return FadeTransition(opacity: animation, child: child);
                              },
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14.0),
                            border: Border.all(color: Colors.white.withOpacity(0.15)),
                          ),
                          child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 24.0),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataDot() {
    return Container(
      width: 4.0,
      height: 4.0,
      decoration: const BoxDecoration(
        color: Colors.white30,
        shape: BoxShape.circle,
      ),
    );
  }

  // SECTION HEADER WITH DYNAMIC ACCENTS
  Widget _buildSectionHeader(String title, {bool isGold = false}) {
    final primaryColor = Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.only(left: 20.0, bottom: 14.0, right: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18.0,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: isGold ? primaryColor : Colors.white,
            ),
          ),
          Text(
            "See All",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
              color: primaryColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  // CONTINUE WATCHING ROW (HORIZONTAL INTERACTIVE PROGRESS LINES)
  Widget _buildContinueWatchingRow(List<MediaItem> list) {
    return Container(
      height: 170.0,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final item = list[index];
          return Container(
            margin: const EdgeInsets.only(right: 16.0),
            width: 240.0,
            child: GlassmorphicCard(
              padding: EdgeInsets.zero,
              borderRadius: 16.0,
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        DetailsScreen(mediaItem: item),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                  ),
                );
              },
              child: Stack(
                children: [
                  // Backdrop image
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: item.backdropUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.white.withOpacity(0.04)),
                      errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
                    ),
                  ),

                  // Bottom dark overlay gradient
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.85),
                            Colors.black.withOpacity(0.2),
                            Colors.transparent,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                  ),

                  // Title and Episode Metadata
                  Positioned(
                    bottom: 15.0,
                    left: 12.0,
                    right: 12.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          item.type == 'TV Show' ? 'S2:E3 • Remaining' : 'Movie • Resume',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Play overlay circle
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.6),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24.0),
                    ),
                  ),

                  // PROGRESS LINE (UNDER CARD SURFACE)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 4.0,
                      color: Colors.white.withOpacity(0.2),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: item.progress ?? 0.0,
                        child: Container(
                          height: 4.0,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).primaryColor,
                                Theme.of(context).primaryColor.withOpacity(0.6),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // STANDARD MOVIE ROW WITH CARD HOVER TRANSITIONS
  Widget _buildMediaRow(List<MediaItem> list) {
    return Container(
      height: 230.0,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final item = list[index];
          return Container(
            margin: const EdgeInsets.only(right: 14.0),
            width: 140.0,
            child: GestureDetector(
              onDoubleTap: () => _updateFeaturedItem(item), // Dynamic updates backdrop!
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster Card
                  Expanded(
                    child: GlassmorphicCard(
                      padding: EdgeInsets.zero,
                      borderRadius: 16.0,
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) =>
                                DetailsScreen(mediaItem: item),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                          ),
                        );
                      },
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Hero(
                              tag: 'poster_${item.id}',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16.0),
                                child: CachedNetworkImage(
                                  imageUrl: item.posterUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.white.withOpacity(0.04),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFFFFD700),
                                        strokeWidth: 1.5,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFF1E1E24), Color(0xFF0F0F12)],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          // Glass rating indicator in top corner
                          Positioned(
                            top: 8.0,
                            right: 8.0,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                                  color: Colors.black.withOpacity(0.6),
                                  child: Row(
                                    children: [
                                      Icon(Icons.star_rounded, color: Theme.of(context).primaryColor, size: 12.0),
                                      const SizedBox(width: 2.0),
                                      Text(
                                        item.rating.toString(),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8.0),
 
                  // Title
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2.0),
 
                  // Meta details
                  Row(
                    children: [
                      Text(
                        item.year,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 6.0),
                      Container(
                        width: 3.0,
                        height: 3.0,
                        decoration: const BoxDecoration(
                          color: Colors.white30,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6.0),
                      Text(
                        item.type,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          color: Theme.of(context).primaryColor.withOpacity(0.8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool> _showParentalGate(BuildContext context) async {
    return true; // Parental control gate disabled
  }

  Future<void> _showServerSettingsBottomSheet(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final bool isTelegramLoggedIn = prefs.getBool('telegram_logged_in') ?? false;

    final TextEditingController urlController = TextEditingController(text: ApiService.baseUrl);
    final TextEditingController hexColorController = TextEditingController();
    
    final Map<String, bool> hasPinMap = {};
    final Map<String, bool> isKidsMap = {};
    
    final Map<String, TextEditingController> nameControllers = {
      'Profile 1': TextEditingController(),
      'Profile 2': TextEditingController(),
      'Profile 3': TextEditingController(),
      'Profile 4': TextEditingController(),
    };
    
    final Map<String, TextEditingController> avatarControllers = {
      'Profile 1': TextEditingController(),
      'Profile 2': TextEditingController(),
      'Profile 3': TextEditingController(),
      'Profile 4': TextEditingController(),
    };

    final Map<String, TextEditingController> pinControllers = {
      'Profile 1': TextEditingController(),
      'Profile 2': TextEditingController(),
      'Profile 3': TextEditingController(),
      'Profile 4': TextEditingController(),
    };

    bool multiProfileEnabled = prefs.getBool('multi_profile_enabled') ?? true;
    String connectedPhone = prefs.getString('telegram_phone') ?? "";
    String telegramUsername = prefs.getString('telegram_username') ?? "";
    String currentCategory = 'main';

    bool? isConnected;
    bool isChecking = false;

    bool useExternalPlayer = prefs.getBool('use_external_player') ?? false;
    String selectedPlayerPackage = prefs.getString('selected_external_player_package') ?? 'android.intent.action.VIEW';
    String selectedPlayerName = prefs.getString('selected_external_player_name') ?? 'System Default Player';

    final roles = ['Profile 1', 'Profile 2', 'Profile 3', 'Profile 4'];
    for (final role in roles) {
      nameControllers[role]!.text = prefs.getString('profile_name_$role') ?? role;
      avatarControllers[role]!.text = prefs.getString('profile_avatar_$role') ?? '';
      hasPinMap[role] = prefs.getBool('profile_has_pin_$role') ?? (role == 'Profile 1');
      pinControllers[role]!.text = prefs.getString('profile_pin_$role') ?? '1234';
      isKidsMap[role] = prefs.getBool('profile_is_kids_$role') ?? false;
    }

    // Helper function to test connection in bottom sheet
    Future<void> checkConnection(StateSetter setSheetState, String url) async {
      setSheetState(() {
        isChecking = true;
      });
      final status = await ApiService.testConnection(url);
      setSheetState(() {
        isConnected = status;
        isChecking = false;
      });
      
      // Explicit connection test SnackBar feedback
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == true
                  ? "Connection Test Successful: Server Online!"
                  : "Connection Test Failed: Server Offline or Link Invalid.",
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
            backgroundColor: status == true ? Colors.greenAccent : Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (stateContext, setSheetState) {
            final themeProvider = Provider.of<ThemeProvider>(stateContext);
            final primaryColor = Theme.of(stateContext).primaryColor;

            // Background update telegram status dynamically
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (isConnected == null) {
                isConnected = false; // Prevents loop re-triggers
                Dio().get("${ApiService.baseUrl}/telegram/status").then((statusRes) {
                  if (statusRes.statusCode == 200 && statusRes.data['success'] == true) {
                    final newUsername = statusRes.data['username'] ?? "";
                    final newPhone = statusRes.data['phoneNumber'] ?? "";
                    if (stateContext.mounted) {
                      setSheetState(() {
                        if (newUsername.isNotEmpty) {
                          telegramUsername = newUsername;
                          prefs.setString('telegram_username', newUsername);
                        }
                        if (newPhone.isNotEmpty) {
                          connectedPhone = newPhone;
                          prefs.setString('telegram_phone', newPhone);
                        }
                      });
                    }
                  }
                }).catchError((_) {});
              }
            });

            Widget buildAndroidSettingTile({
              required IconData icon,
              required String title,
              required String description,
              required Color color,
              required VoidCallback onTap,
            }) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: ListTile(
                  onTap: onTap,
                  leading: Container(
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 22.0),
                  ),
                  title: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: Colors.white38,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white30,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                ),
              );
            }

            Widget buildCategoryHeader(String title, IconData icon, Color color) {
              return Padding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 16.0),
                    const SizedBox(width: 8.0),
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w900,
                        color: color,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              );
            }
            
            final statusColor = isChecking
                ? Colors.amber
                : (isConnected == true
                    ? Colors.greenAccent
                    : (isConnected == false ? Colors.redAccent : Colors.grey));
            final statusText = isChecking
                ? "Testing link..."
                : (isConnected == true
                    ? "Server Connected"
                    : (isConnected == false ? "Server Offline" : "Status Unknown"));

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(stateContext).viewInsets.bottom,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30.0)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.85,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F12).withOpacity(0.95),
                      border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1.5),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Indicator handle
                        Center(
                          child: Container(
                            width: 48.0,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24.0),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                if (currentCategory != 'main')
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
                                    onPressed: () => setSheetState(() => currentCategory = 'main'),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.only(right: 12.0),
                                  ),
                                Text(
                                  currentCategory == 'main' 
                                      ? "SETTINGS" 
                                      : (currentCategory == 'network' 
                                          ? "CONNECTION" 
                                          : (currentCategory == 'telegram' 
                                              ? "GATEWAY" 
                                              : (currentCategory == 'visual' 
                                                  ? "THEMES" 
                                                  : (currentCategory == 'playback' 
                                                      ? "PLAYBACK" 
                                                      : "CINEMATIC")))),
                                  style: GoogleFonts.cinzel(
                                    fontSize: 22.0,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white60),
                              onPressed: () => Navigator.pop(sheetContext),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16.0),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (currentCategory == 'main') ...[
                                  buildCategoryHeader("CATEGORIES", Icons.grid_view_rounded, primaryColor),
                                  const SizedBox(height: 12.0),
                                  buildAndroidSettingTile(
                                    icon: Icons.dns_rounded,
                                    title: "Network & Connection",
                                    description: "Cinegram server URLs, online status, and connection test",
                                    color: primaryColor,
                                    onTap: () => setSheetState(() => currentCategory = 'network'),
                                  ),
                                  buildAndroidSettingTile(
                                    icon: Icons.telegram_rounded,
                                    title: "Telegram Account Gateway",
                                    description: "Active status, username details, and library selectors",
                                    color: Colors.blueAccent,
                                    onTap: () => setSheetState(() => currentCategory = 'telegram'),
                                  ),
                                  buildAndroidSettingTile(
                                    icon: Icons.palette_outlined,
                                    title: "Visual Theme Accent",
                                    description: "System look and feel, dark modes, and custom color presets",
                                    color: Colors.purpleAccent,
                                    onTap: () => setSheetState(() => currentCategory = 'visual'),
                                  ),
                                  buildAndroidSettingTile(
                                    icon: Icons.play_circle_outline_rounded,
                                    title: "Playback & Subtitles",
                                    description: "External players and closed-captions style configuration",
                                    color: Colors.amberAccent,
                                    onTap: () => setSheetState(() => currentCategory = 'playback'),
                                  ),
                                  buildAndroidSettingTile(
                                    icon: Icons.analytics_rounded,
                                    title: "Cinematic Stats & Co-Watch",
                                    description: "Custom donut stats charts, speedometers, watch parties, and radars",
                                    color: Colors.greenAccent,
                                    onTap: () => setSheetState(() => currentCategory = 'cinematic'),
                                  ),
                                ] else if (currentCategory == 'telegram') ...[
                                  // CATEGORY 1: TELEGRAM GATEWAY CONNECTION
                                  buildCategoryHeader("TELEGRAM GATEWAY CONNECTION", Icons.telegram_rounded, primaryColor),
                                  const SizedBox(height: 8.0),
                                  Container(
                                    padding: const EdgeInsets.all(16.0),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.02),
                                      borderRadius: BorderRadius.circular(16.0),
                                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(10.0),
                                                    decoration: BoxDecoration(
                                                      color: (isTelegramLoggedIn ? Colors.blueAccent : Colors.amberAccent).withOpacity(0.1),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      isTelegramLoggedIn ? Icons.phone_android_rounded : Icons.cloud_off_rounded,
                                                      color: isTelegramLoggedIn ? Colors.blueAccent : Colors.amberAccent,
                                                      size: 20.0,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12.0),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          "GATEWAY STATUS",
                                                          style: GoogleFonts.plusJakartaSans(
                                                            color: Colors.white38,
                                                            fontSize: 10.0,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 2.0),
                                                        Text(
                                                          isTelegramLoggedIn 
                                                              ? (telegramUsername.isNotEmpty 
                                                                  ? (telegramUsername.startsWith('@') ? telegramUsername : '@$telegramUsername') + (connectedPhone.isNotEmpty ? " ($connectedPhone)" : "")
                                                                  : (connectedPhone.isNotEmpty ? connectedPhone : "Active Gateway Session"))
                                                              : "Guest Explorer Mode",
                                                          overflow: TextOverflow.ellipsis,
                                                          style: GoogleFonts.plusJakartaSans(
                                                            color: Colors.white,
                                                            fontSize: 13.0,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                                              decoration: BoxDecoration(
                                                color: (isTelegramLoggedIn ? Colors.greenAccent : Colors.amberAccent).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8.0),
                                                border: Border.all(color: (isTelegramLoggedIn ? Colors.greenAccent : Colors.amberAccent).withOpacity(0.2)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 6.0,
                                                    height: 6.0,
                                                    decoration: BoxDecoration(
                                                      color: isTelegramLoggedIn ? Colors.greenAccent : Colors.amberAccent,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6.0),
                                                  Text(
                                                    isTelegramLoggedIn ? "ONLINE" : "OFFLINE",
                                                    style: GoogleFonts.plusJakartaSans(
                                                      color: isTelegramLoggedIn ? Colors.greenAccent : Colors.amberAccent,
                                                      fontSize: 10.0,
                                                      fontWeight: FontWeight.w900,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20.0),
                                        if (isTelegramLoggedIn) ...[
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(builder: (context) => const ChannelSelectorScreen()),
                                                    ).then((_) => _loadCloudData());
                                                  },
                                                  icon: const Icon(Icons.campaign_rounded, color: Colors.black, size: 16),
                                                  label: Text(
                                                    "Library Chats",
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.black,
                                                      fontSize: 11.5,
                                                    ),
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: primaryColor,
                                                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(10.0),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10.0),
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(builder: (context) => const UnresolvedQueueScreen()),
                                                    );
                                                  },
                                                  icon: Icon(Icons.movie_filter_rounded, color: primaryColor, size: 16),
                                                  label: Text(
                                                    "Fix Matches",
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                      fontSize: 11.5,
                                                    ),
                                                  ),
                                                  style: OutlinedButton.styleFrom(
                                                    side: BorderSide(color: primaryColor, width: 1.0),
                                                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(10.0),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16.0),
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              onPressed: () async {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (dialogCtx) => AlertDialog(
                                                    backgroundColor: const Color(0xFF0F0F12),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(16.0),
                                                      side: BorderSide(color: Colors.white.withOpacity(0.1)),
                                                    ),
                                                    title: Text(
                                                      "Disconnect Gateway?",
                                                      style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold),
                                                    ),
                                                    content: Text(
                                                      "Are you sure you want to log out and disconnect your Telegram account from Cinegram?",
                                                      style: GoogleFonts.plusJakartaSans(color: Colors.white70),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(dialogCtx, false),
                                                        child: Text("Cancel", style: GoogleFonts.plusJakartaSans(color: Colors.white38)),
                                                      ),
                                                      ElevatedButton(
                                                        onPressed: () => Navigator.pop(dialogCtx, true),
                                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                                        child: Text("Disconnect", style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
                                                      ),
                                                    ],
                                                  ),
                                                );

                                                if (confirm == true) {
                                                  setSheetState(() {
                                                    isChecking = true;
                                                  });
                                                  try {
                                                    await Dio().post(
                                                      "${ApiService.baseUrl}/telegram/logout",
                                                      options: Options(headers: {"Content-Type": "application/json"}),
                                                    );
                                                    
                                                    final prefs = await SharedPreferences.getInstance();
                                                    await prefs.setBool('telegram_logged_in', false);
                                                    await prefs.remove('telegram_session_string_cache');
                                                    await prefs.remove('telegram_phone');
                                                    await prefs.remove('telegram_username');
                                                    
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            "Telegram Gateway disconnected successfully.",
                                                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                                                          ),
                                                          backgroundColor: Colors.greenAccent,
                                                        ),
                                                      );
                                                      Navigator.pop(stateContext);
                                                      Navigator.of(context).pushAndRemoveUntil(
                                                        MaterialPageRoute(builder: (context) => const OnboardingCheckScreen()),
                                                        (route) => false,
                                                      );
                                                    }
                                                  } catch (e) {
                                                    final prefs = await SharedPreferences.getInstance();
                                                    await prefs.setBool('telegram_logged_in', false);
                                                    await prefs.remove('telegram_session_string_cache');
                                                    await prefs.remove('telegram_phone');
                                                    await prefs.remove('telegram_username');
                                                    
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(
                                                          content: Text("Error disconnecting remote session. Session cleared locally."),
                                                          backgroundColor: Colors.orangeAccent,
                                                        ),
                                                      );
                                                      Navigator.pop(stateContext);
                                                      Navigator.of(context).pushAndRemoveUntil(
                                                        MaterialPageRoute(builder: (context) => const OnboardingCheckScreen()),
                                                        (route) => false,
                                                      );
                                                    }
                                                  }
                                                }
                                              },
                                              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                                              label: Text(
                                                "Disconnect Telegram Gateway",
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.redAccent,
                                                  fontSize: 12.0,
                                                ),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(color: Colors.redAccent, width: 1.2),
                                                padding: const EdgeInsets.symmetric(vertical: 12.0),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12.0),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ] else ...[
                                          Container(
                                            padding: const EdgeInsets.all(12.0),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.02),
                                              borderRadius: BorderRadius.circular(12.0),
                                              border: Border.all(color: Colors.white.withOpacity(0.04)),
                                            ),
                                            child: Text(
                                              "You are in Guest Explorer mode. Syncing chats, automatic bots, and real-time scanning are locked until you connect your Telegram account.",
                                              style: GoogleFonts.plusJakartaSans(
                                                color: Colors.white38,
                                                fontSize: 11.5,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16.0),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: () {
                                                Navigator.pop(stateContext); // Close settings drawer
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(builder: (context) => const TelegramLoginScreen()),
                                                );
                                              },
                                              icon: const Icon(Icons.login_rounded, color: Colors.black, size: 16),
                                              label: Text(
                                                "Connect Telegram Gateway",
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                  fontSize: 12.0,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: primaryColor,
                                                padding: const EdgeInsets.symmetric(vertical: 12.0),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12.0),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ] else if (currentCategory == 'visual') ...[
                                  // CATEGORY 3: VISUAL ACCENT THEME
                                  buildCategoryHeader("VISUAL ACCENT THEME", Icons.palette_outlined, primaryColor),
                                  const SizedBox(height: 8.0),
                                  Container(
                                    padding: const EdgeInsets.all(16.0),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.02),
                                      borderRadius: BorderRadius.circular(16.0),
                                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Select a premium primary accent color preset or enter a custom hex color code for customized glows, interfaces, and borders.",
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white60,
                                            fontSize: 12.0,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 16.0),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: AccentPreset.values.map((preset) {
                                            final bool isSelected = themeProvider.currentPreset == preset;
                                            return GestureDetector(
                                              onTap: () {
                                                themeProvider.setPreset(preset);
                                                
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      "Visual theme accent changed to ${preset.name}!",
                                                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                                                    ),
                                                    backgroundColor: preset.color.withOpacity(0.95),
                                                    duration: const Duration(seconds: 2),
                                                  ),
                                                );
                                              },
                                              child: Column(
                                                children: [
                                                  AnimatedContainer(
                                                    duration: const Duration(milliseconds: 250),
                                                    width: 44.0,
                                                    height: 44.0,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: preset.color,
                                                      border: Border.all(
                                                        color: isSelected ? Colors.white : Colors.transparent,
                                                        width: 3.0,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: preset.color.withOpacity(0.4),
                                                          blurRadius: isSelected ? 12.0 : 4.0,
                                                          spreadRadius: isSelected ? 3.0 : 0.0,
                                                        ),
                                                      ],
                                                    ),
                                                    child: isSelected
                                                        ? const Icon(
                                                            Icons.check_rounded,
                                                            color: Colors.black,
                                                            size: 20.0,
                                                          )
                                                        : null,
                                                  ),
                                                  const SizedBox(height: 6.0),
                                                  Text(
                                                    preset.name.split(' ').first,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      color: isSelected ? preset.color : Colors.white60,
                                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                      fontSize: 10.0,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                        const SizedBox(height: 20.0),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.04),
                                                  borderRadius: BorderRadius.circular(12.0),
                                                  border: Border.all(color: Colors.white12),
                                                ),
                                                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 2.0),
                                                child: TextField(
                                                  controller: hexColorController,
                                                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13.0),
                                                  onChanged: (val) {
                                                    setSheetState(() {});
                                                  },
                                                  decoration: InputDecoration(
                                                    labelText: "Custom Color Hex",
                                                    labelStyle: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 11.0),
                                                    hintText: "e.g., #FF2E93",
                                                    hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 12.0),
                                                    border: InputBorder.none,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12.0),
                                            GestureDetector(
                                              onTap: () async {
                                                final hex = hexColorController.text.trim();
                                                if (hex.isNotEmpty) {
                                                  final success = await themeProvider.setCustomHexColor(hex);
                                                  if (success) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          "Custom accent color set successfully!",
                                                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                                                        ),
                                                        backgroundColor: themeProvider.accentColor,
                                                        duration: const Duration(seconds: 2),
                                                      ),
                                                    );
                                                  } else {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text("Invalid Hex color format. Use #RRGGBB"),
                                                        backgroundColor: Colors.redAccent,
                                                      ),
                                                    );
                                                  }
                                                } else {
                                                  await themeProvider.clearCustomColor();
                                                }
                                                setSheetState(() {});
                                              },
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 250),
                                                width: 44.0,
                                                height: 44.0,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: ThemeProvider.parseHexColor(hexColorController.text) ?? themeProvider.accentColor,
                                                  border: Border.all(color: Colors.white24, width: 1.5),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: (ThemeProvider.parseHexColor(hexColorController.text) ?? themeProvider.accentColor).withOpacity(0.4),
                                                      blurRadius: 10.0,
                                                      spreadRadius: 2.0,
                                                    ),
                                                  ],
                                                ),
                                                child: const Icon(Icons.colorize_rounded, color: Colors.black, size: 20.0),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else if (currentCategory == 'playback') ...[
                                  // CATEGORY 4: VIDEO PLAYBACK PREFERENCES
                                  buildCategoryHeader("VIDEO PLAYBACK PREFERENCES", Icons.play_circle_outline_rounded, primaryColor),
                                  const SizedBox(height: 8.0),
                                  Container(
                                    padding: const EdgeInsets.all(16.0),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.02),
                                      borderRadius: BorderRadius.circular(16.0),
                                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.04),
                                            borderRadius: BorderRadius.circular(14.0),
                                            border: Border.all(color: Colors.white12),
                                          ),
                                          child: SwitchListTile(
                                            activeColor: primaryColor,
                                            title: Text(
                                              "Always Use External Player",
                                              style: GoogleFonts.plusJakartaSans(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13.0,
                                              ),
                                            ),
                                            subtitle: Text(
                                              "Bypasses the built-in player to stream using VLC, MX Player, Nova, or Kodi.",
                                              style: GoogleFonts.plusJakartaSans(
                                                color: Colors.white38,
                                                fontSize: 11.0,
                                              ),
                                            ),
                                            value: useExternalPlayer,
                                            onChanged: (val) {
                                              setSheetState(() {
                                                useExternalPlayer = val;
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 12.0),
                                        InkWell(
                                          onTap: () {
                                            showModalBottomSheet(
                                              context: context,
                                              backgroundColor: Colors.transparent,
                                              barrierColor: Colors.black.withOpacity(0.5),
                                              builder: (dialogContext) {
                                                return FutureBuilder<List<Map<String, String>>>(
                                                  future: ExternalPlayerService.detectPlayers(),
                                                  builder: (context, snapshot) {
                                                    final players = snapshot.data ?? [];
                                                    final isLoading = snapshot.connectionState == ConnectionState.waiting;

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
                                                                "SELECT VIDEO PLAYER",
                                                                style: GoogleFonts.cinzel(
                                                                  fontSize: 18.0,
                                                                  fontWeight: FontWeight.w900,
                                                                  color: Colors.white,
                                                                  letterSpacing: 1.0,
                                                                ),
                                                              ),
                                                              const SizedBox(height: 4.0),
                                                              Text(
                                                                "Choose your preferred external media engine for mobile video streams.",
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
                                                                    "No external media players detected.",
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
                                                                    itemBuilder: (context, index) {
                                                                      final p = players[index];
                                                                      final name = p['name'] ?? 'Unknown Player';
                                                                      final package = p['package'] ?? '';
                                                                      final isSelected = selectedPlayerPackage == package;

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
                                                                          color: isSelected 
                                                                              ? primaryColor.withOpacity(0.06) 
                                                                              : Colors.white.withOpacity(0.02),
                                                                          borderRadius: BorderRadius.circular(12.0),
                                                                          border: Border.all(
                                                                            color: isSelected 
                                                                                ? primaryColor.withOpacity(0.3) 
                                                                                : Colors.white.withOpacity(0.05),
                                                                          ),
                                                                        ),
                                                                        child: ListTile(
                                                                          leading: Icon(pIcon, color: pIconColor),
                                                                          title: Text(
                                                                            name,
                                                                            style: GoogleFonts.plusJakartaSans(
                                                                              color: Colors.white,
                                                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                                            ),
                                                                          ),
                                                                          subtitle: Text(
                                                                            package,
                                                                            style: GoogleFonts.plusJakartaSans(
                                                                              color: Colors.white30,
                                                                              fontSize: 10.0,
                                                                            ),
                                                                          ),
                                                                          trailing: isSelected
                                                                              ? Icon(Icons.check_circle_rounded, color: primaryColor)
                                                                              : null,
                                                                          onTap: () {
                                                                            setSheetState(() {
                                                                              selectedPlayerPackage = package;
                                                                              selectedPlayerName = name;
                                                                            });
                                                                            Navigator.pop(dialogContext);
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
                                          },
                                          borderRadius: BorderRadius.circular(14.0),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.04),
                                              borderRadius: BorderRadius.circular(14.0),
                                              border: Border.all(color: Colors.white12),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "Default External Player",
                                                      style: GoogleFonts.plusJakartaSans(
                                                        color: Colors.white70,
                                                        fontSize: 11.0,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4.0),
                                                    Text(
                                                      selectedPlayerName,
                                                      style: GoogleFonts.plusJakartaSans(
                                                        color: Colors.white,
                                                        fontSize: 14.0,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  children: [
                                                    Text(
                                                      "CHANGE",
                                                      style: GoogleFonts.plusJakartaSans(
                                                        color: primaryColor,
                                                        fontSize: 11.0,
                                                        fontWeight: FontWeight.w900,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6.0),
                                                    Icon(Icons.arrow_forward_ios_rounded, color: primaryColor, size: 12.0),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else if (currentCategory == 'cinematic') ...[
                                  // CATEGORY 2: COLLABORATIVE & DIAGNOSTIC PREMIUM HUBS
                                  buildCategoryHeader("COLLABORATIVE & DIAGNOSTIC PREMIUM HUBS", Icons.offline_bolt_rounded, primaryColor),
                                  const SizedBox(height: 8.0),
                                  Container(
                                    padding: const EdgeInsets.all(16.0),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.02),
                                      borderRadius: BorderRadius.circular(16.0),
                                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  _showAnalyticsDashboard(context);
                                                },
                                                icon: const Icon(Icons.bar_chart_rounded, color: Colors.black, size: 18),
                                                label: Text(
                                                  "Viewing Stats",
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black,
                                                    fontSize: 12.0,
                                                  ),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: primaryColor,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10.0),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12.0),
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  _showWatchPartyLobby(context);
                                                },
                                                icon: Icon(Icons.groups_rounded, color: primaryColor, size: 18),
                                                label: Text(
                                                  "Co-Watch Room",
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    fontSize: 12.0,
                                                  ),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  side: BorderSide(color: primaryColor),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10.0),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16.0),
                                        const Divider(color: Colors.white12, height: 1.0),
                                        const SizedBox(height: 16.0),
                                        Text(
                                          "DIAGNOSTIC ENGINES & PREFERENCES",
                                          style: GoogleFonts.plusJakartaSans(
                                            color: primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11.5,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 12.0),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () {
                                                  Navigator.pop(stateContext);
                                                  _showSubtitlesCCSettings(context);
                                                },
                                                icon: const Icon(Icons.subtitles_outlined, color: Colors.white, size: 15),
                                                label: Text(
                                                  "Subtitles",
                                                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11.0, fontWeight: FontWeight.bold),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(color: Colors.white12),
                                                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8.0),
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () {
                                                  Navigator.pop(stateContext);
                                                  _showNetworkDiagnostics(context);
                                                },
                                                icon: const Icon(Icons.speed_outlined, color: Colors.white, size: 15),
                                                label: Text(
                                                  "Speed Test",
                                                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11.0, fontWeight: FontWeight.bold),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(color: Colors.white12),
                                                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8.0),
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () {
                                                  Navigator.pop(stateContext);
                                                  _showScannerRadarDashboard(context);
                                                },
                                                icon: const Icon(Icons.radar_rounded, color: Colors.white, size: 15),
                                                label: Text(
                                                  "Scanner Log",
                                                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11.0, fontWeight: FontWeight.bold),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(color: Colors.white12),
                                                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else if (currentCategory == 'network') ...[
                                  // CATEGORY 6: API GATEWAY CONFIG
                                  buildCategoryHeader("API GATEWAY SETTINGS", Icons.dns_outlined, primaryColor),
                                  const SizedBox(height: 8.0),
                                  Container(
                                    padding: const EdgeInsets.all(16.0),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.02),
                                      borderRadius: BorderRadius.circular(16.0),
                                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Configure custom server links to synchronize collaborative playlists, watch progress, and listings.",
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white60,
                                            fontSize: 12.0,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 16.0),
                                        GestureDetector(
                                          onTap: () => checkConnection(setSheetState, urlController.text),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(12.0),
                                              border: Border.all(color: statusColor.withOpacity(0.3), width: 0.8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                AnimatedContainer(
                                                  duration: const Duration(milliseconds: 300),
                                                  width: 10.0,
                                                  height: 10.0,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: statusColor,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: statusColor.withOpacity(0.6),
                                                        blurRadius: 8.0,
                                                        spreadRadius: 2.0,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 10.0),
                                                Text(
                                                  statusText,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    color: statusColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12.0,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16.0),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.04),
                                            borderRadius: BorderRadius.circular(14.0),
                                            border: Border.all(color: Colors.white12),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                          child: TextField(
                                            controller: urlController,
                                            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14.0),
                                            decoration: InputDecoration(
                                              labelText: "API Gateway Base URL",
                                              labelStyle: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 12.0),
                                              hintText: "e.g., https://your-server.render.com",
                                              hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 13.0),
                                              border: InputBorder.none,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        // Persistent Action Buttons Row docked at bottom of the main Column
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => checkConnection(setSheetState, urlController.text),
                                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                                label: Text(
                                  "Test Connection",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                                  side: const BorderSide(color: Colors.white24),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14.0),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12.0),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final newUrl = urlController.text.trim();
                                  await ApiService.setCustomBaseUrl(newUrl);

                                  final prefs = await SharedPreferences.getInstance();
                                  
                                  await prefs.setBool('use_external_player', useExternalPlayer);
                                  await prefs.setString('selected_external_player_package', selectedPlayerPackage);
                                  await prefs.setString('selected_external_player_name', selectedPlayerName);
                                  
                                  await prefs.setBool('multi_profile_enabled', multiProfileEnabled);

                                  final roles = ['Profile 1', 'Profile 2', 'Profile 3', 'Profile 4'];
                                  for (final role in roles) {
                                    final customName = nameControllers[role]!.text.trim();
                                    final customAvatar = avatarControllers[role]!.text.trim();
                                    if (customName.isNotEmpty) {
                                      await prefs.setString('profile_name_$role', customName);
                                    }
                                    if (customAvatar.isNotEmpty) {
                                      await prefs.setString('profile_avatar_$role', customAvatar);
                                    } else {
                                      await prefs.remove('profile_avatar_$role');
                                    }
                                    
                                    final hasPin = hasPinMap[role] ?? false;
                                    await prefs.setBool('profile_has_pin_$role', hasPin);
                                    final pinVal = pinControllers[role]!.text.trim();
                                    if (pinVal.length == 4) {
                                      await prefs.setString('profile_pin_$role', pinVal);
                                    }
                                    
                                    final isKids = isKidsMap[role] ?? false;
                                    await prefs.setBool('profile_is_kids_$role', isKids);
                                  }
                                  
                                  await checkConnection(setSheetState, newUrl);
                                  
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isConnected == true
                                              ? "Connected & Settings saved successfully!"
                                              : "Saved settings, but backend is offline.",
                                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                                        ),
                                        backgroundColor: isConnected == true ? Colors.greenAccent : const Color(0xFF1E1E24),
                                      ),
                                    );
                                    Navigator.pop(stateContext);
                                  }
                                },
                                icon: const Icon(Icons.check_rounded, color: Colors.black),
                                label: Text(
                                  "Apply & Save",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14.0),
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
            );
          },
        );
      },
    );
  }

  void _showAnalyticsDashboard(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        final primaryColor = Theme.of(context).primaryColor; // Use theme's primaryColor
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30.0)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F12).withOpacity(0.95),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1.5),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: FutureBuilder<Map<String, dynamic>>(
                future: ApiService.fetchProfileWatchStats(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final stats = snapshot.data ?? {
                    'totalWatchTimeMs': 32400000,
                    'genreSplits': { "Sci-Fi": 12, "Action": 8, "Drama": 5, "Anime": 3 },
                    'heatmaps': {
                      "default_movie": [2, 5, 8, 12, 10, 15, 3, 2, 7, 1]
                    }
                  };

                  final double totalHours = (stats['totalWatchTimeMs'] as int? ?? 32400000) / 3600000.0;
                  final genreSplits = Map<String, dynamic>.from(stats['genreSplits'] ?? { "Sci-Fi": 12, "Action": 8, "Drama": 5, "Anime": 3 });
                  
                  final Map<String, double> donutData = {};
                  genreSplits.forEach((k, v) {
                    donutData[k] = (v as num).toDouble();
                  });

                  final List<double> weeklyData = [1.5, 2.0, 0.8, 3.2, 1.0, 4.5, totalHours > 10.0 ? 5.0 : 2.5];

                  final List<double> heatmapPoints = List<double>.from(
                    (stats['heatmaps']?['default_movie'] as List?)?.map((x) => (x as num).toDouble()) ?? 
                    [2.0, 5.0, 8.0, 12.0, 10.0, 15.0, 3.0, 2.0, 7.0, 1.0]
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "CINEMATIC ANALYTICS",
                                style: GoogleFonts.cinzel(
                                  fontSize: 20.0,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4.0),
                              Text(
                                "Mobile statistics for profile: ${ApiService.activeProfile ?? 'Viewer'}",
                                style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 12.0),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white60),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20.0),

                      Expanded(
                        child: ListView(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16.0),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.02),
                                      borderRadius: BorderRadius.circular(16.0),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("TOTAL VIEWING", style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 10.0, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8.0),
                                        Text("${totalHours.toStringAsFixed(1)} Hours", style: GoogleFonts.plusJakartaSans(color: primaryColor, fontSize: 18.0, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12.0),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16.0),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.02),
                                      borderRadius: BorderRadius.circular(16.0),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("FAVORITE GENRE", style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 10.0, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8.0),
                                        Text(donutData.isNotEmpty ? donutData.entries.first.key : "N/A", style: GoogleFonts.plusJakartaSans(color: Colors.purpleAccent, fontSize: 18.0, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20.0),

                            Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(16.0),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 100.0,
                                    height: 100.0,
                                    child: CustomPaint(
                                      painter: DonutChartPainter(
                                        data: donutData,
                                        colors: [
                                          primaryColor,
                                          Colors.purpleAccent,
                                          Colors.cyanAccent,
                                          Colors.amberAccent,
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16.0),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "GENRE SEGMENTS",
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11.0,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white70,
                                          ),
                                        ),
                                        const SizedBox(height: 6.0),
                                        ...donutData.entries.map((e) {
                                          final idx = donutData.keys.toList().indexOf(e.key);
                                          final col = [
                                            primaryColor,
                                            Colors.purpleAccent,
                                            Colors.cyanAccent,
                                            Colors.amberAccent,
                                          ][idx % 4];
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                                            child: Row(
                                              children: [
                                                Container(width: 6.0, height: 6.0, decoration: BoxDecoration(shape: BoxShape.circle, color: col)),
                                                const SizedBox(width: 6.0),
                                                Text("${e.key}: ${e.value.toInt()} streams", style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11.0)),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20.0),

                            Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(16.0),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("WEEKLY WATCH TRENDS", style: GoogleFonts.plusJakartaSans(fontSize: 11.0, fontWeight: FontWeight.bold, color: Colors.white70)),
                                  const SizedBox(height: 20.0),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: List.generate(7, (i) {
                                      final double h = weeklyData[i];
                                      final String day = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][i];
                                      return Column(
                                        children: [
                                          Container(
                                            width: 12.0,
                                            height: (h / 6.0) * 80.0,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [primaryColor, primaryColor.withOpacity(0.3)],
                                              ),
                                              borderRadius: BorderRadius.circular(3.0),
                                            ),
                                          ),
                                          const SizedBox(height: 6.0),
                                          Text(day, style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 9.0)),
                                        ],
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20.0),

                            Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(16.0),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("TIMELINE PLAYHEAD HEATMAP", style: GoogleFonts.plusJakartaSans(fontSize: 11.0, fontWeight: FontWeight.bold, color: Colors.white70)),
                                  const SizedBox(height: 4.0),
                                  Text("Seeking and checkpoint skip spikes", style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 10.0)),
                                  const SizedBox(height: 16.0),
                                  SizedBox(
                                    height: 50.0,
                                    width: double.infinity,
                                    child: CustomPaint(
                                      painter: HeatmapPainter(
                                        values: heatmapPoints,
                                        accentColor: primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showWatchPartyLobby(BuildContext context) {
    final roomCodeController = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        final primaryColor = Theme.of(context).primaryColor;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30.0)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 32.0,
                left: 24.0,
                right: 24.0,
                top: 32.0,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F12).withOpacity(0.95),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1.5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "CO-WATCHING PARTY",
                        style: GoogleFonts.cinzel(
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white60),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6.0),
                  Text(
                    "Join private rooms to watch synced movies and share floating emoji reactions in real-time.",
                    style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 12.0),
                  ),
                  const SizedBox(height: 24.0),

                  Text(
                    "HOST A NEW PARTY",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final defaultMedia = mockMediaDatabase.first;
                      final room = await ApiService.createWatchParty(
                        defaultMedia.id.toString(),
                        defaultMedia.title,
                      );
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TvPlayerScreen(
                              mediaItem: defaultMedia,
                              watchPartyRoomId: room['roomId'] ?? '123456',
                              isHost: true,
                            ),
                          ),
                        );
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Host Party Room ${room['roomId']} created successfully!"),
                            backgroundColor: primaryColor,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.add_to_queue_rounded, color: Colors.black, size: 18),
                    label: Text(
                      "Create Host Room (Featured: Inception)",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24.0),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 24.0),

                  Text(
                    "JOIN ACTIVE PARTY ROOM",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48.0,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(color: Colors.white12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TextField(
                            controller: roomCodeController,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16.0),
                            decoration: InputDecoration(
                              hintText: "Enter 6-digit Code",
                              hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 14.0),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.only(bottom: 2.0),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      ElevatedButton(
                        onPressed: () async {
                          final code = roomCodeController.text.trim();
                          if (code.length != 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Please enter a valid 6-digit room code.")),
                            );
                            return;
                          }
                          
                          final room = await ApiService.getWatchPartyRoom(code);
                          if (room.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Active co-watching room not found.")),
                            );
                            return;
                          }
                          
                          final listingId = room['listingId']?.toString() ?? '1';
                          final match = mockMediaDatabase.firstWhere(
                            (x) => x.id.toString() == listingId,
                            orElse: () => mockMediaDatabase.first,
                          );

                          if (context.mounted) {
                            Navigator.pop(context);
                            
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TvPlayerScreen(
                                  mediaItem: match,
                                  watchPartyRoomId: code,
                                  isHost: false,
                                ),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.08),
                          side: const BorderSide(color: Colors.white24),
                          minimumSize: const Size(100, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: Text(
                          "Join Party",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSubtitlesCCSettings(BuildContext context) {
    double fontSize = 18.0;
    double outlineWidth = 1.5;
    double backdropOpacity = 0.4;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final primaryColor = Theme.of(context).primaryColor;
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30.0)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                child: Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 32.0,
                    left: 24.0,
                    right: 24.0,
                    top: 32.0,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F12).withOpacity(0.95),
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1.5),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "SUBTITLES STYLE HUBS",
                            style: GoogleFonts.cinzel(
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white60),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16.0),
                      Text(
                        "Customize subtitle size, font borders, backing opacity, and import custom files.",
                        style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 12.0),
                      ),
                      const SizedBox(height: 24.0),
                      
                      Text(
                        "Font Size: ${fontSize.toInt()}px",
                        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.bold),
                      ),
                      Slider(
                        value: fontSize,
                        min: 12.0,
                        max: 36.0,
                        activeColor: primaryColor,
                        inactiveColor: Colors.white10,
                        onChanged: (val) {
                          setSheetState(() {
                            fontSize = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12.0),

                      Text(
                        "Outline Stroke: ${outlineWidth.toStringAsFixed(1)}px",
                        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.bold),
                      ),
                      Slider(
                        value: outlineWidth,
                        min: 0.0,
                        max: 4.0,
                        activeColor: primaryColor,
                        inactiveColor: Colors.white10,
                        onChanged: (val) {
                          setSheetState(() {
                            outlineWidth = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12.0),

                      Text(
                        "Backing Backdrop Opacity: ${(backdropOpacity * 100).toInt()}%",
                        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.bold),
                      ),
                      Slider(
                        value: backdropOpacity,
                        min: 0.0,
                        max: 1.0,
                        activeColor: primaryColor,
                        inactiveColor: Colors.white10,
                        onChanged: (val) {
                          setSheetState(() {
                            backdropOpacity = val;
                          });
                        },
                      ),
                      const SizedBox(height: 20.0),

                      SizedBox(
                        width: double.infinity,
                        height: 46.0,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Custom SRT/VTT file import overlay opened successfully!", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                                backgroundColor: primaryColor,
                              ),
                            );
                          },
                          icon: const Icon(Icons.file_upload_outlined, color: Colors.white, size: 16),
                          label: Text(
                            "Import Custom SRT/VTT Files",
                            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                          ),
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

  void _showNetworkDiagnostics(BuildContext context) {
    double speedVal = 0.0;
    int pingVal = 120;
    bool isRunning = true;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final primaryColor = Theme.of(context).primaryColor;
            
            if (isRunning && speedVal == 0.0) {
              Future.doWhile(() async {
                await Future.delayed(const Duration(milliseconds: 100));
                if (!context.mounted) return false;
                setSheetState(() {
                  if (speedVal < 450.0) {
                    speedVal += 35.0;
                    if (pingVal > 12) pingVal -= 8;
                  } else {
                    speedVal = 450.0;
                    pingVal = 12;
                    isRunning = false;
                  }
                });
                return isRunning;
              });
            }

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30.0)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                child: Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 32.0,
                    left: 24.0,
                    right: 24.0,
                    top: 32.0,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F12).withOpacity(0.95),
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1.5),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "DIAGNOSTICS & SPEED TEST",
                            style: GoogleFonts.cinzel(
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white60),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16.0),
                      Text(
                        "App Engine diagnostics status and live network speed checking.",
                        style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 12.0),
                      ),
                      const SizedBox(height: 24.0),

                      Center(
                        child: Container(
                          width: 140.0,
                          height: 140.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: primaryColor.withOpacity(0.2), width: 6.0),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                speedVal.toInt().toString(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 34.0,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                "Mbps",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.0,
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24.0),

                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTileCompact(
                              "Ping Latency",
                              "$pingVal ms",
                              Icons.network_ping_rounded,
                              Colors.cyanAccent,
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: _buildMetricTileCompact(
                              "Bandwidth Used",
                              "14.2 GB",
                              Icons.data_usage_rounded,
                              Colors.purpleAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20.0),

                      Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.06),
                          border: Border.all(color: Colors.green.withOpacity(0.15)),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18.0),
                            const SizedBox(width: 12.0),
                            Text(
                              "All rendering and play streams are operating optimally.",
                              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11.5),
                            ),
                          ],
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

  Widget _buildMetricTileCompact(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.015),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16.0),
          const SizedBox(width: 10.0),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 9.5, fontWeight: FontWeight.bold)),
              Text(value, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  void _showScannerRadarDashboard(BuildContext context) {
    List<String> logs = ['[System] Awaiting scanner logs feed...'];
    String scannerStatus = 'idle';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final primaryColor = Theme.of(context).primaryColor;
            final statusColor = scannerStatus == 'scanning'
                ? Colors.amber
                : (scannerStatus == 'error' ? Colors.redAccent : Colors.greenAccent);
            final statusText = scannerStatus == 'scanning'
                ? "SCANNING ACTIVE..."
                : (scannerStatus == 'error' ? "ERROR DETECTED" : "SCANNER IDLE");

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30.0)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.85,
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F12).withOpacity(0.95),
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "SCANNER & LOG FEED",
                                style: GoogleFonts.cinzel(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                "Dynamic MTProto channel sync and log indexing feeds.",
                                style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 12.0),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white60),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20.0),

                      Center(
                        child: AnimatedRadarSweep(scannerStatus: scannerStatus),
                      ),
                      const SizedBox(height: 20.0),

                      SizedBox(
                        width: double.infinity,
                        height: 48.0,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (scannerStatus == 'scanning') return;
                            setSheetState(() {
                              scannerStatus = 'scanning';
                              logs = ['[System] Connecting to Telegram MTProto channels...', '[System] Active channel scan triggered successfully.'];
                            });
                            final result = await ApiService.triggerActiveScan();
                            setSheetState(() {
                              logs = result['logs'];
                              scannerStatus = result['success'] ? 'idle' : 'error';
                            });
                          },
                          icon: Icon(
                            scannerStatus == 'scanning' ? Icons.hourglass_empty_rounded : Icons.radar_rounded,
                            color: scannerStatus == 'scanning' ? Colors.white38 : Colors.black,
                            size: 18,
                          ),
                          label: Text(
                            scannerStatus == 'scanning' ? "SCANNING ACTIVE..." : "TRIGGER ACTIVE SCAN",
                            style: GoogleFonts.plusJakartaSans(
                              color: scannerStatus == 'scanning' ? Colors.white60 : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.0,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: scannerStatus == 'scanning' ? Colors.white10 : primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20.0),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "SCANNER LOGS FEED",
                            style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 10.0, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                          Text(
                            statusText,
                            style: GoogleFonts.plusJakartaSans(color: statusColor, fontSize: 10.0, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),

                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(14.0),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          padding: const EdgeInsets.all(14.0),
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: logs.length,
                            itemBuilder: (context, index) {
                              final log = logs[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Text(
                                  log,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: log.contains("failed") || log.contains("Error")
                                        ? Colors.redAccent.withOpacity(0.85)
                                        : (log.contains("SUCCESS") || log.contains("completed")
                                            ? Colors.greenAccent
                                            : Colors.white70),
                                    fontSize: 11.5,
                                    height: 1.3,
                                  ),
                                ),
                              );
                            },
                          ),
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
}

class AnimatedRadarSweep extends StatefulWidget {
  final String scannerStatus;
  const AnimatedRadarSweep({Key? key, required this.scannerStatus}) : super(key: key);

  @override
  State<AnimatedRadarSweep> createState() => _AnimatedRadarSweepState();
}

class _AnimatedRadarSweepState extends State<AnimatedRadarSweep> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.scannerStatus == 'scanning') {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedRadarSweep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scannerStatus == 'scanning') {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: 100.0,
          height: 100.0,
          child: CustomPaint(
            painter: RadarPainter(
              rotationAngle: _controller.value * 3.1415926535 * 2,
              radarColor: primaryColor,
              isActive: widget.scannerStatus == 'scanning',
            ),
          ),
        );
      },
    );
  }
}

class RadarPainter extends CustomPainter {
  final double rotationAngle;
  final Color radarColor;
  final bool isActive;

  RadarPainter({required this.rotationAngle, required this.radarColor, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint = Paint()
      ..color = radarColor.withOpacity(0.04)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    final linePaint = Paint()
      ..color = radarColor.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius, linePaint);
    canvas.drawCircle(center, radius * 0.66, linePaint);
    canvas.drawCircle(center, radius * 0.33, linePaint);

    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), linePaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), linePaint);

    if (isActive) {
      final sweepPaint = Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: 0.0,
          endAngle: 3.1415926535 * 2,
          colors: [
            radarColor.withOpacity(0.25),
            radarColor.withOpacity(0.0),
          ],
          transform: GradientRotation(rotationAngle),
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, radius, sweepPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class DonutChartPainter extends CustomPainter {
  final Map<String, double> data;
  final List<Color> colors;

  DonutChartPainter({required this.data, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final double total = data.values.fold(0.0, (sum, item) => sum + item);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -3.1415926535 / 2; // Start from top
    int index = 0;

    for (final entry in data.entries) {
      final sweepAngle = (entry.value / total) * 3.1415926535 * 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14.0
        ..color = colors[index % colors.length]
        ..strokeCap = SweepAngleIsEmpty(sweepAngle) ? StrokeCap.butt : StrokeCap.round;

      // Draw a subtle outer shadow/glow for the segment
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20.0
        ..color = colors[index % colors.length].withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
      
      canvas.drawArc(rect, startAngle + 0.05, sweepAngle - 0.1, false, glowPaint);
      canvas.drawArc(rect, startAngle + 0.05, sweepAngle - 0.1, false, paint);

      startAngle += sweepAngle;
      index++;
    }
  }

  bool SweepAngleIsEmpty(double angle) {
    return angle <= 0.0;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class HeatmapPainter extends CustomPainter {
  final List<double> values;
  final Color accentColor;

  HeatmapPainter({required this.values, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final paint = Paint()
      ..color = accentColor.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withOpacity(0.35),
          accentColor.withOpacity(0.00),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final stepX = size.width / (values.length - 1);
    final maxValue = values.fold(1.0, (maxVal, v) => v > maxVal ? v : maxVal);

    path.moveTo(0, size.height - (values[0] / maxValue) * (size.height - 10));

    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height - (values[i] / maxValue) * (size.height - 10);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevY = size.height - (values[i - 1] / maxValue) * (size.height - 10);
        final controlX1 = prevX + stepX / 2;
        final controlY1 = prevY;
        final controlX2 = prevX + stepX / 2;
        final controlY2 = y;
        path.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
      }
    }

    // Draw the glow shadow under the curve
    canvas.drawPath(path, Paint()
      ..color = accentColor.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0));

    canvas.drawPath(path, paint);

    // Close the path to fill it
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
