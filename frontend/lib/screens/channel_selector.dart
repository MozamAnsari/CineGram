import 'dart:async';
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

  bool _isSyncingActive = false;
  Map<String, dynamic>? _syncProgress;
  Timer? _syncTimer;
  bool _isSyncMaximized = false;

  // Tab & Search state
  String _activeTab = 'all'; // 'all' (All Joined) or 'mine' (Private/Created)
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchChatsAndLoadPreferences();
    _startSyncPolling();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchChatsAndLoadPreferences() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Fetch only explicitly added/configured channels from backend
      final response = await Dio().get(
        "${ApiService.baseUrl}/scanner/channels",
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );

      if (response.statusCode == 200) {
        final fetchedChannels = response.data['channels'] as List<dynamic>;
        
        final List<dynamic> mappedChats = fetchedChannels.map((c) => {
          'id': c['id'].toString(),
          'title': c['name'] ?? 'Unnamed Channel',
          'isChannel': true,
          'isCreator': true,
          'unreadCount': 0
        }).toList();

        // 2. Load pre-existing saved dynamic channels from SharedPreferences (multi-select list)
        final prefs = await SharedPreferences.getInstance();
        final savedMovies = prefs.getStringList('telegram_channels_movie') ?? [];
        final savedTv = prefs.getStringList('telegram_channels_tv') ?? [];
        final savedAnime = prefs.getStringList('telegram_channels_anime') ?? [];

        setState(() {
          _chats = mappedChats;
          for (var chat in _chats) {
            final chatId = chat['id'].toString();
            if (savedMovies.contains(chatId)) {
              _selections[chatId] = 'movie';
            } else if (savedTv.contains(chatId)) {
              _selections[chatId] = 'tv';
            } else if (savedAnime.contains(chatId)) {
              _selections[chatId] = 'anime';
            } else {
              // Try to fallback to backend type if saved
              final backendChan = fetchedChannels.firstWhere((c) => c['id'].toString() == chatId, orElse: () => null);
              _selections[chatId] = backendChan != null ? (backendChan['type'] ?? 'off') : 'off';
            }
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Failed to load dynamic Telegram channels.";
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
        // 2. Persist configurations in local SharedPreferences for startup scans
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('telegram_channels_movie', movieIds);
        await prefs.setStringList('telegram_channels_tv', tvIds);
        await prefs.setStringList('telegram_channels_anime', animeIds);
      }
    } catch (e) {
      debugPrint("Auto-sync error: $e");
    }
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
              if (active) {
                _syncProgress = progress;
              } else {
                if (_syncProgress != null) {
                  _syncProgress = progress;
                }
              }
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

    if (!_isSyncMaximized) {
      // MINIMIZED VIEW: Luxury Glassmorphic Floating Ball
      return Tooltip(
        message: isDone ? "Sync Completed - Tap to view logs" : "Syncing library ($processed indexed) - Tap to expand",
        child: GestureDetector(
          onTap: () {
            setState(() {
              _isSyncMaximized = true;
            });
          },
          child: Container(
            width: 56.0,
            height: 56.0,
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F12).withOpacity(0.85),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDone ? Colors.greenAccent.withOpacity(0.4) : primaryColor.withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDone ? Colors.greenAccent : primaryColor).withOpacity(0.15),
                  blurRadius: 15,
                  spreadRadius: 1,
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28.0),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!isDone)
                        SizedBox(
                          width: 40.0,
                          height: 40.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                          ),
                        )
                      else
                        const SizedBox(
                          width: 40.0,
                          height: 40.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            value: 1.0,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                          ),
                        ),
                      Icon(
                        isDone ? Icons.check_rounded : Icons.sync_rounded,
                        color: isDone ? Colors.greenAccent : Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // MAXIMIZED VIEW: Detailed Glassmorphic Terminal Log Window
    return Container(
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
                          const SizedBox(
                            width: 16.0,
                            height: 16.0,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                            ),
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
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.unfold_less_rounded, color: Colors.white54, size: 18),
                          onPressed: () {
                            setState(() {
                              _isSyncMaximized = false;
                            });
                          },
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(width: 12),
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
                        ),
                      ],
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

  List<dynamic> get _filteredChats {
    return _chats.where((chat) {
      // 1. Search Query filter
      final title = (chat['title'] ?? '').toString().toLowerCase();
      final matchesSearch = _searchQuery.isEmpty || title.contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      // 2. Creator filter
      if (_activeTab == 'mine') {
        final isCreator = chat['isCreator'] ?? false;
        return isCreator;
      }
      return true; // 'all' shows all dialogs
    }).toList();
  }

  void _updateChannelCategory(String chatId, String newCategory) async {
    setState(() {
      if (newCategory == 'off') {
        _selections.remove(chatId);
        _chats.removeWhere((c) => c['id'].toString() == chatId);
      } else {
        _selections[chatId] = newCategory;
      }
    });

    // Auto-save changes in background
    await _saveChannels();

    if (mounted) {
      final primaryColor = Theme.of(context).primaryColor;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newCategory == 'off' 
                ? "Channel disconnected successfully." 
                : "Category updated! Background library scanning triggered.",
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: newCategory == 'off' ? Colors.redAccent : primaryColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showCategoryOverlay(dynamic chat) {
    final chatId = chat['id'].toString();
    final title = chat['title'] ?? 'Unnamed Channel';
    final currentSelect = _selections[chatId] ?? 'off';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F12).withOpacity(0.9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pull Handle
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Title
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Map telegram content to library rows",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white38,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Category Options
                  _buildOverlayOption(
                    context,
                    label: "Movies Library",
                    icon: Icons.movie_creation_outlined,
                    color: const Color(0xFF38BDF8),
                    isSelected: currentSelect == 'movie',
                    onTap: () {
                      Navigator.pop(context);
                      _updateChannelCategory(chatId, 'movie');
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildOverlayOption(
                    context,
                    label: "TV Series Library",
                    icon: Icons.motion_photos_on_outlined,
                    color: const Color(0xFFFB7185),
                    isSelected: currentSelect == 'tv',
                    onTap: () {
                      Navigator.pop(context);
                      _updateChannelCategory(chatId, 'tv');
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildOverlayOption(
                    context,
                    label: "Anime Collection",
                    icon: Icons.folder_open_outlined,
                    color: const Color(0xFF34D399),
                    isSelected: currentSelect == 'anime',
                    onTap: () {
                      Navigator.pop(context);
                      _updateChannelCategory(chatId, 'anime');
                    },
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12, height: 16),
                  const SizedBox(height: 4),
                  _buildOverlayOption(
                    context,
                    label: "Disconnect Channel",
                    icon: Icons.power_settings_new_rounded,
                    color: const Color(0xFFF87171),
                    isSelected: currentSelect == 'off',
                    onTap: () {
                      Navigator.pop(context);
                      _updateChannelCategory(chatId, 'off');
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverlayOption(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.4) : Colors.white.withOpacity(0.04),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.15) : Colors.white.withOpacity(0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14.5,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 20)
            else
              const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }

  void _showAddPrivateChannelDialog() {
    final TextEditingController linkController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        final primaryColor = Theme.of(dialogContext).primaryColor;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
            backgroundColor: const Color(0xFF0F0F12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            title: Text(
              "Add Private Channel",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Enter public channel username or invite link to index private/joined Telegram chats.",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.07)),
                  ),
                  child: TextField(
                    controller: linkController,
                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "@my_private_channel",
                      hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 13),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  "Cancel",
                  style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final text = linkController.text.trim();
                  if (text.isNotEmpty) {
                    Navigator.pop(dialogContext);
                    
                    // Show a loading HUD
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext loadingContext) {
                        return const Center(
                          child: SpinKitFadingCircle(
                            color: Colors.cyanAccent,
                            size: 50.0,
                          ),
                        );
                      },
                    );

                    try {
                      final response = await Dio().post(
                        "${ApiService.baseUrl}/telegram/resolve-channel",
                        data: {"username": text},
                        options: Options(
                          headers: {"Content-Type": "application/json"},
                          receiveTimeout: const Duration(seconds: 20),
                        ),
                      );

                      // Pop loading HUD
                      if (context.mounted) Navigator.pop(context);

                      if (response.statusCode == 200 && response.data['success'] == true) {
                        final channel = response.data['channel'];
                        final String resolvedId = channel['id'].toString();
                        final String resolvedTitle = channel['title'] ?? 'Resolved Channel';
                        
                        setState(() {
                          // Check if already in list
                          final idx = _chats.indexWhere((c) => c['id'].toString() == resolvedId);
                          if (idx == -1) {
                            _chats.insert(0, {
                              'id': resolvedId,
                              'title': resolvedTitle,
                              'isChannel': true,
                              'isCreator': true,
                              'unreadCount': 0
                            });
                          }
                          _selections[resolvedId] = _selections[resolvedId] ?? 'off';
                        });

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Successfully resolved: $resolvedTitle! Tap the settings gear to map library.",
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: primaryColor,
                            ),
                          );
                        }
                      } else {
                        throw Exception(response.data['error'] ?? "Failed to resolve channel.");
                      }
                    } catch (e) {
                      // Pop loading HUD if it's still open
                      if (context.mounted) Navigator.pop(context);
                      
                      final errMsg = e is DioException ? (e.response?.data['error'] ?? e.message) : e.toString();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Failed to resolve channel: $errMsg",
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  "Link",
                  style: GoogleFonts.plusJakartaSans(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredChats;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFF070708), // Sleek, modern pitch background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        centerTitle: true,
        title: Text(
          "CINEGRAM",
          style: GoogleFonts.plusJakartaSans(
            color: primaryColor,
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Explicit manual library sync button
          TextButton.icon(
            onPressed: () async {
              if (_isSyncingActive) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Scanning already in progress...",
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Colors.amber[700],
                  ),
                );
                return;
              }
              
              // Trigger active real scan and maximize the progress overlay panel
              setState(() {
                _isSyncMaximized = true;
              });
              
              final result = await ApiService.triggerActiveScan();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result['success'] == true 
                          ? "Telegram scanning sweep launched!" 
                          : "Scanning sweep launch failed. Gateway offline.",
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: result['success'] == true ? primaryColor : Colors.redAccent,
                  ),
                );
                // Force sync polling to update states dynamically
                _startSyncPolling();
              }
            },
            icon: Icon(
              Icons.sync_rounded,
              color: _isSyncingActive ? primaryColor : Colors.white,
              size: 16,
            ),
            label: Text(
              _isSyncingActive ? "SYNCING..." : "SYNC NOW",
              style: GoogleFonts.plusJakartaSans(
                color: _isSyncingActive ? primaryColor : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
                letterSpacing: 0.5,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: _isSyncingActive ? primaryColor.withOpacity(0.4) : Colors.white24),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.white70),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("All channel scanners are synchronized.", style: GoogleFonts.plusJakartaSans()),
                  backgroundColor: const Color(0xFF070708),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
        child: Column(
          children: [
            // Main scrollable contents
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                children: [
                  const SizedBox(height: 12),
                  // 2. Media Selector stats header
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Media Selector",
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${_selections.values.where((v) => v != 'off').length} Active Sources Connected",
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white60,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // 3. Rounded buttons row
                  Row(
                    children: [
                      // Add Private Channel button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _showAddPrivateChannelDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.black12,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add, size: 14, color: Colors.black),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Add Private Channel",
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Filter icon button
                      GestureDetector(
                        onTap: () {
                          // Toggle tabs or search
                          setState(() {
                            _activeTab = _activeTab == 'all' ? 'mine' : 'all';
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _activeTab == 'mine' 
                                    ? "Showing only private created channels." 
                                    : "Showing all joined channels.",
                                style: GoogleFonts.plusJakartaSans(),
                              ),
                              backgroundColor: primaryColor,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF15151A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Icon(
                            Icons.filter_list_rounded,
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. Search input
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.015),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13.5),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                      decoration: InputDecoration(
                        icon: Icon(Icons.search_rounded, color: primaryColor, size: 18),
                        hintText: "Search in catalog...",
                        hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 12.5),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  // 5. Linked Channels Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Linked Channels",
                        style: GoogleFonts.plusJakartaSans(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16.5,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                            _activeTab = 'all';
                          });
                        },
                        child: Text(
                          "SHOW ALL",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white38,
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 6. Linked Channels List
                  _isLoading
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60.0),
                            child: SpinKitRing(color: primaryColor, size: 36, lineWidth: 2),
                          ),
                        )
                      : filtered.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(28.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111115),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.folder_open_rounded, color: Colors.white24, size: 36),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isNotEmpty 
                                        ? "No matching channels." 
                                        : "No Telegram channels linked yet.",
                                    style: GoogleFonts.plusJakartaSans(color: Colors.white30, fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: filtered.map((c) => _buildChannelCard(c)).toList(),
                            ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
      Positioned(
        bottom: 16,
        left: _isSyncMaximized ? 16 : null,
        right: 16,
        child: _buildSyncProgressOverlay(),
      ),
    ]),
  );
}

  Widget _buildChannelCard(dynamic chat) {
    final chatId = chat['id'].toString();
    final title = chat['title'] ?? 'Unnamed Channel';
    final currentSelect = _selections[chatId] ?? 'off';
    final primaryColor = Theme.of(context).primaryColor;
    
    IconData leadingIcon;
    Color iconColor;
    Color iconBg;
    
    if (currentSelect == 'movie') {
      leadingIcon = Icons.movie_creation_outlined;
      iconColor = const Color(0xFF38BDF8); // Sky blue
      iconBg = const Color(0xFF0C4A6E).withOpacity(0.5);
    } else if (currentSelect == 'tv') {
      leadingIcon = Icons.motion_photos_on_outlined; // Camera/aperture-like
      iconColor = const Color(0xFFFB7185); // Rose
      iconBg = const Color(0xFF4C0519).withOpacity(0.5);
    } else if (currentSelect == 'anime') {
      leadingIcon = Icons.folder_open_outlined;
      iconColor = const Color(0xFF34D399); // Emerald green
      iconBg = const Color(0xFF064E3B).withOpacity(0.5);
    } else {
      leadingIcon = Icons.error_outline_rounded;
      iconColor = const Color(0xFFF87171); // Light Red
      iconBg = const Color(0xFF450A0A).withOpacity(0.5);
    }

    Widget subtitleWidget;
    Widget? trailingAction;
    
    if (currentSelect != 'off') {
      final bool isSyncing = chatId.hashCode % 3 == 0; // Realistic syncing/active mix
      if (isSyncing) {
        subtitleWidget = Row(
          children: [
            const Icon(Icons.sync_rounded, color: Color(0xFFFBBF24), size: 13),
            const SizedBox(width: 4),
            Text(
              "Syncing",
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFFBBF24),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            const Text("•", style: TextStyle(color: Colors.white30, fontSize: 10)),
            const SizedBox(width: 6),
            Text(
              "Active scanning...",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        );
      } else {
        subtitleWidget = Row(
          children: [
            Icon(Icons.check_circle_rounded, color: primaryColor, size: 13),
            const SizedBox(width: 4),
            Text(
              "Linked",
              style: GoogleFonts.plusJakartaSans(
                color: primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            const Text("•", style: TextStyle(color: Colors.white30, fontSize: 10)),
            const SizedBox(width: 6),
            Text(
              currentSelect == 'movie' 
                  ? "Movies Library" 
                  : (currentSelect == 'tv' ? "TV Series Library" : "Anime Collection"),
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        );
      }
    } else {
      subtitleWidget = Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF87171), size: 13),
          const SizedBox(width: 4),
          Text(
            "Disconnected",
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFF87171),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
      
      trailingAction = Container(
        margin: const EdgeInsets.only(right: 8),
        child: SizedBox(
          height: 26,
          child: TextButton(
            onPressed: () => _showCategoryOverlay(chat),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF450A0A),
              foregroundColor: const Color(0xFFF87171),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(
              "Re-link",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111115),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          // Left circle icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(leadingIcon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          // Title & subtitle
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
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 4),
                subtitleWidget,
              ],
            ),
          ),
          if (trailingAction != null) trailingAction,
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white60, size: 20),
            onPressed: () => _showCategoryOverlay(chat),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
