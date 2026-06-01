import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../widgets/glassmorphic_card.dart';
import '../services/download_manager.dart';
import '../services/api_service.dart';
import '../services/external_player_service.dart';
import 'tv_player.dart';

class DetailsScreen extends StatefulWidget {
  final MediaItem mediaItem;

  const DetailsScreen({
    Key? key,
    required this.mediaItem,
  }) : super(key: key);

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> with SingleTickerProviderStateMixin {
  bool _isLiked = false;
  late AnimationController _playBtnController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _playBtnController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _playBtnController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _playBtnController.dispose();
    super.dispose();
  }

  // NAVIGATE TO THE PREMIUM TV-OPTIMIZED REMOTE-FRIENDLY PLAYER
  void _startPlayback(BuildContext context) async {
    final alwaysUse = await ExternalPlayerService.isExternalPlayerEnabled();
    final defaultPackage = await ExternalPlayerService.getSelectedPlayerPackage();
    
    if (alwaysUse && defaultPackage != null) {
      _launchInExternalPlayer(context);
      return;
    }

    if (!context.mounted) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            TvPlayerScreen(
              mediaItem: widget.mediaItem,
              channelId: widget.mediaItem.channelId,
              messageId: widget.mediaItem.messageId,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _launchInExternalPlayer(BuildContext context) async {
    final item = widget.mediaItem;
    final downloadManager = Provider.of<DownloadManager>(context, listen: false);
    final downloadedTask = downloadManager.getTask(item.id);

    // Resolve URL / Local file path
    String streamUrl = '';
    if (downloadedTask != null && downloadedTask.status == 'completed') {
      streamUrl = downloadedTask.localPath;
    } else {
      // Resolve dynamic Telegram channels/message details, falling back to static mocks if needed
      final channelId = item.channelId ?? (item.id == 'm1' ? '-100192837482' : (item.id == 'm2' ? '-100192837482' : (item.id == 'a1' ? '-100192837482' : '-100192837482')));
      final messageId = item.messageId ?? (item.id == 'm1' ? '401' : (item.id == 'm2' ? '402' : (item.id == 'a1' ? '403' : '404')));
      streamUrl = '${ApiService.baseUrl}/stream?channelId=$channelId&messageId=$messageId';
    }

    // Get default configured player package
    final defaultPackage = await ExternalPlayerService.getSelectedPlayerPackage();
    
    // If the user already has a default chosen AND "Always Use" is enabled, launch immediately!
    final alwaysUse = await ExternalPlayerService.isExternalPlayerEnabled();
    if (alwaysUse && defaultPackage != null) {
      final success = await ExternalPlayerService.launchPlayer(defaultPackage, streamUrl, item.title);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Launching in default external player..."),
            backgroundColor: const Color(0xFF121215),
          ),
        );
      }
      return;
    }

    // Show beautiful bottom sheet of detected players to choose from!
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
                        "PLAY WITH EXTERNAL PLAYER",
                        style: GoogleFonts.cinzel(
                          fontSize: 18.0,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        "Choose an external media app to play '${item.title}'",
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
                                    final ok = await ExternalPlayerService.launchPlayer(package, streamUrl, item.title);
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final item = widget.mediaItem;
    final downloadManager = Provider.of<DownloadManager>(context);
    final downloadTask = downloadManager.getTask(item.id);

    // Filter relevant recommendations of similar type
    final suggestions = mockMediaDatabase.where((m) => m.type == item.type && m.id != item.id).toList();

    return Scaffold(
      body: Stack(
        children: [
          // 1. GIANT DYNAMIC BLURRED BACKDROP BACKGROUND
          Positioned.fill(
            child: Container(
              color: const Color(0xFF070708),
            ),
          ),
          
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.55,
            child: Stack(
              children: [
                // Sharp backdrop
                Positioned.fill(
                  child: Hero(
                    tag: 'poster_${item.id}',
                    child: CachedNetworkImage(
                      imageUrl: item.backdropUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
                    ),
                  ),
                ),
                
                // Translucent golden overlay tint & gradient blur
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF070708).withOpacity(0.2),
                          const Color(0xFF070708).withOpacity(0.6),
                          const Color(0xFF070708),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. SCROLLABLE DETAILS SHEET
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: size.height * 0.32),
                  
                  // MAIN INFO PANEL (Glassmorphic)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          item.title,
                          style: GoogleFonts.cinzel(
                            fontSize: 34.0,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 14.0),

                        // METADATA ROW WITH PREMIUM BADGES (4K, Dolby Vision)
                        Row(
                          children: [
                            // Dynamic star rating
                            Icon(Icons.star_rounded, color: Theme.of(context).primaryColor, size: 20.0),
                            const SizedBox(width: 6.0),
                            Text(
                              "${item.rating} / 10",
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 14.0,
                              ),
                            ),
                            const SizedBox(width: 14.0),
                            _buildVerticalDivider(),
                            const SizedBox(width: 14.0),
                            // Year
                            Text(
                              item.year,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white70,
                                fontSize: 14.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 14.0),
                            _buildVerticalDivider(),
                            const SizedBox(width: 14.0),
                            // Duration
                            Text(
                              item.duration,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white70,
                                fontSize: 14.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12.0),

                        // CAPSULE TAGS: Ultra HD, Atmos
                        Row(
                          children: [
                            _buildCapsuleTag("4K ULTRA HD"),
                            const SizedBox(width: 8.0),
                            _buildCapsuleTag("DOLBY VISION"),
                            const SizedBox(width: 8.0),
                            _buildCapsuleTag("ATMOS 7.1"),
                          ],
                        ),
                        const SizedBox(height: 24.0),

                        // MASSIVE GLASSMORPHIC PLAY FEATURE ACTION BUTTON & EXTERNAL PLAYER BUTTON
                        Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: ScaleTransition(
                                scale: _scaleAnimation,
                                child: GestureDetector(
                                  onTapDown: (_) => _playBtnController.forward(),
                                  onTapUp: (_) => _playBtnController.reverse(),
                                  onTapCancel: () => _playBtnController.reverse(),
                                  onTap: () => _startPlayback(context),
                                  child: GlassmorphicCard(
                                    padding: EdgeInsets.zero,
                                    borderRadius: 18.0,
                                    borderWidth: 1.5,
                                    isSelected: true, // Forces constant glow border
                                    enableHoverScale: false, // Custom scale animation handled locally
                                    child: Container(
                                      height: 60.0,
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(4.0),
                                            decoration: const BoxDecoration(
                                              color: Colors.black,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.play_arrow_rounded,
                                              color: Theme.of(context).primaryColor,
                                              size: 26.0,
                                            ),
                                          ),
                                          const SizedBox(width: 14.0),
                                          Text(
                                            "PLAY FEATURE",
                                            style: GoogleFonts.plusJakartaSans(
                                              color: Colors.white,
                                              fontSize: 13.0,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12.0),
                            Expanded(
                              flex: 2,
                              child: GestureDetector(
                                onTap: () => _launchInExternalPlayer(context),
                                child: GlassmorphicCard(
                                  padding: EdgeInsets.zero,
                                  borderRadius: 18.0,
                                  borderWidth: 1.2,
                                  child: Container(
                                    height: 60.0,
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.open_in_new_rounded,
                                          color: Colors.white70,
                                          size: 20.0,
                                        ),
                                        const SizedBox(height: 4.0),
                                        Text(
                                          "EXTERNAL",
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white60,
                                            fontSize: 9.0,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
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

                        const SizedBox(height: 16.0),
                        _buildDownloadControls(context, downloadManager, downloadTask),
                        const SizedBox(height: 30.0),

                        // GENRE BUBBLES
                        Text(
                          "GENRES",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.0,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 10.0),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: item.genres.map((genre) {
                            return Chip(
                              label: Text(
                                genre.toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              backgroundColor: Colors.white.withOpacity(0.04),
                              side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 30.0),

                        // SYNOPSIS
                        Text(
                          "THE SYNOPSIS",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.0,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 10.0),
                        Text(
                          item.synopsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70,
                            fontSize: 14.0,
                            height: 1.6,
                            fontWeight: FontWeight.w400,
                          ),
                        ),

                        const SizedBox(height: 30.0),

                        // CAST PROFILE BUBBLES
                        Text(
                          "HEADLINERS & CAST",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.0,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16.0),
                      ],
                    ),
                  ),

                  // Horizontal Cast list
                  _buildCastList(item.cast),

                  const SizedBox(height: 40.0),

                  // SUGGESTIONS ROW
                  if (suggestions.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 16.0),
                      child: Text(
                        "MORE LIKE THIS",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    _buildSuggestionsRow(suggestions),
                  ],

                  // Bottom padding
                  const SizedBox(height: 100.0),
                ],
              ),
            ),
          ),

          // BACK BUTTON & FAVORITE FLOATING GLASS HEADER
          _buildFloatingHeader(context),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1.0,
      height: 14.0,
      color: Colors.white24,
    );
  }

  Widget _buildCapsuleTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 0.8),
        borderRadius: BorderRadius.circular(5.0),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
          color: Colors.white70,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // FLOATING BACK AND ACTIONS APPMAR
  Widget _buildFloatingHeader(BuildContext context) {
    return Positioned(
      top: 40.0,
      left: 16.0,
      right: 16.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Circular Glassmorphic Back Button
          ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  color: Colors.black.withOpacity(0.4),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20.0),
                ),
              ),
            ),
          ),
          
          // Circular Glassmorphic Favorite
          ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isLiked = !_isLiked;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isLiked ? "Added to My Premium Vault" : "Removed from Vault"),
                      duration: const Duration(seconds: 1),
                      backgroundColor: const Color(0xFF121215),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  color: Colors.black.withOpacity(0.4),
                  child: Icon(
                    _isLiked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: _isLiked ? Theme.of(context).primaryColor : Colors.white,
                    size: 20.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // CAST PROFILE BUBBLES SCROLLER
  Widget _buildCastList(List<CastMember> cast) {
    return Container(
      height: 120.0,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        itemCount: cast.length,
        itemBuilder: (context, index) {
          final actor = cast[index];
          return Container(
            margin: const EdgeInsets.only(right: 20.0),
            child: Column(
              children: [
                // Profile Circular Image with glowing dynamic ring
                Container(
                  width: 65.0,
                  height: 65.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.35), width: 1.5),
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(actor.imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 8.0),
                
                // Real Name
                Text(
                  actor.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2.0),

                // Character Role
                Text(
                  actor.role,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    color: Colors.white30,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // RECOMMENDATION LIST VIEW
  Widget _buildSuggestionsRow(List<MediaItem> list) {
    return Container(
      height: 190.0,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final item = list[index];
          return Container(
            margin: const EdgeInsets.only(right: 14.0),
            width: 110.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: GlassmorphicCard(
                    padding: EdgeInsets.zero,
                    borderRadius: 12.0,
                    onTap: () {
                      Navigator.pushReplacement(
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: CachedNetworkImage(
                        imageUrl: item.posterUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6.0),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDownloadControls(
      BuildContext context, DownloadManager downloadManager, DownloadTask? task) {
    final theme = Theme.of(context);
    final item = widget.mediaItem;

    // Helper to get simulated channel/message details for testing
    String getChannelId() {
      if (item.id == 'm1') return '-100192837482';
      if (item.id == 'm2') return '-100192837482';
      if (item.id == 'a1') return '-100192837482';
      return '-100192837482';
    }

    String getMessageId() {
      if (item.id == 'm1') return '401';
      if (item.id == 'm2') return '402';
      if (item.id == 'a1') return '403';
      return '404';
    }

    if (task == null) {
      // 1. Initial State: Download Button
      return GestureDetector(
        onTap: () {
          downloadManager.startDownload(item, getChannelId(), getMessageId());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Starting offline download for ${item.title}..."),
              backgroundColor: theme.primaryColor.withOpacity(0.9),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: GlassmorphicCard(
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
          borderRadius: 14.0,
          borderWidth: 1.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.download_for_offline_rounded, color: theme.primaryColor, size: 20.0),
              const SizedBox(width: 10.0),
              Text(
                "SECURE OFFLINE COPY IN VAULT",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Active Downloading State
    if (task.status == 'downloading') {
      return GlassmorphicCard(
        padding: const EdgeInsets.all(16.0),
        borderRadius: 14.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "DOWNLOADING DIGITAL PRINT",
                  style: GoogleFonts.plusJakartaSans(
                    color: theme.primaryColor,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  task.speed,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white30,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10.0),
            // Glowing dynamic linear progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4.0),
              child: LinearProgressIndicator(
                value: task.progress,
                backgroundColor: Colors.white.withOpacity(0.06),
                valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                minHeight: 6.0,
              ),
            ),
            const SizedBox(height: 12.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${(task.progress * 100).toStringAsFixed(1)}% Completed",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 11.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () => downloadManager.pauseDownload(item.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.pause_rounded, color: Colors.white, size: 14.0),
                        const SizedBox(width: 4.0),
                        Text(
                          "PAUSE",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
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
      );
    }

    // 3. Paused State
    if (task.status == 'paused') {
      return GlassmorphicCard(
        padding: const EdgeInsets.all(14.0),
        borderRadius: 14.0,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "DOWNLOAD PAUSED",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white30,
                      fontSize: 10.0,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    "${(task.progress * 100).toStringAsFixed(0)}% Cached in Vault",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                // Resume button
                GestureDetector(
                  onTap: () => downloadManager.startDownload(item, getChannelId(), getMessageId()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.play_arrow_rounded, color: theme.primaryColor, size: 14.0),
                        const SizedBox(width: 4.0),
                        Text(
                          "RESUME",
                          style: GoogleFonts.plusJakartaSans(
                            color: theme.primaryColor,
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                // Delete button
                GestureDetector(
                  onTap: () => downloadManager.deleteDownload(item.id),
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 14.0),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 4. Completed State
    if (task.status == 'completed') {
      return GlassmorphicCard(
        padding: const EdgeInsets.all(14.0),
        borderRadius: 14.0,
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6.0),
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E676),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.black, size: 14.0),
                  ),
                  const SizedBox(width: 12.0),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "OFFLINE PRINT SECURED",
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF00E676),
                          fontSize: 10.0,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        "100% Offline Capable",
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Delete offline file button
            GestureDetector(
              onTap: () {
                downloadManager.deleteDownload(item.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Offline copy deleted from Vault."),
                    backgroundColor: Color(0xFF1E1E24),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 14.0),
                    const SizedBox(width: 4.0),
                    Text(
                      "REMOVE FILE",
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.redAccent,
                        fontSize: 10.0,
                        fontWeight: FontWeight.bold,
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

    // 5. Failed State
    return GlassmorphicCard(
      padding: const EdgeInsets.all(14.0),
      borderRadius: 14.0,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "DOWNLOAD INTEGRITY FAILURE",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.redAccent,
                    fontSize: 10.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  "Please check your server connection.",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => downloadManager.startDownload(item, getChannelId(), getMessageId()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.refresh_rounded, color: theme.primaryColor, size: 14.0),
                  const SizedBox(width: 4.0),
                  Text(
                    "RETRY",
                    style: GoogleFonts.plusJakartaSans(
                      color: theme.primaryColor,
                      fontSize: 10.0,
                      fontWeight: FontWeight.bold,
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
}
