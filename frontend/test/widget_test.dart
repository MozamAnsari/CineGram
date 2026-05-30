// Cinegram Widget Smoke Test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinegram/main.dart';

void main() {
  testWidgets('CinegramApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CinegramApp());

    // Verify that a MaterialApp is successfully instantiated.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
