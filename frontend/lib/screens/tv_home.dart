import 'dart:ui';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../theme/cinegram_theme.dart';
import '../models/media_item.dart';
import '../widgets/glassmorphic_card.dart';
import '../services/api_service.dart';
import 'details.dart';
import 'profile_select.dart';
import 'tv_iptv.dart';
import 'tv_player.dart';
import '../services/voice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// REUSABLE PREMIUM D-PAD FOCUSABLE WIDGET FOR 10-FOOT TV UI
class TvFocusable extends StatefulWidget {
  final Widget child;
  final FocusNode? focusNode;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onFocusChanged;
  final double scaleFactor;
  final bool enableGlow;
  final BorderRadius borderRadius;

  const TvFocusable({
    Key? key,
    required this.child,
    this.focusNode,
    this.onTap,
    this.onFocusChanged,
    this.scaleFactor = 1.06,
    this.enableGlow = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(16.0)),
  }) : super(key: key);

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  late FocusNode _focusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_handleFocusChange);
    }
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
      if (widget.onFocusChanged != null) {
        widget.onFocusChanged!(_focusNode.hasFocus);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _hasFocus;

    final Color primaryColor = Theme.of(context).primaryColor;
    final Color activeBorderColor = primaryColor.withOpacity(0.95);
    final Color inactiveBorderColor = Colors.white.withOpacity(0.08);
    final Color activeGlowColor = primaryColor.withOpacity(0.35);

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        // Handle physical D-pad Select or Keyboard Enter keys
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          widget.onTap?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: active ? widget.scaleFactor : 1.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              boxShadow: widget.enableGlow && active
                  ? [
                      BoxShadow(
                        color: activeGlowColor,
                        blurRadius: 30.0,
                        spreadRadius: 3.0,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 15.0,
                        offset: const Offset(0, 5),
                      )
                    ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: widget.borderRadius,
                border: Border.all(
                  color: active ? activeBorderColor : inactiveBorderColor,
                  width: active ? 3.0 : 1.0,
                ),
              ),
              child: ClipRRect(
                borderRadius: widget.borderRadius,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// HORIZONTAL SCROLLABLE ROW THAT AUTO-SCROLLS WHEN A CARD RECEIVES D-PAD FOCUS
class TvRow extends StatefulWidget {
  final String title;
  final List<MediaItem> items;
  final bool isLandscape;
  final ValueChanged<MediaItem> onCardFocused;
  final ValueChanged<MediaItem> onCardTap;

  const TvRow({
    Key? key,
    required this.title,
    required this.items,
    this.isLandscape = false,
    required this.onCardFocused,
    required this.onCardTap,
  }) : super(key: key);

  @override
  State<TvRow> createState() => _TvRowState();
}

class _TvRowState extends State<TvRow> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    
    final double cardWidth = widget.isLandscape ? 320.0 : 180.0;
    final double cardMargin = 16.0;
    final double itemSize = cardWidth + cardMargin;
    
    // We animate scroll controller so focused card scrolls smoothly into view
    final double targetOffset = index * itemSize;
    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double clampedOffset = targetOffset.clamp(0.0, maxScroll);
    
    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double rowHeight = widget.isLandscape ? 210.0 : 310.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 8.0),
          child: Text(
            widget.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20.0,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
        SizedBox(
          height: rowHeight,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 12.0),
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return Container(
                margin: const EdgeInsets.only(right: 16.0),
                width: widget.isLandscape ? 320.0 : 180.0,
                child: TvFocusable(
                  onFocusChanged: (hasFocus) {
                    if (hasFocus) {
                      widget.onCardFocused(item);
                      _scrollToIndex(index);
                    }
                  },
                  onTap: () => widget.onCardTap(item),
                  child: widget.isLandscape
                      ? _buildLandscapeCard(item)
                      : _buildPortraitCard(item),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16.0),
      ],
    );
  }

  Widget _buildLandscapeCard(MediaItem item) {
    return Stack(
      children: [
        Positioned.fill(
          child: CachedNetworkImage(
            imageUrl: item.backdropUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: const Color(0xFF121215)),
            errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.95),
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 16.0,
          left: 16.0,
          right: 16.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2.0),
              Text(
                item.type == 'TV Show' ? 'S2:E3 • Remaining' : 'Movie • Resume',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.65),
              border: Border.all(color: Colors.white30),
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24.0),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 4.5,
            color: Colors.white.withOpacity(0.2),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: item.progress ?? 0.0,
              child: Container(
                height: 4.5,
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
    );
  }

  Widget _buildPortraitCard(MediaItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: item.posterUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: const Color(0xFF121215)),
                  errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
                ),
              ),
              Positioned(
                top: 10.0,
                right: 10.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      color: Colors.black.withOpacity(0.6),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 13.0),
                          const SizedBox(width: 3.0),
                          Text(
                            item.rating.toString(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.0,
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
        Padding(
          padding: const EdgeInsets.fromLTRB(8.0, 10.0, 8.0, 0.0),
          child: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8.0, 3.0, 8.0, 0.0),
          child: Row(
            children: [
              Text(
                item.year,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(width: 8.0),
              Container(
                width: 3.5,
                height: 3.5,
                decoration: const BoxDecoration(
                  color: Colors.white30,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8.0),
              Text(
                item.type,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  color: const Color(0xFFFFD700).withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// MAIN PREMIUM WIDESCREEN TV-OPTIMIZED HOMEPAGE
class TvHomeScreen extends StatefulWidget {
  const TvHomeScreen({Key? key}) : super(key: key);

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen> {
  // Navigation State
  String _activeTab = 'HOME'; // 'HOME' | 'LIVE TV' | 'SEARCH' | 'VAULT' | 'SETTINGS'
  
  // Media State
  late MediaItem _backdropMediaItem;
  final Set<String> _vaultedItemIds = {'m1', 't1'}; // Preloaded bookmarks in the Vault
  
  // Focus Management
  final FocusNode _menuHomeFocusNode = FocusNode();
  final FocusNode _menuLiveFocusNode = FocusNode();
  final FocusNode _menuSearchFocusNode = FocusNode();
  final FocusNode _menuVaultFocusNode = FocusNode();
  final FocusNode _menuSettingsFocusNode = FocusNode();
  
  final FocusNode _btnPlayFocusNode = FocusNode();
  final FocusNode _btnVaultFocusNode = FocusNode();
  
  // Scroll Management
  final ScrollController _mainScrollController = ScrollController();
  
  // Search state
  final TextEditingController _searchController = TextEditingController();
  List<MediaItem> _searchResults = [];
  final List<String> _trendingKeywords = [
    'Aetherius', 'Neon', 'Cyberpunk', 'Succession', 'Severance', 'Sci-Fi'
  ];

  // Settings active item details
  String _focusedSettingKey = 'profile';

  // Server URL Settings state
  final TextEditingController _serverUrlController = TextEditingController();
  final FocusNode _serverUrlFocusNode = FocusNode();
  final FocusNode _serverTestFocusNode = FocusNode();
  final FocusNode _serverSaveFocusNode = FocusNode();
  bool? _serverConnectionStatus;
  bool _serverCheckingStatus = false;

  // IPTV Playlist configuration state
  final TextEditingController _iptvM3uController = TextEditingController();
  final TextEditingController _iptvEpgController = TextEditingController();
  final FocusNode _iptvM3uFocusNode = FocusNode();
  final FocusNode _iptvEpgFocusNode = FocusNode();
  final FocusNode _iptvSaveFocusNode = FocusNode();
  final FocusNode _iptvReloadFocusNode = FocusNode();
  bool _iptvReloading = false;
  int _iptvParsedCount = 12;

  // Scanner state
  String _scannerStatus = 'idle'; // 'idle' | 'scanning' | 'error'
  List<String> _scannerLogs = [];
  List<dynamic> _unresolvedListings = [];
  dynamic _selectedUnresolvedListing;
  final TextEditingController _overrideTmdbController = TextEditingController();
  final FocusNode _btnScanFocusNode = FocusNode();
  final FocusNode _overrideInputFocusNode = FocusNode();
  final FocusNode _btnOverrideFocusNode = FocusNode();

  // Remote helper overlay toggle
  bool _showRemoteHelper = true;
  bool _isKidsProfileActive = false;

  // Supabase dynamic live sync categories
  List<MediaItem> _dynamicContinueWatching = [];
  List<MediaItem> _dynamicMovies = [];
  List<MediaItem> _dynamicTvShows = [];
  List<MediaItem> _dynamicAnime = [];
  List<MediaItem> _dynamicBookmarks = [];
  bool _isLoadingCloudData = false;

  @override
  void initState() {
    super.initState();
    _backdropMediaItem = mockMediaDatabase.firstWhere((item) => item.category == 'Trending');
    _searchResults = List.from(mockMediaDatabase);
    _serverUrlController.text = ApiService.baseUrl;
    
    // Seed initial row lists with static mocks for immediate display
    _dynamicContinueWatching = mockMediaDatabase.where((item) => item.progress != null).toList();
    _dynamicMovies = mockMediaDatabase.where((item) => item.type == 'Movie').toList();
    _dynamicTvShows = mockMediaDatabase.where((item) => item.type == 'TV Show').toList();
    _dynamicAnime = mockMediaDatabase.where((item) => item.type == 'Anime').toList();
    _dynamicBookmarks = mockMediaDatabase.where((item) => _vaultedItemIds.contains(item.id)).toList();

    _checkServerConnection(ApiService.baseUrl);
    _loadUnresolvedListings();
    _loadCloudData();

    // Initialize IPTV configuration values from SharedPreferences
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          _iptvM3uController.text = prefs.getString('iptv_m3u_url') ?? 'https://cinegram.io/playlist.m3u';
          _iptvEpgController.text = prefs.getString('iptv_epg_url') ?? 'http://cinegram.io/epg.xml';
          
          // Load active profile kids mode status
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
          _isKidsProfileActive = prefs.getBool('profile_is_kids_$roleKey') ?? (roleKey == 'Viewer');
        });
      }
    });
    
    // Auto focus the Home button in the top menu on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _menuHomeFocusNode.requestFocus();
    });
  }

  Future<void> _loadCloudData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingCloudData = true;
    });

    try {
      final continueWatching = await ApiService.fetchSyncedContinueWatchingItems();
      final bookmarked = await ApiService.fetchSyncedBookmarkedItems();
      final allListings = await ApiService.fetchMediaItems();

      if (mounted) {
        setState(() {
          if (continueWatching.isNotEmpty) {
            _dynamicContinueWatching = continueWatching;
          }
          if (bookmarked.isNotEmpty) {
            _dynamicBookmarks = bookmarked;
          }
          if (allListings.isNotEmpty) {
            final fetchedMovies = allListings.where((item) => item.type == 'Movie').toList();
            final fetchedTv = allListings.where((item) => item.type == 'TV Show').toList();
            final fetchedAnime = allListings.where((item) => item.type == 'Anime').toList();
            
            if (fetchedMovies.isNotEmpty) _dynamicMovies = fetchedMovies;
            if (fetchedTv.isNotEmpty) _dynamicTvShows = fetchedTv;
            if (fetchedAnime.isNotEmpty) _dynamicAnime = fetchedAnime;
          }
          _isLoadingCloudData = false;
        });
      }
    } catch (e) {
      developer.log("Error loading Supabase cloud media data", error: e, name: "TvHomeScreen");
      if (mounted) {
        setState(() {
          _isLoadingCloudData = false;
        });
      }
    }
  }

  Future<void> _loadUnresolvedListings() async {
    final items = await ApiService.fetchUnresolvedListings();
    if (!mounted) return;
    setState(() {
      _unresolvedListings = items;
      if (_selectedUnresolvedListing != null && !items.any((x) => x['id'] == _selectedUnresolvedListing['id'])) {
        _selectedUnresolvedListing = null;
        _overrideTmdbController.clear();
      }
    });
  }

  @override
  void dispose() {
    _menuHomeFocusNode.dispose();
    _menuLiveFocusNode.dispose();
    _menuSearchFocusNode.dispose();
    _menuVaultFocusNode.dispose();
    _menuSettingsFocusNode.dispose();
    _btnPlayFocusNode.dispose();
    _btnVaultFocusNode.dispose();
    _mainScrollController.dispose();
    _searchController.dispose();
    _serverUrlController.dispose();
    _serverUrlFocusNode.dispose();
    _serverTestFocusNode.dispose();
    _serverSaveFocusNode.dispose();
    _overrideTmdbController.dispose();
    _btnScanFocusNode.dispose();
    _overrideInputFocusNode.dispose();
    _btnOverrideFocusNode.dispose();
    
    _iptvM3uController.dispose();
    _iptvEpgController.dispose();
    _iptvM3uFocusNode.dispose();
    _iptvEpgFocusNode.dispose();
    _iptvSaveFocusNode.dispose();
    _iptvReloadFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkServerConnection(String url) async {
    if (!mounted) return;
    setState(() {
      _serverCheckingStatus = true;
    });
    final isConnected = await ApiService.testConnection(url);
    if (!mounted) return;
    setState(() {
      _serverConnectionStatus = isConnected;
      _serverCheckingStatus = false;
    });
  }

  // Vertical scroll assistance on row focusing to keep things clean
  void _scrollToVerticalOffset(double offset) {
    if (!_mainScrollController.hasClients) return;
    _mainScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _onCardFocused(MediaItem item) {
    setState(() {
      _backdropMediaItem = item;
    });
  }

  void _onCardTap(MediaItem item) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => DetailsScreen(mediaItem: item),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _toggleVault(MediaItem item) {
    setState(() {
      if (_vaultedItemIds.contains(item.id)) {
        _vaultedItemIds.remove(item.id);
      } else {
        _vaultedItemIds.add(item.id);
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_vaultedItemIds.contains(item.id) 
            ? "Added '${item.title}' to Premium Vault" 
            : "Removed '${item.title}' from Vault"),
        duration: const Duration(milliseconds: 1500),
        backgroundColor: const Color(0xFF121215),
      ),
    );
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = List.from(mockMediaDatabase);
      });
      return;
    }

    try {
      final items = await ApiService.semanticSearch(query);
      setState(() {
        _searchResults = items;
      });
    } catch (e) {
      // Safe fallback
      setState(() {
        _searchResults = mockMediaDatabase.where((item) =>
          item.title.toLowerCase().contains(query.toLowerCase()) ||
          item.synopsis.toLowerCase().contains(query.toLowerCase()) ||
          item.genres.any((g) => g.toLowerCase().contains(query.toLowerCase()))
        ).toList();
      });
    }
  }

  void _startTvVoiceSearch() {
    final voiceService = VoiceService();
    
    void listener() {
      if (mounted) setState(() {});
    }
    voiceService.addListener(listener);

    voiceService.startListening(
      onResultComplete: (result) {
        voiceService.removeListener(listener);
        if (mounted) {
          setState(() {
            _searchController.text = result;
          });
          _performSearch(result);
        }
      },
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 480.0,
                height: 320.0,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F11).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(32.0),
                  border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.2),
                      blurRadius: 40.0,
                      spreadRadius: 4.0,
                    )
                  ]
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.mic_rounded,
                      color: Theme.of(context).primaryColor,
                      size: 48.0,
                    ),
                    const SizedBox(height: 20.0),
                    Text(
                      "SPEAK NOW",
                      style: GoogleFonts.cinzel(
                        color: Colors.white,
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      "Describe what you want to watch...",
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white30,
                        fontSize: 14.0,
                      ),
                    ),
                    const SizedBox(height: 32.0),
                    
                    // PULSING AUDIO WAVE VISUALIZER
                    AnimatedBuilder(
                      animation: voiceService,
                      builder: (context, child) {
                        final db = voiceService.decibelLevel;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(7, (index) {
                            final factor = (index - 3).abs();
                            final height = 12.0 + (db * (1.0 - factor * 0.2)).clamp(12.0, 90.0);
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              margin: const EdgeInsets.symmetric(horizontal: 6.0),
                              width: 8.0,
                              height: height,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).primaryColor,
                                    const Color(0xFFE50914),
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 28.0),
                    TvFocusable(
                      borderRadius: BorderRadius.circular(20.0),
                      onTap: () {
                        voiceService.stopListening();
                        voiceService.removeListener(listener);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 12.0),
                        color: Colors.white.withOpacity(0.04),
                        child: Text(
                          "CANCEL",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((value) {
      voiceService.stopListening();
      voiceService.removeListener(listener);
    });
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
              filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
              child: AlertDialog(
                backgroundColor: const Color(0xFF0F0F12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  side: const BorderSide(color: Colors.orangeAccent, width: 2.0),
                ),
                title: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.security_rounded, color: Colors.orangeAccent, size: 48.0),
                      const SizedBox(height: 16.0),
                      Text(
                         "PARENTAL CONTROL GATE",
                         style: GoogleFonts.cinzel(
                           color: Colors.white,
                           fontWeight: FontWeight.bold,
                           fontSize: 20.0,
                           letterSpacing: 1.0,
                         ),
                      ),
                    ],
                  ),
                ),
                content: SizedBox(
                  width: 400.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Please enter the Director (Parent) profile 4-digit PIN using your TV remote controller to authorize this action.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 14.0, height: 1.4),
                      ),
                      const SizedBox(height: 24.0),
                      Container(
                        width: 200.0,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(color: Colors.white24, width: 1.5),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          obscureText: true,
                          textAlign: TextAlign.center,
                          autofocus: true,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white, 
                            fontSize: 24.0, 
                            fontWeight: FontWeight.bold, 
                            letterSpacing: 10.0,
                          ),
                          decoration: const InputDecoration(
                            counterText: "",
                            border: InputBorder.none,
                            hintText: "••••",
                            hintStyle: TextStyle(color: Colors.white24, letterSpacing: 5.0),
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
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final continueWatching = _filterKidsContent(_dynamicContinueWatching);
    final movies = _filterKidsContent(_dynamicMovies);
    final tvShows = _filterKidsContent(_dynamicTvShows);
    final anime = _filterKidsContent(_dynamicAnime);

    return Scaffold(
      backgroundColor: const Color(0xFF070708),
      body: FocusScope(
        child: Stack(
          children: [
            // 1. DYNAMIC FULL SCREEN AMBIENT BACKDROP WITH HIGH CONTRAST DARK LENS
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: Container(
                  key: ValueKey<String>(_backdropMediaItem.id + _activeTab),
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(
                        _activeTab == 'HOME' 
                            ? _backdropMediaItem.backdropUrl 
                            : 'https://images.unsplash.com/photo-1478760329108-5c3ed9d495a0?q=80&w=1200'
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            
            // Premium ambient lens tinting overlay gradients
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF070708).withOpacity(0.95), // Left sidebar/text area blackout
                      const Color(0xFF070708).withOpacity(0.6),
                      const Color(0xFF070708).withOpacity(0.85), // Bottom row blending
                    ],
                    stops: const [0.0, 0.45, 1.0],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
            
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black87,
                      Colors.transparent,
                      const Color(0xFF070708),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // 2. MAIN SCROLLABLE CONTENT VIEW
            Positioned.fill(
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A. TOP PREMIUM WIDESCREEN NAVIGATION BAR
                    _buildWidescreenHeader(),
                    
                    // B. TAB VIEWS (HOME, SEARCH, VAULT, SETTINGS)
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _buildActiveTabContent(continueWatching, movies, tvShows, anime, size),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. KEYBOARD NAV INSTRUCTIONS & SHORTCUT TIPS HELPER OVERLAY (Togglable)
            if (_showRemoteHelper)
              Positioned(
                bottom: 24.0,
                right: 24.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.0),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      width: 320.0,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.35), width: 1.0),
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.tv_rounded, color: Color(0xFFFFD700), size: 20.0),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    "TV SIMULATOR ACTIVE",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12.0,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 16.0),
                                onPressed: () => setState(() => _showRemoteHelper = false),
                              )
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 16.0),
                          _buildShortcutTip("Arrow Keys", "Navigate 10-foot Grid / Menu"),
                          const SizedBox(height: 6.0),
                          _buildShortcutTip("Enter Key", "Select / Watch Media"),
                          const SizedBox(height: 6.0),
                          _buildShortcutTip("Esc / Back", "Exit / Go Back"),
                          const SizedBox(height: 6.0),
                          _buildShortcutTip("Double-Tap Card", "Feature it as Ambient Banner"),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Remote Helper Toggle Button if closed
            if (!_showRemoteHelper)
              Positioned(
                bottom: 24.0,
                right: 24.0,
                child: TvFocusable(
                  borderRadius: BorderRadius.circular(30.0),
                  child: FloatingActionButton(
                    backgroundColor: Colors.black.withOpacity(0.6),
                    onPressed: () => setState(() => _showRemoteHelper = true),
                    child: const Icon(Icons.help_outline_rounded, color: Color(0xFFFFD700)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutTip(String keyName, String actionName) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            border: Border.all(color: Colors.white24, width: 0.8),
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Text(
            keyName,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.0,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFFD700),
            ),
          ),
        ),
        const SizedBox(width: 8.0),
        Expanded(
          child: Text(
            actionName,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.0,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }

  // WIDESCREEN TV LOGO & INTEGRATED TOP MENU ROW
  Widget _buildWidescreenHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, left: 48.0, right: 48.0, bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Elegant Cinema Branding
          Row(
            children: [
              Text(
                "CINE",
                style: GoogleFonts.cinzel(
                  fontSize: 32.0,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 3.0,
                ),
              ),
              Text(
                "GRAM",
                style: GoogleFonts.cinzel(
                  fontSize: 32.0,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFFFD700), // Gold
                  letterSpacing: 3.0,
                ),
              ),
            ],
          ),

          // Central widescreen 10-foot D-pad navigation menu items
          Row(
            children: [
              _buildMenuItem("HOME", _menuHomeFocusNode),
              const SizedBox(width: 16.0),
              _buildMenuItem("LIVE TV", _menuLiveFocusNode),
              const SizedBox(width: 16.0),
              _buildMenuItem("SEARCH", _menuSearchFocusNode),
              const SizedBox(width: 16.0),
              _buildMenuItem("VAULT", _menuVaultFocusNode),
              const SizedBox(width: 16.0),
              _buildMenuItem("SETTINGS", _menuSettingsFocusNode),
            ],
          ),

          // Profile circle indicator
          Container(
            width: 44.0,
            height: 44.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
              image: const DecorationImage(
                image: CachedNetworkImageProvider(
                  'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=150',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // INDIVIDUAL TOP MENU BUTTONS
  Widget _buildMenuItem(String tabKey, FocusNode fNode) {
    final isSelected = _activeTab == tabKey;
    
    return TvFocusable(
      focusNode: fNode,
      scaleFactor: 1.05,
      enableGlow: false,
      borderRadius: BorderRadius.circular(12.0),
      onTap: () {
        setState(() {
          _activeTab = tabKey;
        });
      },
      child: FocusBuilder(
        focusNode: fNode,
        builder: (context, hasFocus) {
          final active = hasFocus || isSelected;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: hasFocus 
                  ? const Color(0xFFFFD700).withOpacity(0.12)
                  : (isSelected ? Colors.white.withOpacity(0.05) : Colors.transparent),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Row(
              children: [
                if (isSelected) ...[
                  Container(
                    width: 6.0,
                    height: 6.0,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD700),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8.0),
                ],
                Text(
                  tabKey,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.0,
                    fontWeight: active ? FontWeight.bold : FontWeight.w500,
                    color: active ? const Color(0xFFFFD700) : Colors.white60,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // TAB CONTENT FACTORY
  Widget _buildActiveTabContent(
    List<MediaItem> continueWatching,
    List<MediaItem> movies,
    List<MediaItem> tvShows,
    List<MediaItem> anime,
    Size size,
  ) {
    switch (_activeTab) {
      case 'HOME':
        return _buildHomeTab(continueWatching, movies, tvShows, anime, size);
      case 'LIVE TV':
        return const TvIptvScreen();
      case 'SEARCH':
        return _buildSearchTab();
      case 'VAULT':
        return _buildVaultTab();
      case 'SETTINGS':
        return _buildSettingsTab();
      default:
        return Container();
    }
  }

  // ================== TAB 1: HOME TAB ==================
  Widget _buildHomeTab(
    List<MediaItem> continueWatching,
    List<MediaItem> movies,
    List<MediaItem> tvShows,
    List<MediaItem> anime,
    Size size,
  ) {
    final bool isVaulted = _vaultedItemIds.contains(_backdropMediaItem.id);

    return SingleChildScrollView(
      controller: _mainScrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // DYNAMIC TEXT DETAILS OVER FEATURED AREA
          Padding(
            padding: const EdgeInsets.only(left: 48.0, top: 40.0, right: 48.0),
            child: SizedBox(
              width: size.width * 0.50,
              height: size.height * 0.38,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Gold pill Category indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4), width: 0.8),
                    ),
                    child: Text(
                      "FEATURED PRESENTATION • ${_backdropMediaItem.type.toUpperCase()}",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.0,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFFD700),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // Immersive Cinematic Title
                  Text(
                    _backdropMediaItem.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cinzel(
                      fontSize: 44.0,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                      shadows: [
                        const Shadow(
                          color: Colors.black87,
                          offset: Offset(0, 4),
                          blurRadius: 12.0,
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 12.0),

                  // Ratings, Year, Duration Metadata Row
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 18.0),
                      const SizedBox(width: 4.0),
                      Text(
                        _backdropMediaItem.rating.toString(),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 15.0,
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      _buildDot(),
                      const SizedBox(width: 16.0),
                      Text(
                        _backdropMediaItem.year,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 15.0,
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      _buildDot(),
                      const SizedBox(width: 16.0),
                      Text(
                        _backdropMediaItem.duration,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 15.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),

                  // Readable, deep-contrast Synopsis text
                  Text(
                    _backdropMediaItem.synopsis,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 15.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24.0),

                  // Action D-pad focusable buttons
                  Row(
                    children: [
                      // Watch Now primary CTA
                      TvFocusable(
                        focusNode: _btnPlayFocusNode,
                        onFocusChanged: (hasFocus) {
                          if (hasFocus) {
                            _scrollToVerticalOffset(0.0);
                          }
                        },
                        onTap: () => _onCardTap(_backdropMediaItem),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 14.0),
                          color: const Color(0xFFFFD700),
                          child: Row(
                            children: [
                              const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 24.0),
                              const SizedBox(width: 8.0),
                              Text(
                                "Watch Now",
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15.0,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16.0),

                      // Add/Remove Vault secondary CTA
                      TvFocusable(
                        focusNode: _btnVaultFocusNode,
                        onFocusChanged: (hasFocus) {
                          if (hasFocus) {
                            _scrollToVerticalOffset(0.0);
                          }
                        },
                        onTap: () => _toggleVault(_backdropMediaItem),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isVaulted ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                color: isVaulted ? const Color(0xFFFFD700) : Colors.white,
                                size: 22.0,
                              ),
                              const SizedBox(width: 8.0),
                              Text(
                                isVaulted ? "In Vault" : "Vault Movie",
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15.0,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24.0),

          // HORIZONTAL ROWS WITH FOCUS-SCROLLING
          if (continueWatching.isNotEmpty)
            Focus(
              onFocusChange: (hasFocus) {
                if (hasFocus) _scrollToVerticalOffset(120.0);
              },
              child: TvRow(
                title: "Continue Watching",
                items: continueWatching,
                isLandscape: true,
                onCardFocused: _onCardFocused,
                onCardTap: _onCardTap,
              ),
            ),

          Focus(
            onFocusChange: (hasFocus) {
              if (hasFocus) _scrollToVerticalOffset(320.0);
            },
            child: TvRow(
              title: "Cinematic Masterpieces (Movies)",
              items: movies,
              isLandscape: false,
              onCardFocused: _onCardFocused,
              onCardTap: _onCardTap,
            ),
          ),

          Focus(
            onFocusChange: (hasFocus) {
              if (hasFocus) _scrollToVerticalOffset(600.0);
            },
            child: TvRow(
              title: "Top-Tier Series (TV Shows)",
              items: tvShows,
              isLandscape: false,
              onCardFocused: _onCardFocused,
              onCardTap: _onCardTap,
            ),
          ),

          Focus(
            onFocusChange: (hasFocus) {
              if (hasFocus) _scrollToVerticalOffset(880.0);
            },
            child: TvRow(
              title: "Vivid Dimensions (Anime)",
              items: anime,
              isLandscape: false,
              onCardFocused: _onCardFocused,
              onCardTap: _onCardTap,
            ),
          ),

          const SizedBox(height: 120.0), // Large bottom spacing
        ],
      ),
    );
  }

  Widget _buildDot() {
    return Container(
      width: 5.0,
      height: 5.0,
      decoration: const BoxDecoration(
        color: Colors.white30,
        shape: BoxShape.circle,
      ),
    );
  }

  // ================== TAB 2: SEARCH TAB ==================
  Widget _buildSearchTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A. TV Widescreen Search Input & Virtual D-pad Search Bar
          Row(
            children: [
              Expanded(
                child: GlassmorphicCard(
                  padding: EdgeInsets.zero,
                  borderRadius: 16.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Color(0xFFFFD700), size: 28.0),
                        const SizedBox(width: 16.0),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: _performSearch,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 18.0,
                            ),
                            decoration: InputDecoration(
                              hintText: "Search title, genre, or keyword using keyboard...",
                              hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 16.0),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16.0),
              
              // Voice search action
              TvFocusable(
                borderRadius: BorderRadius.circular(16.0),
                onTap: _startTvVoiceSearch,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                  color: Colors.white.withOpacity(0.08),
                  child: Icon(
                    Icons.mic_rounded,
                    color: Theme.of(context).primaryColor,
                    size: 24.0,
                  ),
                ),
              ),
              const SizedBox(width: 12.0),
              
              // Clear action
              TvFocusable(
                borderRadius: BorderRadius.circular(16.0),
                onTap: () {
                  _searchController.clear();
                  _performSearch('');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  color: Colors.white.withOpacity(0.08),
                  child: Text(
                    "CLEAR",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24.0),

          // B. Quick Tag Recommendations (D-pad focusable)
          Text(
            "TRENDING TV SEARCHES",
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white38,
              fontSize: 12.0,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12.0),
          
          Wrap(
            spacing: 12.0,
            runSpacing: 12.0,
            children: _trendingKeywords.map((keyword) {
              return TvFocusable(
                borderRadius: BorderRadius.circular(20.0),
                onTap: () {
                  _searchController.text = keyword;
                  _performSearch(keyword);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  color: Colors.white.withOpacity(0.05),
                  child: Text(
                    keyword,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 14.0,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32.0),

          // C. Results Grid in Widescreen Format
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "SEARCH RESULTS (${_searchResults.length})",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                    fontSize: 18.0,
                  ),
                ),
                const SizedBox(height: 16.0),
                Expanded(
                  child: _searchResults.isEmpty
                      ? Center(
                          child: Text(
                            "No cinematic matches found. Try another stellar query!",
                            style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 16.0),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Wrap(
                            spacing: 16.0,
                            runSpacing: 20.0,
                            children: _searchResults.map((item) {
                              return SizedBox(
                                width: 160.0,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 240.0,
                                      child: TvFocusable(
                                        onTap: () => _onCardTap(item),
                                        child: CachedNetworkImage(
                                          imageUrl: item.posterUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(color: Colors.white.withOpacity(0.04)),
                                          errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8.0),
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13.0,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ================== TAB 3: VAULT TAB ==================
  Widget _buildVaultTab() {
    final vaultedItems = _dynamicBookmarks;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "YOUR PREMIUM VAULT",
            style: GoogleFonts.cinzel(
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFFD700),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            "Your custom collection of curated cinematic masterpieces, offline synced and ready for instant playback.",
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white38,
              fontSize: 14.0,
            ),
          ),
          const SizedBox(height: 32.0),
          
          Expanded(
            child: vaultedItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bookmark_outline_rounded, color: Colors.white38, size: 64.0),
                        const SizedBox(height: 16.0),
                        Text(
                          "Your Vault is Empty",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          "Select 'Vault Movie' on any title card to store items in this premium section.",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white38,
                            fontSize: 14.0,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Wrap(
                      spacing: 24.0,
                      runSpacing: 28.0,
                      children: vaultedItems.map((item) {
                        return SizedBox(
                          width: 200.0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 300.0,
                                child: TvFocusable(
                                  onTap: () => _onCardTap(item),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: CachedNetworkImage(
                                          imageUrl: item.posterUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(color: Colors.white.withOpacity(0.04)),
                                          errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
                                        ),
                                      ),
                                      Positioned(
                                        top: 12.0,
                                        left: 12.0,
                                        child: Container(
                                          padding: const EdgeInsets.all(6.0),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFFFD700),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.bookmark_rounded, color: Colors.black, size: 14.0),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12.0),
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4.0),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.type,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.0,
                                      color: const Color(0xFFFFD700).withOpacity(0.8),
                                    ),
                                  ),
                                  TvFocusable(
                                    borderRadius: BorderRadius.circular(4.0),
                                    scaleFactor: 1.1,
                                    enableGlow: false,
                                    onTap: () => _toggleVault(item),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                      color: Colors.red.withOpacity(0.2),
                                      child: Text(
                                        "REMOVE",
                                        style: GoogleFonts.plusJakartaSans(fontSize: 9.0, color: Colors.redAccent, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ================== TAB 4: SETTINGS TAB ==================
  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column Settings Categories (D-pad Focusable)
          SizedBox(
            width: 320.0,
            child: ListView(
              children: [
                _buildSettingsCategoryItem("profile", "Account Profile", Icons.account_circle_outlined),
                const SizedBox(height: 12.0),
                _buildSettingsCategoryItem("server", "Server URL Settings", Icons.dns_outlined),
                const SizedBox(height: 12.0),
                _buildSettingsCategoryItem("analytics", "Cinematic Analytics", Icons.bar_chart_rounded),
                const SizedBox(height: 12.0),
                _buildSettingsCategoryItem("watchparty", "Co-Watching Party", Icons.groups_outlined),
                const SizedBox(height: 12.0),
                _buildSettingsCategoryItem("scanner", "Channel Scanner Dashboard", Icons.radar_rounded),
                const SizedBox(height: 12.0),
                _buildSettingsCategoryItem("iptv", "IPTV & M3U Playlist Setup", Icons.tv_rounded),
                const SizedBox(height: 12.0),
                _buildSettingsCategoryItem("theme", "Visual Theme Accent", Icons.palette_outlined),
                const SizedBox(height: 12.0),
                _buildSettingsCategoryItem("playback", "Playback & Quality", Icons.hd_outlined),
                const SizedBox(height: 12.0),
                _buildSettingsCategoryItem("audio", "Audio Output", Icons.volume_up_outlined),
                const SizedBox(height: 12.0),
                _buildSettingsCategoryItem("subtitles", "Subtitles & Language", Icons.subtitles_outlined),
                const SizedBox(height: 12.0),
                _buildSettingsCategoryItem("diagnostics", "Diagnostics & Speed", Icons.speed_outlined),
              ],
            ),
          ),
          
          const SizedBox(width: 48.0),
          
          // Right Column details panel changing instantly on focus
          Expanded(
            child: GlassmorphicCard(
              borderRadius: 24.0,
              padding: const EdgeInsets.all(32.0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildSettingsDetailContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCategoryItem(String key, String title, IconData icon) {
    final bool isFocused = _focusedSettingKey == key;
    final primaryColor = Theme.of(context).primaryColor;
    
    return TvFocusable(
      onFocusChanged: (hasFocus) {
        if (hasFocus) {
          setState(() {
            _focusedSettingKey = key;
          });
        }
      },
      borderRadius: BorderRadius.circular(16.0),
      onTap: () {
        // Confirm action Snack
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Setting '$title' selected! Config successfully updated."),
            backgroundColor: primaryColor.withOpacity(0.15),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        color: isFocused ? primaryColor.withOpacity(0.15) : Colors.white.withOpacity(0.04),
        child: Row(
          children: [
            Icon(icon, color: isFocused ? primaryColor : Colors.white60, size: 24.0),
            const SizedBox(width: 16.0),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  color: isFocused ? Colors.white : Colors.white70,
                  fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16.0,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_right_rounded, color: isFocused ? primaryColor : Colors.white24),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsDetailContent() {
    switch (_focusedSettingKey) {
      case 'analytics':
        return _buildAnalyticsSettingsDetail();
      case 'watchparty':
        return _buildWatchPartySettingsDetail();
      case 'iptv':
        final primaryColor = Theme.of(context).primaryColor;
        return Column(
          key: const ValueKey('iptv'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "IPTV & M3U PLAYLIST SETUP",
              style: GoogleFonts.cinzel(
                fontSize: 22.0,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              "Add and configure custom IPTV M3U streams and EPG guides to personalize your live experience.",
              style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 13.0),
            ),
            const SizedBox(height: 24.0),

            // M3U Playlist Input
            Focus(
              focusNode: _iptvM3uFocusNode,
              child: FocusBuilder(
                focusNode: _iptvM3uFocusNode,
                builder: (context, hasFocus) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: hasFocus ? primaryColor : Colors.white12,
                        width: hasFocus ? 2.0 : 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: TextField(
                      controller: _iptvM3uController,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 15.0),
                      decoration: InputDecoration(
                        labelText: "M3U Playlist URL",
                        labelStyle: GoogleFonts.plusJakartaSans(
                          color: hasFocus ? primaryColor : Colors.white38,
                          fontSize: 13.0,
                        ),
                        hintText: "e.g., https://example.com/playlist.m3u",
                        hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 14.0),
                        border: InputBorder.none,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16.0),

            // EPG Guide Input
            Focus(
              focusNode: _iptvEpgFocusNode,
              child: FocusBuilder(
                focusNode: _iptvEpgFocusNode,
                builder: (context, hasFocus) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: hasFocus ? primaryColor : Colors.white12,
                        width: hasFocus ? 2.0 : 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: TextField(
                      controller: _iptvEpgController,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 15.0),
                      decoration: InputDecoration(
                        labelText: "EPG (Program Guide) XML URL",
                        labelStyle: GoogleFonts.plusJakartaSans(
                          color: hasFocus ? primaryColor : Colors.white38,
                          fontSize: 13.0,
                        ),
                        hintText: "e.g., http://example.com/epg.xml",
                        hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 14.0),
                        border: InputBorder.none,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24.0),

            // Connection Status & Diagnostic info
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  Icon(
                    _iptvReloading ? Icons.sync_outlined : Icons.check_circle_outline_rounded, 
                    color: _iptvReloading ? Colors.amber : Colors.greenAccent, 
                    size: 24.0
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _iptvReloading ? "RELOAD / SYNC ACTIVE..." : "SYNC COMPLETED",
                          style: GoogleFonts.plusJakartaSans(
                            color: _iptvReloading ? Colors.amber : Colors.greenAccent,
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          _iptvReloading 
                              ? "Downloading remote files and verifying video indices..."
                              : "Parsed $_iptvParsedCount Premium HLS channels successfully.",
                          style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 12.0),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24.0),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TvFocusable(
                    focusNode: _iptvReloadFocusNode,
                    onTap: () async {
                      if (_iptvReloading) return;
                      setState(() {
                        _iptvReloading = true;
                      });
                      await Future.delayed(const Duration(milliseconds: 1500));
                      if (mounted) {
                        setState(() {
                          _iptvReloading = false;
                          _iptvParsedCount = 15;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text("Remote playlist indices updated & loaded!"),
                            backgroundColor: primaryColor,
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(12.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      color: Colors.white.withOpacity(0.08),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.refresh_rounded, color: Colors.white, size: 20.0),
                          const SizedBox(width: 8.0),
                          Text(
                            "Sync Playlist",
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: TvFocusable(
                    focusNode: _iptvSaveFocusNode,
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('iptv_m3u_url', _iptvM3uController.text);
                      await prefs.setString('iptv_epg_url', _iptvEpgController.text);
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text("IPTV M3U & EPG configurations saved!"),
                            backgroundColor: primaryColor,
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(12.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      color: primaryColor,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_rounded, color: Colors.black, size: 20.0),
                          const SizedBox(width: 8.0),
                          Text(
                            "Apply & Save",
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.0,
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
        );
      case 'scanner':
        final primaryColor = Theme.of(context).primaryColor;
        final statusColor = _scannerStatus == 'scanning'
            ? Colors.amber
            : (_scannerStatus == 'error' ? Colors.redAccent : Colors.greenAccent);
        final statusText = _scannerStatus == 'scanning'
            ? "SCANNING ACTIVE..."
            : (_scannerStatus == 'error' ? "ERROR DETECTED" : "SCANNER IDLE");

        return Column(
          key: const ValueKey('scanner'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "CHANNEL SCANNER DASHBOARD",
                      style: GoogleFonts.cinzel(
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      "Index and map digital media feeds from your Telegram Channels in real-time.",
                      style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 13.0),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(color: statusColor.withOpacity(0.3), width: 0.8),
                  ),
                  child: Row(
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
              ],
            ),
            const SizedBox(height: 20.0),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 11,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TvFocusable(
                          focusNode: _btnScanFocusNode,
                          onTap: () async {
                            if (_scannerStatus == 'scanning') return;
                            setState(() {
                              _scannerStatus = 'scanning';
                              _scannerLogs = ['[System] Initializing connection to active channel scan...'];
                            });
                            
                            final result = await ApiService.triggerActiveScan();
                            
                            setState(() {
                              _scannerLogs = result['logs'];
                              _scannerStatus = result['success'] ? 'idle' : 'error';
                            });
                            
                            await _loadUnresolvedListings();
                          },
                          borderRadius: BorderRadius.circular(14.0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            color: _scannerStatus == 'scanning' 
                                ? Colors.white.withOpacity(0.04) 
                                : primaryColor,
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _scannerStatus == 'scanning' 
                                      ? Icons.hourglass_empty_rounded 
                                      : Icons.radar_rounded, 
                                  color: _scannerStatus == 'scanning' ? Colors.white38 : Colors.black, 
                                  size: 22.0
                                ),
                                const SizedBox(width: 10.0),
                                Text(
                                  _scannerStatus == 'scanning' ? "SCAN IN PROGRESS..." : "TRIGGER ACTIVE SCAN",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: _scannerStatus == 'scanning' ? Colors.white60 : Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        Text(
                          "SCANNER LOGS FEED",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white38,
                            fontSize: 11.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
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
                            padding: const EdgeInsets.all(16.0),
                            child: _scannerLogs.isEmpty
                                ? Center(
                                    child: Text(
                                      "Logs feed empty. Trigger scan to view diagnostics.",
                                      style: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 13.0),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _scannerLogs.length,
                                    itemBuilder: (context, index) {
                                      final log = _scannerLogs[index];
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
                                            fontSize: 12.0,
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
                  const SizedBox(width: 24.0),
                  Expanded(
                    flex: 13,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "UNRESOLVED MEDIA LIBRARY (${_unresolvedListings.length})",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white38,
                            fontSize: 11.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Expanded(
                          flex: 5,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(14.0),
                              border: Border.all(color: Colors.white.withOpacity(0.06)),
                            ),
                            child: _unresolvedListings.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent.withOpacity(0.5), size: 40.0),
                                        const SizedBox(height: 12.0),
                                        Text(
                                          "All media listings resolved!",
                                          style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 13.0),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(8.0),
                                    itemCount: _unresolvedListings.length,
                                    itemBuilder: (context, index) {
                                      final item = _unresolvedListings[index];
                                      final isSelected = _selectedUnresolvedListing != null &&
                                          _selectedUnresolvedListing['id'] == item['id'];
                                      
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0),
                                        child: TvFocusable(
                                          onTap: () {
                                            setState(() {
                                              _selectedUnresolvedListing = item;
                                              if (item['title'].toString().toLowerCase().contains("inception")) {
                                                _overrideTmdbController.text = "27205";
                                              } else if (item['title'].toString().toLowerCase().contains("interstellar")) {
                                                _overrideTmdbController.text = "157336";
                                              } else if (item['title'].toString().toLowerCase().contains("stranger")) {
                                                _overrideTmdbController.text = "66732";
                                              } else {
                                                _overrideTmdbController.clear();
                                              }
                                            });
                                            _overrideInputFocusNode.requestFocus();
                                          },
                                          borderRadius: BorderRadius.circular(10.0),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                                            color: isSelected 
                                                ? primaryColor.withOpacity(0.18) 
                                                : Colors.white.withOpacity(0.03),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  item['type'] == 'tv' ? Icons.tv_rounded : Icons.movie_rounded,
                                                  color: isSelected ? primaryColor : Colors.white54,
                                                  size: 18.0
                                                ),
                                                const SizedBox(width: 12.0),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        item['title'],
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: GoogleFonts.plusJakartaSans(
                                                          color: isSelected ? Colors.white : Colors.white70,
                                                          fontSize: 13.0,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2.0),
                                                      Text(
                                                        "Channel: ${item['channel_id']} • Msg: ${item['message_id']}",
                                                        style: GoogleFonts.plusJakartaSans(
                                                          color: Colors.white38,
                                                          fontSize: 10.5,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (isSelected)
                                                  Icon(Icons.edit_rounded, color: primaryColor, size: 16.0),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        if (_selectedUnresolvedListing != null) ...[
                          Text(
                            "MANUAL TMDB RESOLUTION OVERRIDE",
                            style: GoogleFonts.plusJakartaSans(
                              color: primaryColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Focus(
                                  focusNode: _overrideInputFocusNode,
                                  child: FocusBuilder(
                                    focusNode: _overrideInputFocusNode,
                                    builder: (context, hasFocus) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.04),
                                          borderRadius: BorderRadius.circular(10.0),
                                          border: Border.all(
                                            color: hasFocus ? primaryColor : Colors.white12,
                                            width: hasFocus ? 2.0 : 1.0,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                                        child: TextField(
                                          focusNode: FocusNode(),
                                          controller: _overrideTmdbController,
                                          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13.5),
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            hintText: "Enter TMDB ID...",
                                            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 12.5),
                                            border: InputBorder.none,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12.0),
                              Expanded(
                                flex: 2,
                                child: TvFocusable(
                                  focusNode: _btnOverrideFocusNode,
                                  onTap: () async {
                                    final tmdbId = _overrideTmdbController.text.trim();
                                    if (tmdbId.isEmpty) return;
                                    
                                    final success = await ApiService.resolveListing(
                                      _selectedUnresolvedListing['id'],
                                      tmdbId,
                                    );
                                    
                                    if (success) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text("Resolution successful! '${_selectedUnresolvedListing['title']}' mapped to TMDB ID $tmdbId."),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                      _overrideTmdbController.clear();
                                      setState(() {
                                        _selectedUnresolvedListing = null;
                                      });
                                      await _loadUnresolvedListings();
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("Override resolution failed. Check your TMDB ID."),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(10.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                                    color: primaryColor,
                                    alignment: Alignment.center,
                                    child: Text(
                                      "RESOLVE",
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "Select an unresolved media listing to configure TMDB overrides.",
                              style: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 12.0),
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
      case 'theme':
        final themeProvider = Provider.of<ThemeProvider>(context);
        final currentPreset = themeProvider.currentPreset;
        final primaryColor = Theme.of(context).primaryColor;
        
        return Column(
          key: const ValueKey('theme'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "VISUAL THEME CUSTOMIZATION",
              style: GoogleFonts.cinzel(
                fontSize: 22.0,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              "Personalize Cinegram with high-fidelity color presets optimized for ambient dark-room cinematography.",
              style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 13.0),
            ),
            const SizedBox(height: 32.0),
            
            // D-Pad focusable grid (2x2)
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 20.0,
                mainAxisSpacing: 20.0,
                childAspectRatio: 2.1,
                physics: const NeverScrollableScrollPhysics(),
                children: AccentPreset.values.map((preset) {
                  final bool isSelected = currentPreset == preset;
                  
                  return TvFocusable(
                    onTap: () {
                      themeProvider.setPreset(preset);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Visual Accent changed to ${preset.name}!",
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: preset.color.withOpacity(0.9),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            preset.color.withOpacity(0.15),
                            preset.color.withOpacity(0.02),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          // Color swatch chip
                          Container(
                            width: 32.0,
                            height: 32.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: preset.color,
                              boxShadow: [
                                BoxShadow(
                                  color: preset.color.withOpacity(0.4),
                                  blurRadius: 10.0,
                                  spreadRadius: 1.0,
                                ),
                              ],
                            ),
                            child: isSelected
                                ? const Icon(Icons.check_rounded, color: Colors.black, size: 18.0)
                                : null,
                          ),
                          const SizedBox(width: 16.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  preset.name,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15.0,
                                  ),
                                ),
                                const SizedBox(height: 2.0),
                                Text(
                                  preset == AccentPreset.goldLeaf
                                      ? "Classic luxury cinema"
                                      : preset == AccentPreset.cobaltSapphire
                                          ? "Hyper-modern blue"
                                          : preset == AccentPreset.crimsonRuby
                                              ? "Deep cinema red"
                                              : "Sleek neon green",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white38,
                                    fontSize: 10.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      case 'server':
        final statusColor = _serverCheckingStatus
            ? Colors.amber
            : (_serverConnectionStatus == true ? Colors.greenAccent : Colors.redAccent);
        final statusText = _serverCheckingStatus
            ? "Checking connection..."
            : (_serverConnectionStatus == true ? "Server Status: Connected" : "Server Status: Offline");

        return Column(
          key: const ValueKey('server'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "SERVER URL CONFIGURATION",
              style: GoogleFonts.cinzel(
                fontSize: 22.0,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFFD700),
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              "Customize the backend gateway link for real-time sync with Supabase and Telegram listings.",
              style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 13.0),
            ),
            const SizedBox(height: 24.0),
            
            // Glowing Status Indicator & Label
            Row(
              children: [
                // Glowing dot indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 12.0,
                  height: 12.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.6),
                        blurRadius: 10.0,
                        spreadRadius: 3.0,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12.0),
                Text(
                  statusText,
                  style: GoogleFonts.plusJakartaSans(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20.0),
            
            // URL Input Field
            Focus(
              focusNode: _serverUrlFocusNode,
              child: FocusBuilder(
                focusNode: _serverUrlFocusNode,
                builder: (context, hasFocus) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: hasFocus ? const Color(0xFFFFD700) : Colors.white12,
                        width: hasFocus ? 2.0 : 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: TextField(
                      controller: _serverUrlController,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16.0),
                      decoration: InputDecoration(
                        labelText: "Backend Server URL",
                        labelStyle: GoogleFonts.plusJakartaSans(
                          color: hasFocus ? const Color(0xFFFFD700) : Colors.white38,
                          fontSize: 14.0,
                        ),
                        hintText: "http://localhost:3000 or https://your-server.render.com",
                        hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 14.0),
                        border: InputBorder.none,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24.0),
            
            // D-Pad Focusable Buttons
            Row(
              children: [
                Expanded(
                  child: TvFocusable(
                    focusNode: _serverTestFocusNode,
                    onTap: () {
                      _checkServerConnection(_serverUrlController.text);
                    },
                    borderRadius: BorderRadius.circular(12.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      color: Colors.white.withOpacity(0.08),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.refresh_rounded, color: Colors.white, size: 20.0),
                          const SizedBox(width: 8.0),
                          Text(
                            "Test Link",
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: TvFocusable(
                    focusNode: _serverSaveFocusNode,
                    onTap: () async {
                      final newUrl = _serverUrlController.text.trim();
                      await ApiService.setCustomBaseUrl(newUrl);
                      await _checkServerConnection(newUrl);
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Backend Server URL updated and saved!"),
                            backgroundColor: const Color(0xFFFFD700).withOpacity(0.9),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(12.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      color: const Color(0xFFFFD700),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_rounded, color: Colors.black, size: 20.0),
                          const SizedBox(width: 8.0),
                          Text(
                            "Apply & Save",
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.0,
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
        );
      case 'profile':
        final activeProf = ApiService.activeProfile ?? "Viewer";
        return Column(
          key: const ValueKey('profile'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("ACCOUNT PROFILE", style: GoogleFonts.cinzel(fontSize: 22.0, fontWeight: FontWeight.bold, color: const Color(0xFFFFD700))),
            const SizedBox(height: 24.0),
            Row(
              children: [
                Container(
                  width: 80.0,
                  height: 80.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFD700), width: 2.0),
                    image: const DecorationImage(
                      image: CachedNetworkImageProvider(
                        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=150',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 24.0),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(activeProf, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 20.0, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4.0),
                    Text("Status: Executive VIP • Active", style: GoogleFonts.plusJakartaSans(color: const Color(0xFFFFD700), fontSize: 14.0, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2.0),
                    Text("Renews: Dec 31, 2026", style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 13.0)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32.0),
            const Divider(color: Colors.white12),
            const SizedBox(height: 16.0),
            _buildSettingDetailRow("Email", "premium.vip@cinegram.io"),
            _buildSettingDetailRow("Device ID", "CINE-TV-4K-99FA"),
            _buildSettingDetailRow("Country", "United States (US)"),
            const SizedBox(height: 24.0),
            TvFocusable(
              onTap: () async {
                final authorized = await _showParentalGate(context);
                if (authorized) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const ProfileSelectScreen()),
                    (route) => false,
                  );
                }
              },
              borderRadius: BorderRadius.circular(12.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                color: Theme.of(context).primaryColor,
                alignment: Alignment.center,
                child: Text(
                  "Switch Profile",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 15.0,
                  ),
                ),
              ),
            ),
          ],
        );
      case 'playback':
        return Column(
          key: const ValueKey('playback'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("PLAYBACK & QUALITY", style: GoogleFonts.cinzel(fontSize: 22.0, fontWeight: FontWeight.bold, color: const Color(0xFFFFD700))),
            const SizedBox(height: 8.0),
            Text("Calibrate visual settings for your widescreen display.", style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 13.0)),
            const SizedBox(height: 24.0),
            _buildSelectableSettingOption("Auto (UHD 4K Dolby Vision)", true),
            const SizedBox(height: 10.0),
            _buildSelectableSettingOption("High Fidelity (1080p HDR)", false),
            const SizedBox(height: 10.0),
            _buildSelectableSettingOption("Bandwidth Saver (720p SDR)", false),
            const SizedBox(height: 24.0),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFFFFD700), size: 16.0),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text("4K streaming requires an active high-speed connection of at least 25 Mbps.", style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12.0)),
                ),
              ],
            )
          ],
        );
      case 'audio':
        return Column(
          key: const ValueKey('audio'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("AUDIO OUTPUT", style: GoogleFonts.cinzel(fontSize: 22.0, fontWeight: FontWeight.bold, color: const Color(0xFFFFD700))),
            const SizedBox(height: 8.0),
            Text("Configure ambient soundstage settings.", style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 13.0)),
            const SizedBox(height: 24.0),
            _buildSelectableSettingOption("Dolby Atmos 7.1 Passthrough", true),
            const SizedBox(height: 10.0),
            _buildSelectableSettingOption("DTS Headphone:X Surround", false),
            const SizedBox(height: 10.0),
            _buildSelectableSettingOption("PCM Stereo Audio", false),
          ],
        );
      case 'subtitles':
        return Column(
          key: const ValueKey('subtitles'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("SUBTITLES & LANGUAGE", style: GoogleFonts.cinzel(fontSize: 22.0, fontWeight: FontWeight.bold, color: const Color(0xFFFFD700))),
            const SizedBox(height: 24.0),
            _buildSettingDetailRow("Default Audio Track", "English [Original]"),
            _buildSettingDetailRow("Subtitles CC", "English [Closed Captions]"),
            _buildSettingDetailRow("Subtitles Style", "Glassmorphic Gold (Semi-translucent)"),
            _buildSettingDetailRow("Text Size", "Medium (24px TV Optimized)"),
          ],
        );
      case 'diagnostics':
        return Column(
          key: const ValueKey('diagnostics'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("DIAGNOSTICS & SPEED", style: GoogleFonts.cinzel(fontSize: 22.0, fontWeight: FontWeight.bold, color: const Color(0xFFFFD700))),
            const SizedBox(height: 24.0),
            _buildSettingDetailRow("App Version", "v2.6.0-TV PREMIER PRO"),
            _buildSettingDetailRow("Server Region", "US-East (Virginia)"),
            _buildSettingDetailRow("Ping Latency", "12 ms"),
            _buildSettingDetailRow("Network Speed", "420 Mbps (Atmos & 4K Ready)"),
            const SizedBox(height: 20.0),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                  const SizedBox(width: 12.0),
                  Text("All TV rendering engines are operating optimally.", style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13.0)),
                ],
              ),
            ),
          ],
        );
      default:
        return Container();
    }
  }

  Widget _buildSettingDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 15.0)),
          Text(value, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.0)),
        ],
      ),
    );
  }

  Widget _buildSelectableSettingOption(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFFD700).withOpacity(0.1) : Colors.white.withOpacity(0.02),
        border: Border.all(
          color: isSelected ? const Color(0xFFFFD700).withOpacity(0.5) : Colors.white12,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: isSelected ? Colors.white : Colors.white54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 15.0,
            ),
          ),
          if (isSelected)
            const Icon(Icons.check_circle_rounded, color: Color(0xFFFFD700), size: 20.0),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSettingsDetail() {
    final primaryColor = Theme.of(context).primaryColor;
    return FutureBuilder<Map<String, dynamic>>(
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

        return SingleChildScrollView(
          key: const ValueKey('analytics'),
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
                        "CINEMATIC ANALYTICS",
                        style: GoogleFonts.cinzel(
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        "Visual viewing behavior and cinematic patterns for profile: ${ApiService.activeProfile ?? 'Viewer'}",
                        style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 13.0),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: primaryColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      "PREMIUM ONLY",
                      style: GoogleFonts.plusJakartaSans(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24.0),

              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      "Total Screen Time",
                      "${totalHours.toStringAsFixed(1)} Hrs",
                      "Across all listed streams",
                      Icons.timer_rounded,
                      primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: _buildMetricTile(
                      "Favorite Genre",
                      donutData.isNotEmpty ? donutData.entries.first.key : "N/A",
                      "Highest completed playback",
                      Icons.movie_filter_rounded,
                      Colors.purpleAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24.0),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Container(
                      height: 200.0,
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 110.0,
                            height: 110.0,
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
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "GENRE SPLIT",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 8.0),
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
                                        Container(
                                          width: 8.0,
                                          height: 8.0,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: col,
                                          ),
                                        ),
                                        const SizedBox(width: 8.0),
                                        Text(
                                          "${e.key}: ${e.value.toInt()} plays",
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white54,
                                            fontSize: 11.0,
                                          ),
                                        ),
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
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    flex: 5,
                    child: Container(
                      height: 200.0,
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "WEEKLY ACTIVITY TREND (HOURS)",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(7, (i) {
                              final double h = weeklyData[i];
                              final String day = ["M", "T", "W", "T", "F", "S", "S"][i];
                              return Column(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 500),
                                    width: 14.0,
                                    height: (h / 6.0) * 110.0,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [primaryColor, primaryColor.withOpacity(0.3)],
                                      ),
                                      borderRadius: BorderRadius.circular(4.0),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryColor.withOpacity(0.2),
                                          blurRadius: 4.0,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6.0),
                                  Text(
                                    day,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white38,
                                      fontSize: 10.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24.0),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "PLAYHEAD SKIP DENSITY (TIMELINE HEATMAP)",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          "Active Movie: Inception",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.0,
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      "Spikes represent high-frequency seek and skip behaviors across co-watching streams.",
                      style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 11.0),
                    ),
                    const SizedBox(height: 24.0),
                    SizedBox(
                      height: 60.0,
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
        );
      },
    );
  }

  Widget _buildMetricTile(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 24.0),
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white38,
                    fontSize: 11.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white24,
                    fontSize: 10.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _tvPartyRoomCode = '';
  bool _tvIsCreatingParty = false;
  final TextEditingController _tvRoomCodeController = TextEditingController();
  final FocusNode _tvCreatePartyFocusNode = FocusNode(debugLabel: "TvCreatePartyBtn");
  final FocusNode _tvJoinPartyCodeFocusNode = FocusNode(debugLabel: "TvJoinPartyCodeInput");
  final FocusNode _tvJoinPartyBtnFocusNode = FocusNode(debugLabel: "TvJoinPartyBtn");
  final FocusNode _tvLaunchHostPartyFocusNode = FocusNode(debugLabel: "TvLaunchHostPartyBtn");

  Widget _buildWatchPartySettingsDetail() {
    final primaryColor = Theme.of(context).primaryColor;
    return StatefulBuilder(
      builder: (context, setPartyState) {
        return Column(
          key: const ValueKey('watchparty'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "CO-WATCHING WATCH PARTY",
              style: GoogleFonts.cinzel(
                fontSize: 22.0,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              "Sync and co-watch video streams with other viewers globally. Host private viewing rooms or enter a room code.",
              style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 13.0),
            ),
            const SizedBox(height: 32.0),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "HOST WATCH PARTY",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12.0),
                      Text(
                        "Create a dynamic synchronized session using the featured movie listing: Inception.",
                        style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 12.0, height: 1.4),
                      ),
                      const SizedBox(height: 20.0),
                      
                      if (_tvPartyRoomCode.isEmpty)
                        Focus(
                          focusNode: _tvCreatePartyFocusNode,
                          child: FocusBuilder(
                            focusNode: _tvCreatePartyFocusNode,
                            builder: (context, hasFocus) {
                              return ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: hasFocus ? primaryColor : Colors.white.withOpacity(0.08),
                                  side: BorderSide(color: hasFocus ? primaryColor : Colors.white12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                                ),
                                onPressed: () async {
                                  setPartyState(() {
                                    _tvIsCreatingParty = true;
                                  });
                                  final defaultMedia = mockMediaDatabase.first;
                                  final room = await ApiService.createWatchParty(
                                    defaultMedia.id.toString(),
                                    defaultMedia.title,
                                  );
                                  setPartyState(() {
                                    _tvPartyRoomCode = room['roomId'] ?? '123456';
                                    _tvIsCreatingParty = false;
                                  });
                                },
                                icon: Icon(
                                  _tvIsCreatingParty ? Icons.sync : Icons.add_to_queue_rounded,
                                  color: hasFocus ? Colors.black : Colors.white,
                                ),
                                label: Text(
                                  _tvIsCreatingParty ? "Creating..." : "Create Watch Room",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: hasFocus ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "ROOM CODE GENERATED",
                              style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 10.0, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6.0),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12.0),
                                border: Border.all(color: primaryColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                _tvPartyRoomCode,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 32.0,
                                  fontWeight: FontWeight.w900,
                                  color: primaryColor,
                                  letterSpacing: 4.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16.0),
                            Focus(
                              focusNode: _tvLaunchHostPartyFocusNode,
                              child: FocusBuilder(
                                focusNode: _tvLaunchHostPartyFocusNode,
                                builder: (context, hasFocus) {
                                  return ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: hasFocus ? primaryColor : Colors.greenAccent.withOpacity(0.1),
                                      side: BorderSide(color: hasFocus ? primaryColor : Colors.greenAccent),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                                    ),
                                    onPressed: () {
                                      final defaultMedia = mockMediaDatabase.first;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => TvPlayerScreen(
                                            mediaItem: defaultMedia,
                                            watchPartyRoomId: _tvPartyRoomCode,
                                            isHost: true,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: Icon(Icons.play_arrow_rounded, color: hasFocus ? Colors.black : Colors.greenAccent),
                                    label: Text(
                                      "Launch Room",
                                      style: GoogleFonts.plusJakartaSans(
                                        color: hasFocus ? Colors.black : Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 48.0),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "JOIN EXISTING ROOM",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12.0),
                      Text(
                        "Input the 6-digit sync room code generated by the host to connect watch progress.",
                        style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 12.0, height: 1.4),
                      ),
                      const SizedBox(height: 20.0),

                      Focus(
                        focusNode: _tvJoinPartyCodeFocusNode,
                        child: FocusBuilder(
                          focusNode: _tvJoinPartyCodeFocusNode,
                          builder: (context, hasFocus) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(12.0),
                                border: Border.all(
                                  color: hasFocus ? primaryColor : Colors.white12,
                                  width: hasFocus ? 2.0 : 1.0,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                              child: TextField(
                                controller: _tvRoomCodeController,
                                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 15.0),
                                decoration: InputDecoration(
                                  labelText: "6-Digit Code",
                                  labelStyle: GoogleFonts.plusJakartaSans(
                                    color: hasFocus ? primaryColor : Colors.white38,
                                    fontSize: 13.0,
                                  ),
                                  hintText: "e.g., 295819",
                                  hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 14.0),
                                  border: InputBorder.none,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16.0),

                      Focus(
                        focusNode: _tvJoinPartyBtnFocusNode,
                        child: FocusBuilder(
                          focusNode: _tvJoinPartyBtnFocusNode,
                          builder: (context, hasFocus) {
                            return ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: hasFocus ? primaryColor : Colors.white.withOpacity(0.08),
                                side: BorderSide(color: hasFocus ? primaryColor : Colors.white12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                                minimumSize: const Size(double.infinity, 48),
                              ),
                              onPressed: () async {
                                final code = _tvRoomCodeController.text.trim();
                                if (code.length != 6) {
                                  _showToast("Enter a valid 6-digit code");
                                  return;
                                }
                                final room = await ApiService.getWatchPartyRoom(code);
                                if (room.isEmpty) {
                                  _showToast("Watch room not found");
                                  return;
                                }
                                final listingId = room['listingId']?.toString() ?? '1';
                                final match = mockMediaDatabase.firstWhere(
                                  (x) => x.id.toString() == listingId,
                                  orElse: () => mockMediaDatabase.first,
                                );

                                if (context.mounted) {
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
                              icon: Icon(Icons.groups_rounded, color: hasFocus ? Colors.black : Colors.white),
                              label: Text(
                                "Join Synced Party",
                                style: GoogleFonts.plusJakartaSans(
                                  color: hasFocus ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontFamily: 'Outfit'),
        ),
        backgroundColor: const Color(0xFFE50914),
        duration: const Duration(seconds: 2),
      ),
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

// Focus builder helper to simplify focused states
class FocusBuilder extends StatelessWidget {
  final FocusNode focusNode;
  final Widget Function(BuildContext context, bool hasFocus) builder;

  const FocusBuilder({
    Key? key,
    required this.focusNode,
    required this.builder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) => builder(context, focusNode.hasFocus),
    );
  }
}
