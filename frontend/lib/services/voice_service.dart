import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

class VoiceService with ChangeNotifier {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  bool _isListening = false;
  String _recognizedText = "";
  double _decibelLevel = 0.0;
  Timer? _dbTimer;
  Timer? _recognitionTimer;

  bool get isListening => _isListening;
  String get recognizedText => _recognizedText;
  double get decibelLevel => _decibelLevel;

  final List<String> _simulatedQueries = [
    "mind-bending Christopher Nolan movie",
    "space exploration sci-fi and wormholes",
    "supernatural girl vanishes in a small town",
    "cyberpunk hacker learns true reality in matrix",
    "mafia Corleone crime family Godfather classic",
    "spirited away gods and spirits anime classic",
  ];

  void startListening({required Function(String result) onResultComplete}) {
    if (_isListening) return;

    _isListening = true;
    _recognizedText = "";
    _decibelLevel = 10.0;
    notifyListeners();

    // Start decibel pulsing animation loop
    final random = Random();
    _dbTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      // Pulse decibels dynamically to simulate natural speech fluctuations (20dB to 85dB)
      _decibelLevel = 20.0 + random.nextDouble() * 65.0;
      notifyListeners();
    });

    // Stop listening after 3.5 seconds and trigger simulated speech-to-text result
    _recognitionTimer = Timer(const Duration(milliseconds: 3500), () {
      stopListening();
      
      // Select a random query from our premium list
      final selectedQuery = _simulatedQueries[random.nextInt(_simulatedQueries.length)];
      _recognizedText = selectedQuery;
      notifyListeners();
      
      onResultComplete(selectedQuery);
    });
  }

  void stopListening() {
    if (!_isListening) return;

    _isListening = false;
    _decibelLevel = 0.0;
    _dbTimer?.cancel();
    _recognitionTimer?.cancel();
    notifyListeners();
  }
}
