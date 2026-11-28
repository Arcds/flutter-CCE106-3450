import 'package:courtflow/app.dart';
import 'package:courtflow/screens/auth/auth_screen.dart';
import 'package:courtflow/screens/player/club_discovery_screen.dart';
import 'package:courtflow/screens/player/club_storefront_screen.dart';
import 'package:courtflow/screens/player/my_passes_screen.dart';
import 'package:courtflow/screens/player/open_play_screen.dart';
import 'package:courtflow/screens/player/profile_settings_screen.dart';
import 'package:courtflow/screens/staff/qr_scanner_screen.dart';
import 'package:courtflow/screens/staff/staff_control_center_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpScreen(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('discovery lists seeded clubs for guests', (tester) async {
    await _pumpScreen(tester, const ClubDiscoveryScreen());

    expect(find.text('CourtFlow'), findsOneWidget);
    expect(find.text('Davao Pickleball Club'), findsOneWidget);
    expect(find.text('Matina Smash Courts'), findsOneWidget);
    expect(find.text('Browsing as guest'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('storefront renders court filters and slots', (tester) async {
    await _pumpScreen(
      tester,
      const ClubStorefrontScreen(facilityId: 'davao-pickleball-club'),
    );

    expect(find.text('Davao Pickleball Club'), findsWidgets);
    expect(find.text('All courts'), findsOneWidget);
    expect(find.text('Center Court'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('passes asks guests to sign in', (tester) async {
    await _pumpScreen(tester, const MyPassesScreen());

    expect(find.text('Sign in to see your passes'), findsOneWidget);
  });

  testWidgets('open play shows capacity', (tester) async {
    await _pumpScreen(tester, const OpenPlayScreen());

    expect(find.text('Live capacity'), findsOneWidget);
    expect(find.text('Sunset Open Play'), findsOneWidget);
    expect(find.text('Full'), findsWidgets);
  });

  testWidgets('staff center is locked for guests', (tester) async {
    await _pumpScreen(tester, const StaffControlCenterScreen());

    expect(find.text('Staff access required'), findsOneWidget);
  });

  testWidgets('scanner renders manual validation UI', (tester) async {
    await _pumpScreen(tester, const QrScannerScreen());

    expect(find.text('Scan Pass'), findsOneWidget);
    expect(find.text('Validate token'), findsOneWidget);
    expect(find.text('Use demo pass'), findsOneWidget);
  });

  testWidgets('auth offers player, staff and guest entry', (tester) async {
    await _pumpScreen(tester, const AuthScreen());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in as player'), findsOneWidget);
    expect(find.text('Continue as staff (demo)'), findsOneWidget);
    expect(find.text('Continue as guest'), findsOneWidget);
  });

  testWidgets('profile shows guest state', (tester) async {
    await _pumpScreen(tester, const ProfileSettingsScreen());

    expect(find.text('You are browsing as a guest'), findsOneWidget);
  });

  testWidgets('app boots with the shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CourtFlowApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('CourtFlow'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Open Play'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
