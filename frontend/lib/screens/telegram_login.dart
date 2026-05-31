import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import 'profile_select.dart';

class TelegramLoginScreen extends StatefulWidget {
  const TelegramLoginScreen({Key? key}) : super(key: key);

  @override
  State<TelegramLoginScreen> createState() => _TelegramLoginScreenState();
}

class _TelegramLoginScreenState extends State<TelegramLoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isCodeSent = false;
  bool _isLoading = false;
  String? _phoneCodeHash;
  String? _errorMessage;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _phoneController.text = "+"; // Pre-fill with + for country code
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 5 || !phone.startsWith("+")) {
      setState(() {
        _errorMessage = "Please enter a valid country code phone number (e.g. +1234567890)";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Dio().post(
        "${ApiService.baseUrl}/telegram/login/send-code",
        data: {"phoneNumber": phone},
        options: Options(
          headers: {"Content-Type": "application/json"},
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          _isCodeSent = true;
          _phoneCodeHash = response.data['phoneCodeHash'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.data['error'] ?? "Failed to request code. Try again.";
          _isLoading = false;
        });
      }
    } catch (e) {
      String details = e.toString();
      if (e is DioException) {
        if (e.response != null) {
          final errData = e.response?.data;
          String? serverError;
          if (errData is Map) {
            serverError = errData['error']?.toString();
          }
          details = "Server response: ${serverError ?? e.response?.statusMessage ?? e.response?.statusCode}";
        } else {
          details = "Network connection failed. Verify that your backend server is running and accessible. Error: ${e.message ?? e.type.toString()}";
        }
      }
      setState(() {
        _errorMessage = "Gateway Connection Error:\n$details";
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text.trim();

    if (code.length < 4) {
      setState(() {
        _errorMessage = "Please enter the valid Telegram authentication code.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Dio().post(
        "${ApiService.baseUrl}/telegram/login/verify",
        data: {
          "phoneNumber": phone,
          "phoneCodeHash": _phoneCodeHash,
          "code": code,
          "password": password.isEmpty ? null : password
        },
        options: Options(
          headers: {"Content-Type": "application/json"},
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Authenticated! Cache locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('telegram_logged_in', true);
        await prefs.setString('telegram_session_string_cache', response.data['sessionString'] ?? 'active');
        await prefs.setString('telegram_phone', phone);

        setState(() {
          _isLoading = false;
        });

        // Navigate to profiles selection with premium transition
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const ProfileSelectScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      } else {
        setState(() {
          _errorMessage = response.data['error'] ?? "Verification failed. Try again.";
          _isLoading = false;
        });
      }
    } catch (e) {
      String details = e.toString();
      if (e is DioException) {
        if (e.response != null) {
          final errData = e.response?.data;
          String? serverError;
          if (errData is Map) {
            serverError = errData['error']?.toString();
          }
          details = "Server response: ${serverError ?? e.response?.statusMessage ?? e.response?.statusCode}";
        } else {
          details = "Network connection failed. Error: ${e.message ?? e.type.toString()}";
        }
      }
      setState(() {
        _errorMessage = "Authentication Failed:\n$details";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = const Color(0xFFFFD700);

    return Scaffold(
      backgroundColor: const Color(0xFF070708),
      body: Stack(
        children: [
          // Background ambient glows
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withOpacity(0.06),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo / Title
                      Icon(Icons.tv_rounded, size: 54.0, color: accentColor),
                      const SizedBox(height: 16.0),
                      Text(
                        "CINEGRAM",
                        style: GoogleFonts.cinzel(
                          fontSize: 28.0,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 4.0,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        "CONNECT TELEGRAM GATEWAY",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.0,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      Text(
                        "Synchronize, scan, and stream digital files directly from your Telegram channels to the built-in video player.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.0,
                          color: Colors.white38,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 40.0),

                      // Input Box Card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 28.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F0F12).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(24.0),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.04),
                              blurRadius: 30.0,
                              spreadRadius: 2.0,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12.0),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18.0),
                                    const SizedBox(width: 10.0),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontSize: 12.0),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20.0),
                            ],

                            if (!_isCodeSent) ...[
                              // Phone Number Input Flow
                              Text(
                                "PHONE NUMBER",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(color: Colors.white12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                                child: TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    hintText: "+1234567890",
                                    hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 15.0),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24.0),
                              
                              // Action Button
                              SizedBox(
                                width: double.infinity,
                                height: 48.0,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _sendCode,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentColor,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SpinKitThreeBounce(color: Colors.black, size: 20.0)
                                      : Text(
                                          "Send Verification Code",
                                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14.0),
                                        ),
                                ),
                              ),
                              if (_isLoading) ...[
                                const SizedBox(height: 12.0),
                                Center(
                                  child: Text(
                                    "Waking up backend gateway on Render...\n(Render free servers cold-start can take up to 60s) 🍿",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: accentColor.withOpacity(0.7),
                                      fontSize: 11.0,
                                      height: 1.4,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ] else ...[
                              // Verification Code Input Flow
                              Text(
                                "VERIFICATION CODE",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(color: Colors.white12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                                child: TextField(
                                  controller: _codeController,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 18.0, fontWeight: FontWeight.bold, letterSpacing: 6.0),
                                  decoration: InputDecoration(
                                    hintText: "•••••",
                                    hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 16.0, letterSpacing: 4.0),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20.0),

                              // 2FA Password Input (Optional)
                              Text(
                                "2FA CLOUD PASSWORD (OPTIONAL)",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white30,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(color: Colors.white12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                                child: TextField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 14.0),
                                  decoration: InputDecoration(
                                    hintText: "Enter 2FA password if enabled",
                                    hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 13.0),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24.0),

                              // Verify Action Button
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          _isCodeSent = false;
                                          _codeController.clear();
                                          _passwordController.clear();
                                        });
                                      },
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Colors.white24),
                                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12.0),
                                        ),
                                      ),
                                      child: Text(
                                        "Back",
                                        style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12.0),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _verifyCode,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: accentColor,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12.0),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SpinKitThreeBounce(color: Colors.black, size: 20.0)
                                          : Text(
                                              "Verify & Sync",
                                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_isLoading) ...[
                                const SizedBox(height: 12.0),
                                Center(
                                  child: Text(
                                    "Waking up backend gateway on Render...\n(Render free servers cold-start can take up to 60s) 🍿",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: accentColor.withOpacity(0.7),
                                      fontSize: 11.0,
                                      height: 1.4,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24.0),
                      TextButton.icon(
                        onPressed: () async {
                          // Bypasses Telegram login for preview/explore mode
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('telegram_logged_in', false);
                          await prefs.setString('telegram_phone', 'Guest Explorer');
                          
                          if (!mounted) return;
                          Navigator.of(context).pushReplacement(
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) => const ProfileSelectScreen(),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                return FadeTransition(opacity: animation, child: child);
                              },
                              transitionDuration: const Duration(milliseconds: 600),
                            ),
                          );
                        },
                        icon: Icon(Icons.auto_awesome_rounded, color: accentColor.withOpacity(0.8), size: 16.0),
                        label: Text(
                          "Explore App & Settings First",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.0,
                            letterSpacing: 0.5,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
