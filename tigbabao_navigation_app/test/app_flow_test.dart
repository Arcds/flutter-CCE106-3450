import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tigbabao_navigation_app/demo_auth.dart';
import 'package:tigbabao_navigation_app/main.dart';
import 'package:tigbabao_navigation_app/social_media/create_post_sheet.dart';
import 'package:tigbabao_navigation_app/social_media/post_card.dart';

Future<void> login(
  WidgetTester tester,
  String username,
  String password,
) async {
  await tester.enterText(find.byType(TextFormField).at(0), username);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
  await tester.pumpAndSettle();
}

Future<void> createPost(
  WidgetTester tester,
  String caption,
  String imageUrl,
) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();

  final fields = find.descendant(
    of: find.byType(CreatePostSheet),
    matching: find.byType(TextField),
  );

  await tester.enterText(fields.at(0), caption);
  await tester.enterText(fields.at(1), imageUrl);
  await tester.tap(find.widgetWithText(ElevatedButton, 'Submit Post'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    DemoAuth.registeredUsername = null;
    DemoAuth.registeredPassword = null;
    DemoAuth.currentUsername = null;
  });

  testWidgets('admin login opens Dashboard with username', (tester) async {
    await tester.pumpWidget(const StudentApp());

    expect(find.text('Welcome Back!'), findsOneWidget);
    await login(tester, 'admin', 'admin123');

    expect(find.text('Welcome, admin!'), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Calculator'), findsWidgets);
    expect(find.text('Social'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
  });

  testWidgets('empty and invalid login are rejected', (tester) async {
    await tester.pumpWidget(const StudentApp());

    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pump();

    expect(find.text('Enter your username.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);

    await login(tester, 'admin', 'wrong-password');

    expect(find.text('Invalid username or password.'), findsOneWidget);
    expect(find.text('Welcome, admin!'), findsNothing);
  });

  testWidgets('calculator keeps its input and result across tabs',
      (tester) async {
    await tester.pumpWidget(const StudentApp());
    await login(tester, 'admin', 'admin123');

    await tester.tap(find.byIcon(Icons.calculate_outlined));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));

    await tester.enterText(fields.at(0), '10');
    await tester.enterText(fields.at(1), '5');
    await tester.tap(find.widgetWithText(ElevatedButton, '+'));
    await tester.pump();

    expect(find.text('15.0'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.dashboard_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.calculate_outlined));
    await tester.pumpAndSettle();

    expect(find.text('15.0'), findsOneWidget);
    final firstField = tester.widget<TextField>(find.byType(TextField).at(0));
    final secondField = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(firstField.controller!.text, '10');
    expect(secondField.controller!.text, '5');
  });

  testWidgets('social post, like, comment, and tab state work',
      (tester) async {
    await tester.pumpWidget(const StudentApp());
    await login(tester, 'admin', 'admin123');

    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();

    expect(find.text('JohnDoe'), findsOneWidget);

    await createPost(
      tester,
      'Test post',
      'https://picsum.photos/id/20/600/400',
    );

    expect(find.text('Test post'), findsOneWidget);
    expect(find.text('admin'), findsOneWidget);

    final postCard = find.ancestor(
      of: find.text('Test post'),
      matching: find.byType(PostCard),
    );

    await tester.tap(
      find.descendant(of: postCard, matching: find.text('Like')),
    );
    await tester.pump();
    expect(
      find.descendant(of: postCard, matching: find.text('Liked')),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: postCard, matching: find.text('Liked')),
    );
    await tester.pump();
    expect(
      find.descendant(of: postCard, matching: find.text('Like')),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: postCard, matching: find.text('Like')),
    );
    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(0, -150));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(of: postCard, matching: find.byType(TextField)),
      'Nice post',
    );
    await tester.tap(
      find.descendant(of: postCard, matching: find.byIcon(Icons.send)),
    );
    await tester.pump();

    expect(find.text('Nice post'), findsOneWidget);
    expect(find.text('1 Comments'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.dashboard_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();

    expect(find.text('Test post'), findsOneWidget);
    expect(find.text('Nice post'), findsOneWidget);
    expect(find.text('1 Comments'), findsOneWidget);
    expect(
      find.descendant(of: postCard, matching: find.text('Liked')),
      findsOneWidget,
    );
  });

  testWidgets('profile shows username and logout clears navigation history',
      (tester) async {
    await tester.pumpWidget(const StudentApp());
    await login(tester, 'admin', 'admin123');

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    expect(find.text('Student Profile'), findsOneWidget);
    expect(find.text('Logged in as: admin'), findsOneWidget);
    expect(find.text('ARCHE M. TIGBABAO'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.widgetWithText(ElevatedButton, 'Logout'),
      200,
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Logout'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.text('Logged in as: admin'), findsNothing);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse);
  });

  testWidgets('registered account logs in and creates a post with its name',
      (tester) async {
    await tester.pumpWidget(const StudentApp());

    await tester.tap(
      find.text("Don't have an account? Register"),
    );
    await tester.pumpAndSettle();

    final registerFields = find.byType(TextFormField);
    expect(registerFields, findsNWidgets(3));

    await tester.enterText(registerFields.at(0), 'student1');
    await tester.enterText(registerFields.at(1), 'secret1');
    await tester.enterText(registerFields.at(2), 'secret1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back!'), findsOneWidget);

    await login(tester, 'student1', 'secret1');

    expect(find.text('Welcome, student1!'), findsOneWidget);

    // Allow the registration SnackBar to disappear before tapping the FAB.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();
    await createPost(
      tester,
      'Registered post',
      'https://picsum.photos/id/24/600/400',
    );

    expect(find.text('Registered post'), findsOneWidget);
    expect(find.text('student1'), findsOneWidget);
  });
}
