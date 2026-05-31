import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';

class ChannelSelectorScreen extends StatefulWidget {
  const ChannelSelectorScreen({Key? key}) : super(key: key);

  @override
  State<ChannelSelectorScreen> createState() => _ChannelSelectorScreenState();
}

class _ChannelSelectorScreenState extends State<ChannelSelectorScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _chats = [];
  
  // Map of chat ID -> selected category: 'off', 'movie', 'tv', 'anime'
  final Map<String, String> _selections = {};

  // Tab & Search state
  String _activeTab = 'mine'; // 'mine' (Created) or 'all' (All Joined)
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchChatsAndLoadPreferences();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchChatsAndLoadPreferences() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Fetch active Telegram dialogs from backend
      final response = await Dio().get(
        "${ApiService.baseUrl}/telegram/chats",
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final fetchedChats = response.data['chats'] as List<dynamic>;
        
        // 2. Load pre-existing saved dynamic channels from SharedPreferences (multi-select list)
        final prefs = await SharedPreferences.getInstance();
        final savedMovies = prefs.getStringList('telegram_channels_movie') ?? [];
        final savedTv = prefs.getStringList('telegram_channels_tv') ?? [];
        final savedAnime = prefs.getStringList('telegram_channels_anime') ?? [];

        setState(() {
          _chats = fetchedChats;
          for (var chat in _chats) {
            final chatId = chat['id'].toString();
            if (savedMovies.contains(chatId)) {
              _selections[chatId] = 'movie';
            } else if (savedTv.contains(chatId)) {
              _selections[chatId] = 'tv';
            } else if (savedAnime.contains(chatId)) {
              _selections[chatId] = 'anime';
            } else {
              _selections[chatId] = 'off';
            }
          }
          
          // Smart switch: if 'My Channels' is empty, automatically open 'All Dialogs'
          final hasMine = _chats.any((c) => c['isCreator'] == true);
          if (!hasMine) {
            _activeTab = 'all';
          }
          
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.data['error'] ?? "Failed to query Telegram chats.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Connection error. Double check that the Telegram Gateway is online.";
        _isLoading = false;
      });
    }
  }

  Future<void> _saveChannels() async {
    setState(() {
      _isLoading = true;
    });

    final List<Map<String, String>> activeChannels = [];
    final List<String> movieIds = [];
    final List<String> tvIds = [];
    final List<String> animeIds = [];

    _selections.forEach((chatId, category) {
      if (category != 'off') {
        final chat = _chats.firstWhere((c) => c['id'].toString() == chatId, orElse: () => null);
        if (chat != null) {
          activeChannels.add({
            'id': chatId,
            'type': category,
            'name': chat['title'] ?? 'Unnamed Channel'
          });

          if (category == 'movie') movieIds.add(chatId);
          if (category == 'tv') tvIds.add(chatId);
          if (category == 'anime') animeIds.add(chatId);
        }
      }
    });

    try {
      // 1. Sync dynamic channel configurations with backend server
      final response = await Dio().post(
        "${ApiService.baseUrl}/telegram/channels",
        data: {'channels': activeChannels},
        options: Options(headers: {"Content-Type": "application/json"}),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // 2. Persist configurations in local SharedPreferences for app startup scans
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('telegram_channels_movie', movieIds);
        await prefs.setStringList('telegram_channels_tv', tvIds);
        await prefs.setStringList('telegram_channels_anime', animeIds);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Telegram Library Channels synced successfully! Scanning has started in the background.",
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.greenAccent,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        setState(() {
          _errorMessage = response.data['error'] ?? "Failed to sync channels.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Network gateway error syncing channels.";
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredChats {
    return _chats.where((chat) {
      // 1. Search Query filter
      final title = (chat['title'] ?? '').toString().toLowerCase();
      final matchesSearch = _searchQuery.isEmpty || title.contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      // 2. Creator tab filter
      if (_activeTab == 'mine') {
        final isCreator = chat['isCreator'] ?? false;
        return isCreator;
      }
      return true; // 'all' shows all dialogs
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = const Color(0xFFFFD700);

    final filtered = _filteredChats;

    return Scaffold(
      backgroundColor: const Color(0xFF070708),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        centerTitle: true,
        title: Text(
          "LIBRARY CHAT SELECTOR",
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
      ),
      body: Stack(
        children: [
          // Background ambient gold glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withOpacity(0.04),
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
                // Info Banner
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Text(
                    "Select which channels Cinegram scans for media. Unlike before, you can now toggle multiple channels for Movies or Series at the same time!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.0,
                      color: Colors.white38,
                      height: 1.4,
                    ),
                  ),
                ),

                // 1. Premium Search Bar
                Container(
                  margin: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(14.0),
                    border: Border.all(color: Colors.white.withOpacity(0.07)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14.0),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                    decoration: InputDecoration(
                      icon: Icon(Icons.search_rounded, color: accentColor, size: 20.0),
                      hintText: "Search channels or megagroups...",
                      hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 13.0),
                      border: InputBorder.none,
                    ),
                  ),
                ),

                // 2. Segmented Tab Selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      _buildTabButton('mine', 'My Channels', Icons.folder_shared_rounded),
                      const SizedBox(width: 12.0),
                      _buildTabButton('all', 'All Joined', Icons.explore_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 16.0),

                // 3. Dynamic Dialog List
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: SpinKitRing(
                            color: accentColor,
                            size: 44.0,
                            lineWidth: 2.0,
                          ),
                        )
                      : _errorMessage != null
                          ? Padding(
                              padding: const EdgeInsets.all(28.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40.0),
                                  const SizedBox(height: 16.0),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13.0),
                                  ),
                                  const SizedBox(height: 24.0),
                                  ElevatedButton.icon(
                                    onPressed: _fetchChatsAndLoadPreferences,
                                    icon: const Icon(Icons.refresh_rounded, color: Colors.black),
                                    label: Text("Retry Dialog Fetch", style: GoogleFonts.plusJakartaSans(color: Colors.black, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accentColor,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                                    ),
                                  )
                                ],
                              ),
                            )
                          : filtered.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.folder_open_rounded, color: Colors.white24, size: 48.0),
                                      const SizedBox(height: 16.0),
                                      Text(
                                        _searchQuery.isNotEmpty 
                                            ? "No channels match your search."
                                            : (_activeTab == 'mine' 
                                                ? "You haven't created any private channels." 
                                                : "No Telegram channels found."),
                                        style: GoogleFonts.plusJakartaSans(color: Colors.white30, fontSize: 13.5),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final chat = filtered[index];
                                    final chatId = chat['id'].toString();
                                    final title = chat['title'] ?? 'Unnamed Chat';
                                    final isChannel = chat['isChannel'] ?? false;
                                    final isCreator = chat['isCreator'] ?? false;
                                    final unreadCount = chat['unreadCount'] ?? 0;
                                    final currentSelect = _selections[chatId] ?? 'off';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12.0),
                                      padding: const EdgeInsets.all(16.0),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.015),
                                        borderRadius: BorderRadius.circular(16.0),
                                        border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                                                      padding: const EdgeInsets.all(8.0),
                                                      decoration: BoxDecoration(
                                                        color: isCreator 
                                                            ? accentColor.withOpacity(0.1) 
                                                            : (isChannel 
                                                                ? Colors.purpleAccent.withOpacity(0.08) 
                                                                : Colors.tealAccent.withOpacity(0.08)),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        isCreator 
                                                            ? Icons.star_rounded 
                                                            : (isChannel ? Icons.campaign_rounded : Icons.forum_rounded),
                                                        color: isCreator 
                                                            ? accentColor 
                                                            : (isChannel ? Colors.purpleAccent : Colors.tealAccent),
                                                        size: 16.0,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12.0),
                                                    Expanded(
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
                                                              fontSize: 14.0,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 2.0),
                                                          Text(
                                                            isCreator 
                                                                ? "Created by Me (Private)" 
                                                                : (isChannel ? "Telegram Channel" : "Megagroup Chat"),
                                                            style: GoogleFonts.plusJakartaSans(
                                                              color: isCreator ? accentColor.withOpacity(0.6) : Colors.white30,
                                                              fontSize: 10.0,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (unreadCount > 0)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                                  decoration: BoxDecoration(
                                                    color: accentColor.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8.0),
                                                  ),
                                                  child: Text(
                                                    "$unreadCount new",
                                                    style: GoogleFonts.plusJakartaSans(
                                                      color: accentColor,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 9.0,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 16.0),
                                          
                                          // Category Selection Pills
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              _buildCategoryPill('off', 'Disabled', currentSelect, chatId, accentColor),
                                              _buildCategoryPill('movie', 'Movies', currentSelect, chatId, Colors.amberAccent),
                                              _buildCategoryPill('tv', 'TV Shows', currentSelect, chatId, Colors.cyanAccent),
                                              _buildCategoryPill('anime', 'Anime', currentSelect, chatId, Colors.pinkAccent),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                ),

                // Save Action Button
                if (!_isLoading && _errorMessage == null)
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48.0,
                      child: ElevatedButton.icon(
                        onPressed: _saveChannels,
                        icon: const Icon(Icons.sync_rounded, color: Colors.black),
                        label: Text(
                          "Save & Sync Channels",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.0,
                            color: Colors.black,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          elevation: 8.0,
                          shadowColor: accentColor.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tab, String label, IconData icon) {
    final bool isActive = _activeTab == tab;
    final activeColor = const Color(0xFFFFD700);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeTab = tab;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          decoration: BoxDecoration(
            color: isActive ? activeColor.withOpacity(0.12) : Colors.white.withOpacity(0.015),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: isActive ? activeColor.withOpacity(0.4) : Colors.white.withOpacity(0.05),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14.0, color: isActive ? activeColor : Colors.white54),
              const SizedBox(width: 8.0),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? activeColor : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPill(String value, String label, String currentSelect, String chatId, Color activeColor) {
    final bool isSelected = currentSelect == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            // Toggles between selected value and off (multi-select, no 1:1 lock)
            _selections[chatId] = (isSelected && value != 'off') ? 'off' : value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3.0),
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.12) : Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(
              color: isSelected ? activeColor.withOpacity(0.4) : Colors.white.withOpacity(0.04),
              width: 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: isSelected ? activeColor : Colors.white54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 11.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
