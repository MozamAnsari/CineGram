import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinegram/theme/cinegram_theme.dart';

void main() {
  group('ThemeProvider Unit Tests', () {
    test('Hex Color Parsing Valid Configurations', () {
      // With hashtag 6-digits
      final c1 = ThemeProvider.parseHexColor('#FF0055');
      expect(c1, const Color(0xFFFF0055));

      // Without hashtag 6-digits
      final c2 = ThemeProvider.parseHexColor('00E676');
      expect(c2, const Color(0xFF00E676));

      // 3-digit shorthand
      final c3 = ThemeProvider.parseHexColor('#F00');
      expect(c3, const Color(0xFFFF0000));

      // 8-digit full format (ARGB)
      final c4 = ThemeProvider.parseHexColor('#80FF5500');
      expect(c4, const Color(0x80FF5500));
    });

    test('Hex Color Parsing Invalid Configurations', () {
      expect(ThemeProvider.parseHexColor(''), null);
      expect(ThemeProvider.parseHexColor('   '), null);
      expect(ThemeProvider.parseHexColor('#XYZ'), null);
      expect(ThemeProvider.parseHexColor('12345'), null);
    });

    test('Preset Accent Colors Assignment', () async {
      final provider = ThemeProvider(0); // Gold Leaf index
      expect(provider.currentPreset, AccentPreset.goldLeaf);
      expect(provider.accentColor, AccentPreset.goldLeaf.color);

      await provider.setPreset(AccentPreset.cobaltSapphire);
      expect(provider.currentPreset, AccentPreset.cobaltSapphire);
      expect(provider.accentColor, AccentPreset.cobaltSapphire.color);
      expect(provider.customColor, null);
    });

    test('Custom Hex Accent Configuration', () async {
      final provider = ThemeProvider(0);
      
      // Apply custom hex
      final success = await provider.setCustomHexColor('#FF0055');
      expect(success, true);
      expect(provider.accentColor, const Color(0xFFFF0055));
      expect(provider.customColor, const Color(0xFFFF0055));
      expect(provider.customColorHex, '#FF0055');

      // Clear custom color
      await provider.clearCustomColor();
      expect(provider.customColor, null);
      expect(provider.accentColor, AccentPreset.goldLeaf.color);
    });
  });
}
