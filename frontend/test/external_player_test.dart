import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinegram/services/external_player_service.dart';

void main() {
  group('ExternalPlayerService Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Mock Players Loading Configurations', () {
      expect(ExternalPlayerService.mockPlayers.length, 5);
      
      final vlc = ExternalPlayerService.mockPlayers.firstWhere((p) => p.package == 'org.videolan.vlc');
      expect(vlc.name, "VLC Media Player");
      expect(vlc.icon, "vlc");
    });

    test('Graceful Non-Android / Test Runner Fallbacks', () async {
      // Test environment is non-Android, so detectPlayers should return the mock list
      final players = await ExternalPlayerService.detectPlayers();
      expect(players.length, ExternalPlayerService.mockPlayers.length);
      expect(players.first['package'], 'android.intent.action.VIEW');
    });

    test('SharedPreferences Toggles & Configurations Persistence', () async {
      // Test initial default values
      expect(await ExternalPlayerService.isExternalPlayerEnabled(), false);
      expect(await ExternalPlayerService.getSelectedPlayerPackage(), null);
      expect(await ExternalPlayerService.getSelectedPlayerName(), "System Default Player");

      // Save toggled states
      await ExternalPlayerService.setExternalPlayerEnabled(true);
      await ExternalPlayerService.setSelectedPlayerPackage('org.videolan.vlc');
      await ExternalPlayerService.setSelectedPlayerName('VLC Media Player');

      // Verify states are updated and persisted
      expect(await ExternalPlayerService.isExternalPlayerEnabled(), true);
      expect(await ExternalPlayerService.getSelectedPlayerPackage(), 'org.videolan.vlc');
      expect(await ExternalPlayerService.getSelectedPlayerName(), 'VLC Media Player');
    });

    test('Simulation Mode Playback Intent Resolver', () async {
      // Assert launching in test runner returns true (simulated success)
      final success = await ExternalPlayerService.launchPlayer(
        'org.videolan.vlc',
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        'Big Buck Bunny',
      );
      expect(success, true);
    });
  });
}
