import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/cinegram_theme.dart';
import '../services/api_service.dart';
import 'home.dart';

class ProfileSelectScreen extends StatefulWidget {
  const ProfileSelectScreen({Key? key}) : super(key: key);

  @override
  State<ProfileSelectScreen> createState() => _ProfileSelectScreenState();
}

class _ProfileSelectScreenState extends State<ProfileSelectScreen> with SingleTickerProviderStateMixin {
  final Map<String, String> _profileNames = {
    'Profile 1': 'Profile 1',
    'Profile 2': 'Profile 2',
    'Profile 3': 'Profile 3',
    'Profile 4': 'Profile 4',
  };

  final Map<String, String> _profileAvatars = {
    'Profile 1': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=150',
    'Profile 2': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?q=80&w=150',
    'Profile 3': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=150',
    'Profile 4': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=150',
  };

  final Map<String, String> _profilePins = {};

  String? _selectedProfileForPin;
  String _enteredPin = '';
  bool _pinError = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _loadCustomNames();
    
    // Set up shake animation for PIN error
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 12.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _shakeController.reverse();
        }
      });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomNames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        for (var role in _profileNames.keys) {
          final savedName = prefs.getString('profile_name_$role');
          if (savedName != null && savedName.isNotEmpty) {
            _profileNames[role] = savedName;
          }
          final savedAvatar = prefs.getString('profile_avatar_$role');
          if (savedAvatar != null && savedAvatar.isNotEmpty) {
            _profileAvatars[role] = savedAvatar;
          }
          
          // Load profile PIN
          final hasPin = prefs.getBool('profile_has_pin_$role') ?? (role == 'Profile 1');
          final savedPin = prefs.getString('profile_pin_$role');
          if (hasPin) {
            _profilePins[role] = (savedPin != null && savedPin.isNotEmpty) ? savedPin : '1234';
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _saveCustomName(String role, String newName) async {
    if (newName.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_name_$role', newName.trim());
      setState(() {
        _profileNames[role] = newName.trim();
      });
    } catch (_) {}
  }

  void _onProfileSelected(String role) {
    if (_profilePins.containsKey(role)) {
      setState(() {
        _selectedProfileForPin = role;
        _enteredPin = '';
        _pinError = false;
      });
    } else {
      _loginAsProfile(role);
    }
  }

  Future<void> _loginAsProfile(String role) async {
    await ApiService.setActiveProfile(_profileNames[role] ?? role);
    if (!mounted) return;
    
    // Navigate with cinematic fade transition
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _handlePinPress(String value) {
    setState(() {
      _pinError = false;
      if (value == 'delete') {
        if (_enteredPin.isNotEmpty) {
          _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        }
      } else if (value == 'submit') {
        _validatePin();
      } else {
        if (_enteredPin.length < 4) {
          _enteredPin += value;
        }
        // Auto-validate if 4 digits entered
        if (_enteredPin.length == 4) {
          _validatePin();
        }
      }
    });
  }

  void _validatePin() {
    final expectedPin = _profilePins[_selectedProfileForPin!];
    if (_enteredPin == expectedPin) {
      // Unlocked successfully
      final targetProfile = _selectedProfileForPin!;
      setState(() {
        _selectedProfileForPin = null;
      });
      _loginAsProfile(targetProfile);
    } else if (_enteredPin == '0000') {
      // Guest bypass
      final targetProfile = _selectedProfileForPin!;
      setState(() {
        _selectedProfileForPin = null;
      });
      _loginAsProfile('$targetProfile (Guest)');
    } else {
      // Error
      setState(() {
        _pinError = true;
        _enteredPin = '';
      });
      _shakeController.forward(from: 0.0);
    }
  }

  void _showRenameDialog(String role) {
    final controller = TextEditingController(text: _profileNames[role]);
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
            backgroundColor: const Color(0xFF121215),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
              side: BorderSide(color: theme.primaryColor.withOpacity(0.3)),
            ),
            title: Text(
              "Rename $role Profile",
              style: GoogleFonts.cinzel(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: TextField(
              controller: controller,
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Enter custom name",
                hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white30),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: theme.primaryColor),
                ),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "CANCEL",
                  style: GoogleFonts.plusJakartaSans(color: Colors.white60),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  _saveCustomName(role, controller.text);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: Text(
                  "SAVE",
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
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
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final accentColor = themeProvider.accentColor;

    return Scaffold(
      backgroundColor: const Color(0xFF070708),
      body: Stack(
        children: [
          // Elegant background atmospheric ambient glows
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              key: const ValueKey('ambient_glow_1'),
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withOpacity(0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              key: const ValueKey('ambient_glow_2'),
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withOpacity(0.06),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // Main Header and Profile Selection Grid
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand Identity / Splash Title
                    Text(
                      "CINEGRAM",
                      style: GoogleFonts.cinzel(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                        letterSpacing: 6.0,
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      "Who's Watching?",
                      style: GoogleFonts.cinzel(
                        fontSize: isMobile ? 32.0 : 44.0,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      "Select a perspective to curate your cinematic void",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isMobile ? 12.0 : 15.0,
                        color: Colors.white38,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 48.0),

                    // Responsive Grid or Row of Profile Cards
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: isMobile
                          ? Wrap(
                              spacing: 24.0,
                              runSpacing: 24.0,
                              alignment: WrapAlignment.center,
                              children: _profileNames.keys.map((role) {
                                return SizedBox(
                                  width: 140.0,
                                  child: ProfileCard(
                                    roleKey: role,
                                    name: _profileNames[role]!,
                                    imageUrl: _profileAvatars[role]!,
                                    isSecured: role == 'Profile 1',
                                    onTap: () => _onProfileSelected(role),
                                    onEditName: () => _showRenameDialog(role),
                                  ),
                                );
                              }).toList(),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: _profileNames.keys.map((role) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                  child: SizedBox(
                                    width: 160.0,
                                    child: ProfileCard(
                                      roleKey: role,
                                      name: _profileNames[role]!,
                                      imageUrl: _profileAvatars[role]!,
                                      isSecured: role == 'Profile 1',
                                      onTap: () => _onProfileSelected(role),
                                      onEditName: () => _showRenameDialog(role),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 64.0),
                  ],
                ),
              ),
            ),
          ),

          // Slide-up overlay PIN-Lock pad
          if (_selectedProfileForPin != null)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                child: Container(
                  color: Colors.black.withOpacity(0.75),
                  alignment: Alignment.center,
                  child: AnimatedSlide(
                    offset: _selectedProfileForPin != null ? Offset.zero : const Offset(0, 1),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    child: Container(
                      width: isMobile ? size.width * 0.9 : 420.0,
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121215).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(30.0),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.15),
                            blurRadius: 40.0,
                            spreadRadius: 2.0,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const SizedBox(width: 32.0),
                              Icon(Icons.lock_outline_rounded, color: accentColor, size: 28.0),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white60),
                                onPressed: () {
                                  setState(() {
                                    _selectedProfileForPin = null;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12.0),
                          Text(
                            "Profile 1 PIN Required",
                            style: GoogleFonts.cinzel(
                              fontSize: 20.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6.0),
                          Text(
                            "Enter code to unlock executive options (try 1234 or 0000)",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.0,
                              color: Colors.white38,
                            ),
                          ),
                          const SizedBox(height: 32.0),

                          // Dots Row
                          AnimatedBuilder(
                            animation: _shakeAnimation,
                            builder: (context, child) {
                              double dx = 0.0;
                              if (_shakeController.isAnimating) {
                                dx = (0.5 - ((_shakeController.value * 10) % 1.0).abs()) * _shakeAnimation.value;
                              }
                              return Transform.translate(
                                offset: Offset(dx, 0.0),
                                child: child,
                              );
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(4, (index) {
                                final isFilled = _enteredPin.length > index;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  margin: const EdgeInsets.symmetric(horizontal: 12.0),
                                  width: 16.0,
                                  height: 16.0,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _pinError
                                        ? Colors.redAccent
                                        : (isFilled ? accentColor : Colors.transparent),
                                    border: Border.all(
                                      color: _pinError
                                          ? Colors.redAccent
                                          : (isFilled ? accentColor : Colors.white24),
                                      width: 2.0,
                                    ),
                                    boxShadow: isFilled && !_pinError
                                        ? [
                                            BoxShadow(
                                              color: accentColor.withOpacity(0.6),
                                              blurRadius: 10.0,
                                              spreadRadius: 1.0,
                                            ),
                                          ]
                                        : [],
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 36.0),

                          // Numeric Grid
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: ['1', '2', '3'].map((n) => PinButton(label: n, onTap: () => _handlePinPress(n))).toList(),
                              ),
                              const SizedBox(height: 16.0),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: ['4', '5', '6'].map((n) => PinButton(label: n, onTap: () => _handlePinPress(n))).toList(),
                              ),
                              const SizedBox(height: 16.0),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: ['7', '8', '9'].map((n) => PinButton(label: n, onTap: () => _handlePinPress(n))).toList(),
                              ),
                              const SizedBox(height: 16.0),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  PinButton(
                                    label: 'Del',
                                    onTap: () => _handlePinPress('delete'),
                                    child: const Icon(Icons.backspace_outlined, color: Colors.white, size: 20.0),
                                  ),
                                  PinButton(label: '0', onTap: () => _handlePinPress('0')),
                                  PinButton(
                                    label: 'Go',
                                    onTap: () => _handlePinPress('submit'),
                                    child: const Icon(Icons.check_rounded, color: Colors.black, size: 22.0),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
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

class ProfileCard extends StatefulWidget {
  final String roleKey;
  final String name;
  final String imageUrl;
  final bool isSecured;
  final VoidCallback onTap;
  final VoidCallback onEditName;

  const ProfileCard({
    Key? key,
    required this.roleKey,
    required this.name,
    required this.imageUrl,
    required this.isSecured,
    required this.onTap,
    required this.onEditName,
  }) : super(key: key);

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() {
          _hasFocus = _focusNode.hasFocus;
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final accentColor = themeProvider.accentColor;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hasFocus ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 120.0,
                height: 120.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _hasFocus ? accentColor : Colors.white24,
                    width: _hasFocus ? 4.0 : 2.0,
                  ),
                  boxShadow: _hasFocus
                      ? [
                          BoxShadow(
                            color: accentColor.withOpacity(0.6),
                            blurRadius: 20.0,
                            spreadRadius: 3.0,
                          ),
                        ]
                      : [],
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: const Color(0xFF121215),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2.0),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[900],
                      child: const Icon(Icons.person, size: 48.0, color: Colors.white24),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12.0),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16.0,
                        fontWeight: _hasFocus ? FontWeight.bold : FontWeight.w600,
                        color: _hasFocus ? Colors.white : Colors.white70,
                      ),
                    ),
                  ),
                  if (widget.isSecured) ...[
                    const SizedBox(width: 6.0),
                    Icon(
                      Icons.lock_rounded,
                      size: 14.0,
                      color: _hasFocus ? accentColor : Colors.white38,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8.0),
              
              // Custom Name edit trigger
              GestureDetector(
                onTap: widget.onEditName,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_rounded, size: 10.0, color: Colors.white38),
                      const SizedBox(width: 4.0),
                      Text(
                        "Rename",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.0,
                          color: Colors.white38,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PinButton extends StatefulWidget {
  final String label;
  final Widget? child;
  final VoidCallback onTap;

  const PinButton({
    Key? key,
    required this.label,
    this.child,
    required this.onTap,
  }) : super(key: key);

  @override
  State<PinButton> createState() => _PinButtonState();
}

class _PinButtonState extends State<PinButton> {
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() {
          _hasFocus = _focusNode.hasFocus;
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final accentColor = themeProvider.accentColor;
    final isSpecialButton = widget.label == 'Del' || widget.label == 'Go';

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hasFocus ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hasFocus
                  ? (widget.label == 'Go' ? accentColor : Colors.white.withOpacity(0.2))
                  : (widget.label == 'Go' ? accentColor.withOpacity(0.8) : Colors.white.withOpacity(0.06)),
              border: Border.all(
                color: _hasFocus ? Colors.white : Colors.white12,
                width: 2.0,
              ),
              boxShadow: _hasFocus
                  ? [
                      BoxShadow(
                        color: (widget.label == 'Go' ? accentColor : Colors.white).withOpacity(0.3),
                        blurRadius: 15.0,
                        spreadRadius: 2.0,
                      ),
                    ]
                  : [],
            ),
            alignment: Alignment.center,
            child: widget.child ??
                Text(
                  widget.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                    color: _hasFocus && widget.label == 'Go' ? Colors.black : Colors.white,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
