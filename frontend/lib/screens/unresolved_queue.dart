import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';

class UnresolvedQueueScreen extends StatefulWidget {
  const UnresolvedQueueScreen({Key? key}) : super(key: key);

  @override
  State<UnresolvedQueueScreen> createState() => _UnresolvedQueueScreenState();
}

class _UnresolvedQueueScreenState extends State<UnresolvedQueueScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _unresolvedListings = [];

  @override
  void initState() {
    super.initState();
    _fetchUnresolvedListings();
  }

  Future<void> _fetchUnresolvedListings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Dio().get("${ApiService.baseUrl}/listings/unresolved");
      if (response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          _unresolvedListings = response.data['listings'] as List<dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.data['error'] ?? "Failed to fetch unresolved queue.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Network gateway connection failed. Double check API Base URL.";
        _isLoading = false;
      });
    }
  }

  void _showResolutionSheet(BuildContext context, Map<String, dynamic> listing) {
    final TextEditingController searchController = TextEditingController(
      text: _extractInitialQuery(listing['title'] ?? '')
    );
    bool isSearchingCandidates = false;
    List<dynamic> candidates = [];
    String? searchError;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (stateContext, setSheetState) {
            final theme = Theme.of(stateContext);
            final primaryColor = theme.primaryColor;

            Future<void> fetchCandidates(String query) async {
              setSheetState(() {
                isSearchingCandidates = true;
                searchError = null;
              });

              try {
                final response = await Dio().get(
                  "${ApiService.baseUrl}/listings/search-candidates",
                  queryParameters: {
                    'query': query,
                    'type': listing['type'] ?? 'movie'
                  },
                );

                if (response.statusCode == 200 && response.data['success'] == true) {
                  setSheetState(() {
                    candidates = response.data['candidates'] as List<dynamic>;
                    isSearchingCandidates = false;
                  });
                } else {
                  setSheetState(() {
                    searchError = response.data['error'] ?? "No candidates found.";
                    isSearchingCandidates = false;
                  });
                }
              } catch (e) {
                setSheetState(() {
                  searchError = "Error connecting to TMDB candidates proxy.";
                  isSearchingCandidates = false;
                });
              }
            }

            // Fetch initial candidates if list is empty and search query is pre-filled
            if (candidates.isEmpty && !isSearchingCandidates && searchError == null && searchController.text.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                fetchCandidates(searchController.text);
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(stateContext).viewInsets.bottom,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30.0)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.75,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F12).withOpacity(0.95),
                      border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1.5),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                    child: Column(
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
                        const SizedBox(height: 16.0),
                        Text(
                          "RESOLVE LIBRARY MATCH",
                          style: GoogleFonts.cinzel(
                            fontSize: 18.0,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          "Filename: ${listing['title']}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white38,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 20.0),

                        // Search Bar
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(color: Colors.white12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: searchController,
                                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14.0),
                                  decoration: InputDecoration(
                                    hintText: "Enter Movie/TV Show title...",
                                    hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 13.0),
                                    border: InputBorder.none,
                                  ),
                                  onSubmitted: (val) {
                                    if (val.trim().isNotEmpty) {
                                      fetchCandidates(val.trim());
                                    }
                                  },
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.search_rounded, color: primaryColor),
                                onPressed: () {
                                  final q = searchController.text.trim();
                                  if (q.isNotEmpty) {
                                    fetchCandidates(q);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20.0),

                        // Candidates Area (Carousel / Cards)
                        Expanded(
                          child: isSearchingCandidates
                              ? Center(
                                  child: SpinKitFadingCircle(
                                    color: primaryColor,
                                    size: 40.0,
                                  ),
                                )
                              : searchError != null
                                  ? Center(
                                      child: Text(
                                        searchError!,
                                        style: GoogleFonts.plusJakartaSans(color: Colors.white30, fontSize: 13.0),
                                      ),
                                    )
                                  : candidates.isEmpty
                                      ? Center(
                                          child: Text(
                                            "Enter a search query to search TMDB candidates.",
                                            style: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 12.0),
                                          ),
                                        )
                                      : ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          physics: const BouncingScrollPhysics(),
                                          itemCount: candidates.length,
                                          itemBuilder: (context, index) {
                                            final candidate = candidates[index];
                                            final tmdbId = candidate['tmdbId'].toString();
                                            final title = candidate['title'] ?? 'Unnamed';
                                            final year = candidate['year'] ?? '';
                                            final overview = candidate['overview'] ?? '';
                                            final posterPath = candidate['posterPath'];

                                            return Tooltip(
                                              message: overview.isNotEmpty ? overview : "No overview available.",
                                              preferBelow: false,
                                              textStyle: GoogleFonts.plusJakartaSans(
                                                color: Colors.white,
                                                fontSize: 12.0,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.95),
                                                borderRadius: BorderRadius.circular(12.0),
                                                border: Border.all(color: Colors.white.withOpacity(0.15)),
                                              ),
                                              padding: const EdgeInsets.all(12.0),
                                              margin: const EdgeInsets.symmetric(horizontal: 20.0),
                                              child: GestureDetector(
                                                onTap: () async {
                                                  // Trigger Resolution sync
                                                  Navigator.pop(sheetCtx); // Close sheet
                                                  await _resolveListing(listing['id'], tmdbId, listing['type'] ?? 'movie', title);
                                                },
                                                child: Container(
                                                  width: 160.0,
                                                  margin: const EdgeInsets.only(right: 14.0, bottom: 8.0),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.02),
                                                    borderRadius: BorderRadius.circular(16.0),
                                                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(16.0),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Expanded(
                                                          child: posterPath != null
                                                              ? CachedNetworkImage(
                                                                  imageUrl: posterPath,
                                                                  fit: BoxFit.cover,
                                                                  width: double.infinity,
                                                                  placeholder: (context, url) => Container(
                                                                    color: Colors.white.withOpacity(0.02),
                                                                    child: const Center(child: SpinKitDoubleBounce(color: Colors.white24, size: 24.0)),
                                                                  ),
                                                                  errorWidget: (context, url, error) => Container(
                                                                    color: Colors.white.withOpacity(0.03),
                                                                    child: const Icon(Icons.movie_rounded, color: Colors.white24),
                                                                  ),
                                                                )
                                                              : Container(
                                                                  color: Colors.white.withOpacity(0.03),
                                                                  child: const Center(child: Icon(Icons.movie_rounded, color: Colors.white24, size: 36.0)),
                                                                ),
                                                        ),
                                                        Padding(
                                                          padding: const EdgeInsets.all(10.0),
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                title,
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: GoogleFonts.plusJakartaSans(
                                                                  color: Colors.white,
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 12.0,
                                                                ),
                                                              ),
                                                              const SizedBox(height: 2.0),
                                                              Text(
                                                                year.isNotEmpty ? year : "N/A",
                                                                style: GoogleFonts.plusJakartaSans(
                                                                  color: primaryColor,
                                                                  fontSize: 10.0,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
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
                                          },
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

  Future<void> _resolveListing(dynamic dbId, String tmdbId, String type, String title) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Dio().post(
        "${ApiService.baseUrl}/listings/resolve",
        data: {
          'id': dbId,
          'tmdbId': tmdbId,
          'type': type,
          'title': title
        },
        options: Options(headers: {"Content-Type": "application/json"}),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Successfully matched print to '$title'! 🍿",
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.greenAccent,
            ),
          );
        }
        
        // Refresh list
        _fetchUnresolvedListings();
      } else {
        setState(() {
          _errorMessage = response.data['error'] ?? "Failed to save match.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Network gateway error resolving movie listing.";
        _isLoading = false;
      });
    }
  }

  String _extractInitialQuery(String title) {
    // Basic fuzzy parser in the client to clean common release labels
    if (title.isEmpty) return "";
    String q = title.replaceAll(RegExp(r'\.(mp4|mkv|avi|mov|flv|wmv)$', caseSensitive: false), '');
    q = q.replaceAll(RegExp(r'[\._-]'), ' ');
    q = q.replaceAll(RegExp(r'\b(2160p|1080p|720p|4k|4K|bluray|dvdrip|webrip|web-dl|hevc|x264|x265|h264|h265|hdr|remux)\b', caseSensitive: false), '');
    // Pull out year if attached
    final yearMatch = RegExp(r'\b(19\d{2}|20\d{2})\b').firstMatch(q);
    if (yearMatch != null) {
      q = q.substring(0, yearMatch.start);
    }
    return q.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFF070708),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        title: Text(
          "UNRESOLVED MATCHES",
          style: GoogleFonts.cinzel(
            fontWeight: FontWeight.w900,
            fontSize: 18.0,
            color: Colors.white,
            letterSpacing: 2.0,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _fetchUnresolvedListings,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background ambient glows
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent.withOpacity(0.03),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Text(
                    "The following indexed files could not be automatically verified against TMDB. Tap any file to manually match it with official artwork and subtitles.",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.0,
                      color: Colors.white54,
                      height: 1.4,
                    ),
                  ),
                ),

                Expanded(
                  child: _isLoading
                      ? Center(
                          child: SpinKitRing(
                            color: primaryColor,
                            size: 48.0,
                            lineWidth: 2.0,
                          ),
                        )
                      : _errorMessage != null
                          ? Padding(
                              padding: const EdgeInsets.all(28.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 40.0),
                                  const SizedBox(height: 16.0),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13.0),
                                  ),
                                  const SizedBox(height: 20.0),
                                  ElevatedButton.icon(
                                    onPressed: _fetchUnresolvedListings,
                                    icon: const Icon(Icons.refresh_rounded, color: Colors.black),
                                    label: Text("Retry Load", style: GoogleFonts.plusJakartaSans(color: Colors.black, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _unresolvedListings.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20.0),
                                        decoration: BoxDecoration(
                                          color: Colors.greenAccent.withOpacity(0.05),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 48.0),
                                      ),
                                      const SizedBox(height: 16.0),
                                      Text(
                                        "All prints resolved!",
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16.0,
                                        ),
                                      ),
                                      const SizedBox(height: 6.0),
                                      Text(
                                        "Your Cinegram media catalog is 100% matched.",
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white30,
                                          fontSize: 12.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  itemCount: _unresolvedListings.length,
                                  itemBuilder: (context, index) {
                                    final listing = _unresolvedListings[index];
                                    final title = listing['title'] ?? 'Unknown Print';
                                    final type = listing['type'] ?? 'movie';
                                    final quality = listing['quality'] ?? '1080p';
                                    final date = listing['created_at'] != null 
                                        ? listing['created_at'].toString().split('T')[0] 
                                        : '';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12.0),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.02),
                                        borderRadius: BorderRadius.circular(16.0),
                                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                        leading: Container(
                                          padding: const EdgeInsets.all(10.0),
                                          decoration: BoxDecoration(
                                            color: Colors.amberAccent.withOpacity(0.06),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.amberAccent.withOpacity(0.2)),
                                          ),
                                          child: const Icon(Icons.question_mark_rounded, color: Colors.amberAccent, size: 20.0),
                                        ),
                                        title: Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14.0,
                                          ),
                                        ),
                                        subtitle: Row(
                                          children: [
                                            Text(
                                              type.toUpperCase(),
                                              style: GoogleFonts.plusJakartaSans(
                                                color: Colors.white30,
                                                fontSize: 10.0,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 8.0),
                                            Container(
                                              width: 3.0,
                                              height: 3.0,
                                              decoration: const BoxDecoration(
                                                color: Colors.white12,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8.0),
                                            Text(
                                              quality.toUpperCase(),
                                              style: GoogleFonts.plusJakartaSans(
                                                color: primaryColor,
                                                fontSize: 10.0,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (date.isNotEmpty) ...[
                                              const SizedBox(width: 8.0),
                                              Text(
                                                "•  $date",
                                                style: GoogleFonts.plusJakartaSans(
                                                  color: Colors.white24,
                                                  fontSize: 10.0,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 14.0),
                                        onTap: () => _showResolutionSheet(context, listing),
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
    );
  }
}
