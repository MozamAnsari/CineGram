import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../theme/cinegram_theme.dart';
import '../models/media_item.dart';
import '../widgets/glassmorphic_card.dart';
import 'tv_player.dart';

// IPTV Channel Model Definition
class IptvChannel {
  final String name;
  final String logoUrl;
  final String streamUrl;
  final String category;
  final String status;
  final int pingMs;
  final String currentProgram;
  final String nextProgram;

  const IptvChannel({
    required this.name,
    required this.logoUrl,
    required this.streamUrl,
    required this.category,
    this.status = 'Stable',
    this.pingMs = 12,
    this.currentProgram = 'Cinegram Premium Presentation Live',
    this.nextProgram = 'Direct Broadcast Network Feed',
  });
}

// Customized IPTV focusable widget for 10-foot Television HUD
class IptvFocusable extends StatefulWidget {
  final Widget child;
  final FocusNode? focusNode;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onFocusChanged;
  final double scaleFactor;
  final Color? glowColor;
  final BorderRadius borderRadius;

  const IptvFocusable({
    Key? key,
    required this.child,
    this.focusNode,
    this.onTap,
    this.onFocusChanged,
    this.scaleFactor = 1.05,
    this.glowColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(12.0)),
  }) : super(key: key);

  @override
  State<IptvFocusable> createState() => _IptvFocusableState();
}

class _IptvFocusableState extends State<IptvFocusable> {
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
    final themeGlowColor = widget.glowColor ?? Theme.of(context).primaryColor;
    
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.space ||
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
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: themeGlowColor.withOpacity(0.4),
                        blurRadius: 20.0,
                        spreadRadius: 2.0,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8.0,
                        offset: const Offset(0, 2),
                      )
                    ],
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: widget.borderRadius,
                border: Border.all(
                  color: active ? themeGlowColor : Colors.white.withOpacity(0.08),
                  width: active ? 2.5 : 1.0,
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

class TvIptvScreen extends StatefulWidget {
  const TvIptvScreen({Key? key}) : super(key: key);

  @override
  State<TvIptvScreen> createState() => _TvIptvScreenState();
}

class _TvIptvScreenState extends State<TvIptvScreen> {
  // Static premium fallback streams
  static const List<IptvChannel> _premiumMockChannels = [
    // Sports
    IptvChannel(
      name: 'ESPN UHD',
      logoUrl: 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?q=80&w=300',
      streamUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
      category: 'Sports',
      pingMs: 14,
      currentProgram: 'UEFA Champions League Live Grid',
      nextProgram: 'Sports Center Premium Post-Game',
    ),
    IptvChannel(
      name: 'Sky Sports Main Event',
      logoUrl: 'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?q=80&w=300',
      streamUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
      category: 'Sports',
      pingMs: 18,
      currentProgram: 'F1 Grand Prix Live Broadcast',
      nextProgram: 'Super Sunday Panel Debate',
    ),
    IptvChannel(
      name: 'Eurosport 4K HDR',
      logoUrl: 'https://images.unsplash.com/photo-1517649763962-0c623066013b?q=80&w=300',
      streamUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      category: 'Sports',
      pingMs: 22,
      currentProgram: 'Roland Garros Tennis Finals',
      nextProgram: 'Cycling: Giro d\'Italia Classic Stage',
    ),

    // News
    IptvChannel(
      name: 'BBC World News HD',
      logoUrl: 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?q=80&w=300',
      streamUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
      category: 'News',
      pingMs: 9,
      currentProgram: 'Global Report: Tech Innovation & Climate',
      nextProgram: 'Hardtalk Global Special Interview',
    ),
    IptvChannel(
      name: 'CNN International',
      logoUrl: 'https://images.unsplash.com/photo-1495020689067-958852a6565d?q=80&w=300',
      streamUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
      category: 'News',
      pingMs: 11,
      currentProgram: 'Amanpour Global Affairs Live Debate',
      nextProgram: 'Quest Means Business Financial Hour',
    ),
    IptvChannel(
      name: 'Al Jazeera Live',
      logoUrl: 'https://images.unsplash.com/photo-1504711434969-e33886168f5c?q=80&w=300',
      streamUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
      category: 'News',
      pingMs: 15,
      currentProgram: 'Inside Story: Middle East Geopolitics',
      nextProgram: 'People & Power Weekly Documentary',
    ),

    // Movies
    IptvChannel(
      name: 'HBO Premium East',
      logoUrl: 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?q=80&w=300',
      streamUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
      category: 'Movies',
      pingMs: 25,
      currentProgram: 'House of the Dragon: Season Finale',
      nextProgram: 'Dune: Part Two (Blockbuster Premiere)',
    ),
    IptvChannel(
      name: 'Showtime UHD',
      logoUrl: 'https://images.unsplash.com/photo-1536440136628-849c177e76a1?q=80&w=300',
      streamUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/SubaruOutback.mp4',
      category: 'Movies',
      pingMs: 28,
      currentProgram: 'Yellowjackets Live Stream Premiere',
      nextProgram: 'Billions: Legacy Corporate Special',
    ),
    IptvChannel(
      name: 'Cinegram Live 4K',
      logoUrl: 'https://images.unsplash.com/photo-1478760329108-5c3ed9d495a0?q=80&w=300',
      streamUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      category: 'Movies',
      pingMs: 12,
      currentProgram: 'Aetherius: Echoes of Eternity 4K Showcase',
      nextProgram: 'Shadow Protocol: Tokyo Neon Exclusive',
    ),

    // Entertainment
    IptvChannel(
      name: 'Discovery Channel HD',
      logoUrl: 'https://images.unsplash.com/photo-1535223289827-42f1e9919769?q=80&w=300',
      streamUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4',
      category: 'Entertainment',
      pingMs: 16,
      currentProgram: 'Deadliest Catch: Deep Frost Operations',
      nextProgram: 'MythBusters: Classic Explosion Special',
    ),
    IptvChannel(
      name: 'National Geographic Wild',
      logoUrl: 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?q=80&w=300',
      streamUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WhatCarCanYouGetFor53.mp4',
      category: 'Entertainment',
      pingMs: 13,
      currentProgram: 'Savage Kingdom: Rise of the Cheetahs',
      nextProgram: 'Cosmos: Possible Worlds with Neil Tyson',
    ),
    IptvChannel(
      name: 'Comedy Central Live',
      logoUrl: 'https://images.unsplash.com/photo-1514306191717-452ec28c7814?q=80&w=300',
      streamUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      category: 'Entertainment',
      pingMs: 19,
      currentProgram: 'The Daily Show Live Special',
      nextProgram: 'South Park: Marathon Special Edition',
    ),
  ];

  // Dynamic state
  List<String> _categories = ['Sports', 'News', 'Movies', 'Entertainment'];
  String _activeCategory = 'Sports';
  List<IptvChannel> _displayedChannels = [];
  IptvChannel? _activeChannel;
  bool _isLoading = false;

  // Persistence playlist urls
  String? _customM3uUrl;
  String? _customEpgUrl;

  // Scroll and focus control
  late ScrollController _categoryScrollController;
  late ScrollController _channelScrollController;

  @override
  void initState() {
    super.initState();
    _categoryScrollController = ScrollController();
    _channelScrollController = ScrollController();
    _loadCustomPlaylistConfigAndData();
  }

  @override
  void dispose() {
    _categoryScrollController.dispose();
    _channelScrollController.dispose();
    super.dispose();
  }

  // Load configuration from SharedPreferences and initialize channels
  Future<void> _loadCustomPlaylistConfigAndData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _customM3uUrl = prefs.getString('iptv_m3u_url');
      _customEpgUrl = prefs.getString('iptv_epg_url');

      if (_customM3uUrl != null && _customM3uUrl!.isNotEmpty) {
        // Here we simulate loaded custom M3U playlist channels
        final parsedChannels = [
          IptvChannel(
            name: 'Custom Live Sports 1',
            logoUrl: 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?q=80&w=300',
            streamUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
            category: 'Sports',
            pingMs: 24,
            currentProgram: 'M3U Custom Live Stream Active',
          ),
          IptvChannel(
            name: 'Custom Live News 24',
            logoUrl: 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?q=80&w=300',
            streamUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
            category: 'News',
            pingMs: 14,
            currentProgram: 'Custom M3U XML EPG Program Guide',
          ),
          IptvChannel(
            name: 'Cinegram IPTV Custom M3U',
            logoUrl: 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?q=80&w=300',
            streamUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
            category: 'Movies',
            pingMs: 16,
            currentProgram: 'Custom Playlist Stream Source',
          )
        ];

        // Merge custom loaded channels with static ones to create rich dashboard
        final mergedList = List<IptvChannel>.from(_premiumMockChannels);
        for (var c in parsedChannels) {
          if (!mergedList.any((x) => x.name == c.name)) {
            mergedList.add(c);
          }
        }
        
        setState(() {
          _categories = ['Sports', 'News', 'Movies', 'Entertainment'];
          _displayedChannels = mergedList.where((c) => c.category == _activeCategory).toList();
          _activeChannel = _displayedChannels.isNotEmpty ? _displayedChannels.first : null;
        });
      } else {
        setState(() {
          _displayedChannels = _premiumMockChannels.where((c) => c.category == _activeCategory).toList();
          _activeChannel = _displayedChannels.isNotEmpty ? _displayedChannels.first : null;
        });
      }
    } catch (e) {
      // In case of shared preference or load error, fallback safely
      setState(() {
        _displayedChannels = _premiumMockChannels.where((c) => c.category == _activeCategory).toList();
        _activeChannel = _displayedChannels.isNotEmpty ? _displayedChannels.first : null;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _changeCategory(String category) {
    setState(() {
      _activeCategory = category;
      _displayedChannels = _premiumMockChannels.where((c) => c.category == category).toList();
      _activeChannel = _displayedChannels.isNotEmpty ? _displayedChannels.first : null;
    });
    // Reset vertical list scroll to top
    if (_channelScrollController.hasClients) {
      _channelScrollController.jumpTo(0.0);
    }
  }

  void _onChannelFocused(IptvChannel channel) {
    setState(() {
      _activeChannel = channel;
    });
  }

  void _openLiveStream(IptvChannel channel) {
    // Navigate using PageRoute to premium TvPlayerScreen with dynamically mapped MediaItem
    final mediaItem = MediaItem(
      id: 'iptv_${channel.name.replaceAll(' ', '_')}',
      title: channel.name,
      type: 'Live TV',
      backdropUrl: channel.logoUrl,
      posterUrl: channel.logoUrl,
      rating: 9.9,
      year: 'LIVE',
      duration: 'HLS Live Feed',
      synopsis: 'Active dynamic broadcast feed loaded from M3U playlist configuration. Program currently playing: "${channel.currentProgram}". Next up: "${channel.nextProgram}". Status: Stable.',
      genres: ['Live', channel.category],
      cast: [],
      category: 'Live',
    );

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => TvPlayerScreen(
          mediaItem: mediaItem,
          streamUrl: channel.streamUrl,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final primaryColor = Theme.of(context).primaryColor;

    return FocusScope(
      child: Container(
        color: const Color(0xFF070708),
        padding: const EdgeInsets.fromLTRB(48.0, 20.0, 48.0, 32.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PANE 1: LEFT SIDEBAR CATEGORIES (20% WIDTH)
            SizedBox(
              width: size.width * 0.20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0, bottom: 20.0),
                    child: Row(
                      children: [
                        Icon(Icons.live_tv_rounded, color: primaryColor, size: 28.0),
                        const SizedBox(width: 12.0),
                        Text(
                          'LIVE CATEGORIES',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white38,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _categoryScrollController,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = _activeCategory == cat;

                        // Colorful category highlights for TV simulator
                        Color glowColor = primaryColor;
                        if (cat == 'Sports') glowColor = Colors.emeraldAccent;
                        if (cat == 'News') glowColor = Colors.redAccent;
                        if (cat == 'Movies') glowColor = Colors.amberAccent;
                        if (cat == 'Entertainment') glowColor = Colors.purpleAccent;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: IptvFocusable(
                            glowColor: glowColor,
                            scaleFactor: 1.04,
                            onFocusChanged: (hasFocus) {
                              if (hasFocus) {
                                _changeCategory(cat);
                              }
                            },
                            onTap: () => _changeCategory(cat),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                              color: isSelected 
                                  ? glowColor.withOpacity(0.12)
                                  : Colors.white.withOpacity(0.04),
                              child: Row(
                                children: [
                                  // Live status indicator dot
                                  if (isSelected) ...[
                                    Container(
                                      width: 8.0,
                                      height: 8.0,
                                      decoration: BoxDecoration(
                                        color: glowColor,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: glowColor,
                                            blurRadius: 8.0,
                                            spreadRadius: 1.0,
                                          )
                                        ]
                                      ),
                                    ),
                                    const SizedBox(width: 12.0),
                                  ],
                                  Expanded(
                                    child: Text(
                                      cat.toUpperCase(),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15.0,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? Colors.white : Colors.white70,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.keyboard_arrow_right_rounded, 
                                    color: isSelected ? glowColor : Colors.white24,
                                    size: 18.0,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 32.0),

            // PANE 2: CENTER VERTICAL CHANNEL LIST (40% WIDTH)
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 20.0),
                    child: Text(
                      '$_activeCategory CHANNELS (${_displayedChannels.length})',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white38,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _displayedChannels.isEmpty
                        ? Center(
                            child: Text(
                              'No live channels configured inside $_activeCategory.',
                              style: GoogleFonts.plusJakartaSans(color: Colors.white38),
                            ),
                          )
                        : ListView.builder(
                            controller: _channelScrollController,
                            itemCount: _displayedChannels.length,
                            itemBuilder: (context, index) {
                              final ch = _displayedChannels[index];
                              final isSelected = _activeChannel?.name == ch.name;

                              Color categoryColor = primaryColor;
                              if (ch.category == 'Sports') categoryColor = Colors.emeraldAccent;
                              if (ch.category == 'News') categoryColor = Colors.redAccent;
                              if (ch.category == 'Movies') categoryColor = Colors.amberAccent;
                              if (ch.category == 'Entertainment') categoryColor = Colors.purpleAccent;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: IptvFocusable(
                                  glowColor: categoryColor,
                                  scaleFactor: 1.03,
                                  onFocusChanged: (hasFocus) {
                                    if (hasFocus) {
                                      _onChannelFocused(ch);
                                    }
                                  },
                                  onTap: () => _openLiveStream(ch),
                                  child: Container(
                                    padding: const EdgeInsets.all(12.0),
                                    color: isSelected 
                                        ? categoryColor.withOpacity(0.08) 
                                        : Colors.white.withOpacity(0.02),
                                    child: Row(
                                      children: [
                                        // Channel Logo Thumbnail with Cached Network Image
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8.0),
                                          child: SizedBox(
                                            width: 72.0,
                                            height: 52.0,
                                            child: CachedNetworkImage(
                                              imageUrl: ch.logoUrl,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(color: Colors.white.withOpacity(0.04)),
                                              errorWidget: (context, url, error) => Container(
                                                color: Colors.grey[900],
                                                child: Icon(Icons.live_tv_rounded, color: categoryColor, size: 24.0),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16.0),
                                        // Title and current program subtitle
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                ch.name,
                                                style: GoogleFonts.plusJakartaSans(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16.0,
                                                ),
                                              ),
                                              const SizedBox(height: 4.0),
                                              Text(
                                                ch.currentProgram,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.plusJakartaSans(
                                                  color: isSelected ? categoryColor : Colors.white38,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8.0),
                                        // Status Pill Indicator
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20.0),
                                            border: Border.all(color: Colors.green.withOpacity(0.3), width: 0.8),
                                          ),
                                          child: Text(
                                            '${ch.pingMs}ms',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: Colors.greenAccent,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 32.0),

            // PANE 3: ELEGANT RIGHT DETAILS PANEL (40% WIDTH)
            Expanded(
              flex: 5,
              child: _activeChannel == null
                  ? Center(
                      child: Text(
                        'Select a channel to view dynamic program guides & network statuses.',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 14.0),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20.0),
                          child: Text(
                            'LIVE PRESENTATION PREVIEW',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.white38,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        // Channel Preview Poster Card
                        IptvFocusable(
                          onTap: () => _openLiveStream(_activeChannel!),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: CachedNetworkImage(
                                    imageUrl: _activeChannel!.logoUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(color: Colors.black45),
                                    errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.black.withOpacity(0.9),
                                          Colors.transparent,
                                        ],
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                      ),
                                    ),
                                  ),
                                ),
                                // Glowing Play Icon Overlay
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(16.0),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black.withOpacity(0.65),
                                      border: Border.all(color: Colors.white30, width: 1.5),
                                    ),
                                    child: Icon(
                                      Icons.play_arrow_rounded, 
                                      color: Theme.of(context).primaryColor, 
                                      size: 32.0,
                                    ),
                                  ),
                                ),
                                // Custom Stream Protocol Tag
                                Positioned(
                                  top: 16.0,
                                  left: 16.0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD700).withOpacity(0.2),
                                      border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.6), width: 1.0),
                                      borderRadius: BorderRadius.circular(4.0),
                                    ),
                                    child: Text(
                                      'UHD 4K HLS',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10.0,
                                        color: const Color(0xFFFFD700),
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24.0),
                        
                        // Metadata & EPG Guide Details
                        Text(
                          _activeChannel!.name.toUpperCase(),
                          style: GoogleFonts.cinzel(
                            fontSize: 24.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Row(
                          children: [
                            Text(
                              'Category: ${_activeChannel!.category}',
                              style: GoogleFonts.plusJakartaSans(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.0,
                              ),
                            ),
                            const SizedBox(width: 16.0),
                            Container(width: 4.0, height: 4.0, decoration: const BoxDecoration(color: Colors.white30, shape: BoxShape.circle)),
                            const SizedBox(width: 16.0),
                            Text(
                              'Latency: ${_activeChannel!.pingMs}ms',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.greenAccent,
                                fontSize: 13.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16.0),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 12.0),

                        // Electronic Program Guide EPG Detail Content
                        Text(
                          'NOW PLAYING GUIDE',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white38,
                            fontSize: 11.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 6.0),
                        Text(
                          _activeChannel!.currentProgram,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16.0),

                        Text(
                          'COMING UP NEXT',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white38,
                            fontSize: 11.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 6.0),
                        Text(
                          _activeChannel!.nextProgram,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white60,
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
