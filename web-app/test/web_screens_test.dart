import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridify/core/app_theme.dart';
import 'package:ridify/screens/login_screen.dart';
import 'package:ridify/screens/offer_ride_screen.dart';
import 'package:ridify/screens/ride_history_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Use the actual app font: the test framework's square Ahem glyphs
    // otherwise produce false layout overflows for ordinary labels.
    final loader = FontLoader('Roboto');
    loader.addFont(Future.value(ByteData.sublistView(
      await File(Platform.environment['RIDIFY_TEST_FONT']!).readAsBytes())));
    await loader.load();
  });
  for (final width in [390.0, 480.0]) {
    for (final dark in [false, true]) {
      testWidgets('Login and signup at $width, dark=$dark', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: const LoginScreen(),
        ));
        await tester.pumpAndSettle();
        expect(find.text('Log In'), findsOneWidget);
        await tester.tap(find.text('Log In'));
        await tester.pumpAndSettle();
        expect(find.text('Please fill in your Email!'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        await tester.ensureVisible(find.text('Sign up'));
        await tester.tap(find.text('Sign up'));
        await tester.pumpAndSettle();
        expect(find.text('Full Name'), findsOneWidget);
        expect(find.text('Create Account'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('Offer form and empty history render without network', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme,
      home: const OfferRideScreen(userName: 'Test', userEmail: 'test@example.com')));
    await tester.pumpAndSettle();
    expect(find.text('Offer a Ride'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme,
      home: const RideHistoryScreen(userName: 'Test', userEmail: 'test@example.com', allRides: [])));
    await tester.pumpAndSettle();
    expect(find.text('No completed rides yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
