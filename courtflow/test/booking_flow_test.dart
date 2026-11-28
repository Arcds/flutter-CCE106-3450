import 'package:courtflow/app.dart';
import 'package:courtflow/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('guest checkout resumes after sign-in and issues a pass', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CourtFlowApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Davao Pickleball Club').first);
    await tester.pumpAndSettle();

    // Pick tomorrow so the first slot is always in the future.
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await tester.tap(find.text(dayNumber(tomorrow)).first);
    await tester.pumpAndSettle();

    final reserve = find.text('Reserve').first;
    await tester.ensureVisible(reserve);
    await tester.pumpAndSettle();
    await tester.tap(reserve);
    await tester.pumpAndSettle();

    expect(find.text('Sign in & confirm'), findsOneWidget);
    await tester.ensureVisible(find.text('Sign in & confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in & confirm'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    await tester.tap(find.text('Sign in as player'));
    await tester.pumpAndSettle();

    // Pending intent resumes and reopens the sheet as a signed-in player.
    expect(find.text('Confirm reservation'), findsOneWidget);
    await tester.ensureVisible(find.text('Confirm reservation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm reservation'));
    await tester.pumpAndSettle();

    expect(find.text('Payment successful (demo)'), findsOneWidget);
    await tester.tap(find.text('View pass'));
    await tester.pumpAndSettle();

    expect(find.text('My Passes'), findsOneWidget);
    expect(find.text('Verified'), findsWidgets);
    expect(find.text('Tap to present at the front desk'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
  });
}
