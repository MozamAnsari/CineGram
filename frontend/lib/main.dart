import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/cinegram_theme.dart';
import 'screens/home.dart';
import 'screens/profile_select.dart';
import 'services/api_service.dart';

import 'services/download_manager.dart';

void main() async {
  // Ensure visual services are bound
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Load custom backend server URL if previously saved
  await ApiService.init();

  // Load custom theme presets if previously saved
  final prefs = await SharedPreferences.getInstance();
  final savedThemeIndex = prefs.getInt('accent_preset') ?? 0;
  final savedCustomHex = prefs.getString('custom_accent_color');
  
  // Set elegant system overlay colors (e.g., status bar matching the deep void dark palette)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(savedThemeIndex, savedCustomHex: savedCustomHex),
        ),
        ChangeNotifierProvider(
          create: (_) => DownloadManager()..init(),
        ),
      ],
      child: const CinegramApp(),
    ),
  );
}

class CinegramApp extends StatelessWidget {
  const CinegramApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'Cinegram',
      debugShowCheckedModeBanner: false,
      theme: CinegramTheme.darkTheme(themeProvider.accentColor),
      home: const ProfileSelectScreen(),
    );
  }
}
