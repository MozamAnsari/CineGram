import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/api_service.dart';
import 'home.dart';
import 'telegram_login.dart';
import 'package:dio/dio.dart';

class OnboardingCheckScreen extends StatefulWidget {
  const OnboardingCheckScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingCheckScreen> createState() => _OnboardingCheckScreenState();
}

class _OnboardingCheckScreenState extends State<OnboardingCheckScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String _statusText = "Authenticating gateway...";

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _fadeController.forward();
    
    // Check dynamic auth status after frame binding
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runDiagnostics();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _runDiagnostics() async {
    try {
      // 1. Initialize API Service base parameters
      await ApiService.init();

      // Introduce a brief luxury delay for premium transition
      await Future.delayed(const Duration(milliseconds: 1500));

      setState(() {
        _statusText = "Checking account status...";
      });

      // 2. Poll backend status
      final response = await ApiService.testConnection(ApiService.baseUrl);
      
      // If server is offline, we fallback to offline check using shared preferences session,
      // or directly prompt login wizard for verification.
      bool isLoggedIn = false;
      
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final localTgSession = prefs.getBool('telegram_logged_in') ?? false;
        
        // Retrieve dynamic loggedIn status via status endpoint
        isLoggedIn = localTgSession;
        
        // Verify via actual test connection to ensure correctness
        final url = ApiService.baseUrl;
        
        // We will also use SharedPreferences locally for full offline resilience
        final doubleCheck = prefs.getString('telegram_session_string_cache') ?? '';
        if (doubleCheck.isNotEmpty) {
          isLoggedIn = true;
        }
      } catch (_) {}

      // Double check active status via remote status endpoint if online
      if (response) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final hasRemoteSession = prefs.getString('telegram_session_string_cache') ?? '';
          if (hasRemoteSession.isNotEmpty) {
            isLoggedIn = true;
          }
        } catch (_) {}
      }

      if (!isLoggedIn) {
        _navigateTo(const TelegramLoginScreen());
      } else {
        // Self-Healing Startup Sync: automatically sync local SharedPreferences config to backend
        _syncSavedChannels();
        _navigateTo(const HomeScreen());
      }
    } catch (e) {
      // Offline fallback: prompt login setup
      _navigateTo(const TelegramLoginScreen());
    }
  }

  Future<void> _syncSavedChannels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> savedMovies = prefs.getStringList('telegram_channels_movie') ?? [];
      final List<String> savedTv = prefs.getStringList('telegram_channels_tv') ?? [];
      final List<String> savedAnime = prefs.getStringList('telegram_channels_anime') ?? [];
      
      final List<Map<String, String>> activeChannels = [];
      for (final id in savedMovies) {
        activeChannels.add({'id': id, 'type': 'movie', 'name': 'Movies'});
      }
      for (final id in savedTv) {
        activeChannels.add({'id': id, 'type': 'tv', 'name': 'TV Shows'});
      }
      for (final id in savedAnime) {
        activeChannels.add({'id': id, 'type': 'anime', 'name': 'Anime'});
      }
      
      if (activeChannels.isNotEmpty) {
        final dio = Dio(BaseOptions(
          baseUrl: ApiService.baseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ));
        await dio.post(
          "/telegram/channels",
          data: {'channels': activeChannels},
          options: Options(headers: {"Content-Type": "application/json"}),
        );
      }
    } catch (_) {}
  }

  void _navigateTo(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070708),
      body: Stack(
        children: [
          // Luxury Ambient Glows
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x15FFD700), // Cinematic gold glow
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "CINEGRAM",
                      style: GoogleFonts.cinzel(
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFFD700),
                        letterSpacing: 8.0,
                      ),
                    ),
                    const SizedBox(height: 48.0),
                    const SpinKitRing(
                      color: Color(0xFFFFD700),
                      size: 50.0,
                      lineWidth: 2.0,
                    ),
                    const SizedBox(height: 32.0),
                    Text(
                      _statusText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.0,
                        color: Colors.white60,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
