import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/media_item.dart';
import '../widgets/glassmorphic_card.dart';
import 'details.dart';
import '../services/api_service.dart';
import '../services/voice_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedFilter = "All"; // 'All' | 'Movie' | 'TV Show' | 'Anime'
  bool _isLoading = false;
  Timer? _debounce;
  List<MediaItem> _searchResults = [];

  final List<String> _filters = ["All", "Movie", "TV Show", "Anime"];

  @override
  void initState() {
    super.initState();
    _searchResults = mockMediaDatabase; // Show all initially as trending
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // REAL-TIME SEARCH METADATA DEBOUNCER
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    setState(() {
      _isLoading = true;
      _searchQuery = query;
    });

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _executeSemanticSearch();
    });
  }

  Future<void> _executeSemanticSearch() async {
    if (_searchQuery.trim().isEmpty) {
      setState(() {
        _searchResults = mockMediaDatabase;
        _isLoading = false;
      });
      return;
    }
    
    try {
      final items = await ApiService.semanticSearch(_searchQuery);
      
      // Filter by Type
      List<MediaItem> filtered = items;
      if (_selectedFilter != "All") {
        filtered = items.where((item) => item.type == _selectedFilter).toList();
      }
      
      setState(() {
        _searchResults = filtered;
        _isLoading = false;
      });
    } catch (e) {
      _executeSearch();
    }
  }

  void _executeSearch() {
    List<MediaItem> tempResults = mockMediaDatabase;

    // Filter by Search Query (title, genres, actors)
    if (_searchQuery.isNotEmpty) {
      tempResults = tempResults.where((item) {
        final matchesTitle = item.title.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesGenre = item.genres.any((g) => g.toLowerCase().contains(_searchQuery.toLowerCase()));
        final matchesCast = item.cast.any((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()));
        return matchesTitle || matchesGenre || matchesCast;
      }).toList();
    }

    // Filter by Type
    if (_selectedFilter != "All") {
      tempResults = tempResults.where((item) => item.type == _selectedFilter).toList();
    }

    setState(() {
      _searchResults = tempResults;
      _isLoading = false;
    });
  }

  void _startVoiceSearch() {
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
            _searchQuery = result;
            _isLoading = true;
          });
          _executeSemanticSearch();
        }
      },
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: 280.0,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F11).withOpacity(0.95),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32.0),
                  topRight: Radius.circular(32.0),
                ),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.08), width: 1.0),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32.0),
                  topRight: Radius.circular(32.0),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40.0,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                    const SizedBox(height: 28.0),
                    Text(
                      "Listening to your voice...",
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      "Describe what you want to watch (e.g. Christopher Nolan)",
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white30,
                        fontSize: 12.0,
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
                            final height = 10.0 + (db * (1.0 - factor * 0.2)).clamp(10.0, 75.0);
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              margin: const EdgeInsets.symmetric(horizontal: 4.0),
                              width: 6.0,
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
                                borderRadius: BorderRadius.circular(3.0),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 36.0),
                    GestureDetector(
                      onTap: () {
                        voiceService.stopListening();
                        voiceService.removeListener(listener);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(20.0),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Text(
                          "Cancel",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
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

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged("");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070708),
      body: SafeArea(
        child: Column(
          children: [
            // 1. FLOATING SEARCH HEADER BAR
            _buildSearchInputHeader(),
            
            // 2. SEARCH QUICK FILTER PILLS
            _buildFilterRow(),

            const SizedBox(height: 12.0),

            // 3. SEARCH RESULTS OR LAZY SHIMMERS
            Expanded(
              child: _isLoading 
                ? _buildShimmerGrid() 
                : _searchResults.isEmpty 
                  ? _buildEmptyState() 
                  : _buildResultsGrid(),
            ),
          ],
        ),
      ),
    );
  }

  // SEARCH FIELD WITH DYNAMIC ACTIVE BORDERS
  Widget _buildSearchInputHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 8.0),
      child: Row(
        children: [
          // Close/Back Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18.0),
            ),
          ),
          const SizedBox(width: 14.0),

          // Search Field Card
          Expanded(
            child: Container(
              height: 52.0,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: _searchQuery.isNotEmpty 
                      ? Theme.of(context).primaryColor.withOpacity(0.4) 
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14.0),
                decoration: InputDecoration(
                  hintText: "Search movies, genres, cast...",
                  hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white30, fontSize: 14.0),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 22.0),
                  suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.white70),
                          onPressed: _clearSearch,
                        )
                      : IconButton(
                          icon: Icon(Icons.mic_rounded, color: Theme.of(context).primaryColor),
                          onPressed: _startVoiceSearch,
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // FILTER CHIP PILLS ROW
  Widget _buildFilterRow() {
    return Container(
      height: 60.0,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final bool isSelected = _selectedFilter == filter;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
                _isLoading = true;
              });
              _executeSearch();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10.0),
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).primaryColor : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: isSelected 
                      ? Theme.of(context).primaryColor 
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Text(
                filter,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.black : Colors.white70,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // HIGH-DENSITY SEARCH RESULTS GRID
  Widget _buildResultsGrid() {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.66,
        crossAxisSpacing: 12.0,
        mainAxisSpacing: 16.0,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        return Hero(
          tag: 'poster_${item.id}',
          child: GlassmorphicCard(
            padding: EdgeInsets.zero,
            borderRadius: 14.0,
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => DetailsScreen(mediaItem: item),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
              );
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14.0),
                    child: CachedNetworkImage(
                      imageUrl: item.posterUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[900],
                        child: Center(
                          child: Text(
                            item.title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cinzel(fontSize: 8, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Corner premium tags (Star indicator)
                Positioned(
                  bottom: 6.0,
                  left: 6.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(5.0),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.star_rounded, color: Theme.of(context).primaryColor, size: 10.0),
                        const SizedBox(width: 2.0),
                        Text(
                          item.rating.toString(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // PREMIUM SHIMMER LAZY LOADING STATE
  Widget _buildShimmerGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.66,
        crossAxisSpacing: 12.0,
        mainAxisSpacing: 16.0,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: const Color(0xFF1E1E22).withOpacity(0.6),
          highlightColor: const Color(0xFF2A2A30).withOpacity(0.8),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E22),
              borderRadius: BorderRadius.circular(14.0),
            ),
          ),
        );
      },
    );
  }

  // BEAUTIFUL EMPTY RESULTS STATE
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 80.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 64.0,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 24.0),
            Text(
              "No Premium Findings",
              style: GoogleFonts.cinzel(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12.0),
            Text(
              "We couldn't match your query to our vault databases. Try refining keywords, looking up genre classifications, or searching actor names.",
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.0,
                color: Colors.white30,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30.0),
            ElevatedButton(
              onPressed: _clearSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              child: Text(
                "Reset Vault Search",
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13.0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
