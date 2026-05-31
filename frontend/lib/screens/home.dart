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
import 'tv_home.dart';
import 'profile_select.dart';
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

  // Dynamic cloud live sync rows
  List<MediaItem> _dynamicContinueWatching = [];
  List<MediaItem> _dynamicMovies = [];
  List<MediaItem> _dynamicTvShows = [];
  List<MediaItem> _dynamicAnime = [];

  @override
  void initState() {
    super.initState();
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
    super.dispose();
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
    if (!_isKidsProfileActive) return true; // Direct pass if not Kids Mode
    
    final prefs = await SharedPreferences.getInstance();
    final hasParentPin = prefs.getBool('profile_has_pin_Director') ?? true;
    final parentPin = prefs.getString('profile_pin_Director') ?? '1234';
    
    if (!hasParentPin) return true; // Direct pass if no parent PIN set

    final controller = TextEditingController();
    bool isCorrect = false;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
              child: AlertDialog(
                backgroundColor: const Color(0xFF0F0F12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  side: const BorderSide(color: Colors.orangeAccent, width: 1.5),
                ),
                title: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.security_rounded, color: Colors.orangeAccent, size: 36.0),
                      const SizedBox(height: 12.0),
                      Text(
                         "PARENTAL CONTROL GATE",
                         style: GoogleFonts.cinzel(
                           color: Colors.white,
                           fontWeight: FontWeight.bold,
                           fontSize: 16.0,
                           letterSpacing: 1.0,
                         ),
                      ),
                    ],
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Please enter the Director (Parent) profile 4-digit PIN to authorize this action.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13.0, height: 1.4),
                    ),
                    const SizedBox(height: 20.0),
                    Container(
                      width: 160.0,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(color: Colors.white24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: true,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 20.0, fontWeight: FontWeight.bold, letterSpacing: 8.0),
                        decoration: const InputDecoration(
                          counterText: "",
                          border: InputBorder.none,
                          hintText: "••••",
                          hintStyle: TextStyle(color: Colors.white24, letterSpacing: 4.0),
                        ),
                        onChanged: (val) {
                          if (val.length == 4) {
                            if (val == parentPin) {
                              isCorrect = true;
                              Navigator.pop(context);
                            } else {
                              controller.clear();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Incorrect Parent PIN. Try again!"),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      isCorrect = false;
                      Navigator.pop(context);
                    },
                    child: Text(
                      "CANCEL",
                      style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
    return isCorrect;
  }

  Future<void> _showServerSettingsBottomSheet(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final bool isTelegramLoggedIn = prefs.getBool('telegram_logged_in') ?? false;

    final TextEditingController urlController = TextEditingController(text: ApiService.baseUrl);
    final TextEditingController m3uController = TextEditingController(text: prefs.getString('iptv_m3u_url') ?? 'https://cinegram.io/playlist.m3u');
    final TextEditingController epgController = TextEditingController(text: prefs.getString('iptv_epg_url') ?? 'http://cinegram.io/epg.xml');
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
                            Text(
                              "SETTINGS",
                              style: GoogleFonts.cinzel(
                                fontSize: 24.0,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white60),
                              onPressed: () => Navigator.pop(context),
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
                                          Row(
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
                                              Column(
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
                                                        ? (connectedPhone.isNotEmpty ? connectedPhone : "Active Gateway Session")
                                                        : "Guest Explorer Mode",
                                                    style: GoogleFonts.plusJakartaSans(
                                                      color: Colors.white,
                                                      fontSize: 14.0,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
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
                                                  );
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
                                const SizedBox(height: 24.0),

                                // CATEGORY 2: DYNAMIC PROFILES & SECURITY
                                buildCategoryHeader("DYNAMIC PROFILES & SECURITY", Icons.people_outline_rounded, primaryColor),
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
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "CURRENT ACTIVE PROFILE",
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 10.0,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white38,
                                                ),
                                              ),
                                              const SizedBox(height: 4.0),
                                              Row(
                                                children: [
                                                  Icon(Icons.account_circle, color: primaryColor, size: 18),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    ApiService.activeProfile ?? "Profile 1",
                                                    style: GoogleFonts.plusJakartaSans(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14.0,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: () async {
                                              Navigator.pop(context);
                                              final authorized = await _showParentalGate(context);
                                              if (authorized) {
                                                Navigator.of(context).pushAndRemoveUntil(
                                                  MaterialPageRoute(builder: (context) => const ProfileSelectScreen()),
                                                  (route) => false,
                                                );
                                              }
                                            },
                                            icon: const Icon(Icons.swap_horiz, color: Colors.black, size: 16),
                                            label: Text(
                                              "Switch Profile",
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
                                        ],
                                      ),
                                      const SizedBox(height: 12.0),
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

                                      SwitchListTile(
                                        contentPadding: EdgeInsets.zero,
                                        activeColor: primaryColor,
                                        title: Text(
                                          "Multi-Profile Mode",
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.0,
                                          ),
                                        ),
                                        subtitle: Text(
                                          "Enable multiple profile choices on app startup. If disabled, defaults to primary Profile directly.",
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white38,
                                            fontSize: 11.0,
                                            height: 1.3,
                                          ),
                                        ),
                                        value: multiProfileEnabled,
                                        onChanged: (val) {
                                          setSheetState(() {
                                            multiProfileEnabled = val;
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 16.0),
                                      const Divider(color: Colors.white12, height: 1.0),
                                      const SizedBox(height: 16.0),

                                      Text(
                                        "CUSTOM PROFILE SLOTS",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10.0,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 12.0),

                                      Column(
                                        children: ['Profile 1', 'Profile 2', 'Profile 3', 'Profile 4'].map((role) {
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 12.0),
                                            padding: const EdgeInsets.all(12.0),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.01),
                                              borderRadius: BorderRadius.circular(14.0),
                                              border: Border.all(color: Colors.white.withOpacity(0.04)),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 44.0,
                                                  height: 44.0,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: primaryColor.withOpacity(0.4), width: 1.5),
                                                    image: DecorationImage(
                                                      image: CachedNetworkImageProvider(
                                                        avatarControllers[role]!.text.trim().isNotEmpty
                                                            ? avatarControllers[role]!.text.trim()
                                                            : (role == 'Profile 1'
                                                                ? 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=150'
                                                                : role == 'Profile 2'
                                                                    ? 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?q=80&w=150'
                                                                    : role == 'Profile 3'
                                                                        ? 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=150'
                                                                        : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=150'),
                                                      ),
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12.0),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Container(
                                                        height: 32.0,
                                                        decoration: BoxDecoration(
                                                          color: Colors.white.withOpacity(0.03),
                                                          borderRadius: BorderRadius.circular(8.0),
                                                        ),
                                                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                                        child: TextField(
                                                          controller: nameControllers[role],
                                                          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13.0),
                                                          decoration: InputDecoration(
                                                            hintText: "Profile Name ($role)",
                                                            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 12.0),
                                                            border: InputBorder.none,
                                                            contentPadding: const EdgeInsets.only(bottom: 14.0),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6.0),
                                                      Container(
                                                        height: 32.0,
                                                        decoration: BoxDecoration(
                                                          color: Colors.white.withOpacity(0.03),
                                                          borderRadius: BorderRadius.circular(8.0),
                                                        ),
                                                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                                        child: TextField(
                                                          controller: avatarControllers[role],
                                                          style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 11.5),
                                                          onChanged: (val) {
                                                            setSheetState(() {});
                                                          },
                                                          decoration: InputDecoration(
                                                            hintText: "Avatar URL for $role",
                                                            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 11.0),
                                                            border: InputBorder.none,
                                                            contentPadding: const EdgeInsets.only(bottom: 15.0),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8.0),
                                                      Row(
                                                        children: [
                                                          Text(
                                                            "KIDS:",
                                                            style: GoogleFonts.plusJakartaSans(
                                                              color: Colors.white38,
                                                              fontSize: 9.5,
                                                              fontWeight: FontWeight.bold,
                                                              letterSpacing: 0.5,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 4.0),
                                                          SizedBox(
                                                            height: 18.0,
                                                            width: 28.0,
                                                            child: Switch(
                                                              value: isKidsMap[role] ?? false,
                                                              activeColor: Colors.orangeAccent,
                                                              onChanged: (val) {
                                                                setSheetState(() {
                                                                  isKidsMap[role] = val;
                                                                });
                                                              },
                                                            ),
                                                          ),
                                                          const SizedBox(width: 12.0),
                                                          Text(
                                                            "LOCK PIN:",
                                                            style: GoogleFonts.plusJakartaSans(
                                                              color: Colors.white38,
                                                              fontSize: 9.5,
                                                              fontWeight: FontWeight.bold,
                                                              letterSpacing: 0.5,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 4.0),
                                                          SizedBox(
                                                            height: 18.0,
                                                            width: 28.0,
                                                            child: Switch(
                                                              value: hasPinMap[role] ?? false,
                                                              activeColor: primaryColor,
                                                              onChanged: (val) {
                                                                setSheetState(() {
                                                                  hasPinMap[role] = val;
                                                                });
                                                              },
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8.0),
                                                          if (hasPinMap[role] == true)
                                                            Expanded(
                                                              child: Container(
                                                                height: 24.0,
                                                                decoration: BoxDecoration(
                                                                  color: Colors.white.withOpacity(0.04),
                                                                  borderRadius: BorderRadius.circular(6.0),
                                                                  border: Border.all(color: Colors.white12),
                                                                ),
                                                                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                                                child: TextField(
                                                                  controller: pinControllers[role],
                                                                  keyboardType: TextInputType.number,
                                                                  maxLength: 4,
                                                                  obscureText: true,
                                                                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11.0),
                                                                  decoration: const InputDecoration(
                                                                    hintText: "PIN (4-digits)",
                                                                    counterText: "",
                                                                    border: InputBorder.none,
                                                                    contentPadding: EdgeInsets.only(bottom: 15.0),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24.0),

                                // CATEGORY 3: TV SIMULATOR & DASHBOARD
                                buildCategoryHeader("TV SIMULATOR & DASHBOARD", Icons.tv_rounded, primaryColor),
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
                                        "Experience the premium, D-pad remote optimized widescreen dashboard design scaled dynamically for mobile handsets.",
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white60,
                                          fontSize: 12.0,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 16.0),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          Navigator.push(
                                            context,
                                            PageRouteBuilder(
                                              pageBuilder: (context, animation, secondaryAnimation) => const TvHomeScreen(),
                                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                return FadeTransition(opacity: animation, child: child);
                                              },
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.tv_rounded, color: Colors.black, size: 18),
                                        label: Text(
                                          "Launch Widescreen TV Simulator",
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                            fontSize: 12.0,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          minimumSize: const Size(double.infinity, 44),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10.0),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24.0),

                                // CATEGORY 4: VISUAL ACCENT THEME
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
                                const SizedBox(height: 24.0),

                                // CATEGORY 5: VIDEO PLAYBACK PREFERENCES
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
                                const SizedBox(height: 24.0),

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
                                const SizedBox(height: 24.0),

                                // CATEGORY 7: IPTV STREAM CONFIG
                                buildCategoryHeader("IPTV & M3U STREAM SETUP", Icons.live_tv_rounded, primaryColor),
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
                                        "Enter your custom M3U playlist URL and Electronic Program Guide (EPG) XML to map Live Channels inside the TV Simulator.",
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white60,
                                          fontSize: 12.0,
                                          height: 1.4,
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
                                          controller: m3uController,
                                          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14.0),
                                          decoration: InputDecoration(
                                            labelText: "M3U Playlist URL",
                                            labelStyle: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 12.0),
                                            hintText: "https://your-domain.com/playlist.m3u",
                                            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 13.0),
                                            border: InputBorder.none,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12.0),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.04),
                                          borderRadius: BorderRadius.circular(14.0),
                                          border: Border.all(color: Colors.white12),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                        child: TextField(
                                          controller: epgController,
                                          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14.0),
                                          decoration: InputDecoration(
                                            labelText: "EPG XML URL (Optional)",
                                            labelStyle: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 12.0),
                                            hintText: "http://your-domain.com/epg.xml",
                                            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 13.0),
                                            border: InputBorder.none,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 28.0),

                                // Action Buttons Row (Test Connection, Save)
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
                                          await prefs.setString('iptv_m3u_url', m3uController.text.trim());
                                          await prefs.setString('iptv_epg_url', epgController.text.trim());
                                          
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
                                                      : "Saved custom URL and IPTV URLs, but backend is offline.",
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
