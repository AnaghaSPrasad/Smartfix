// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smartfix_app/main.dart';
import 'package:smartfix_app/models/service.dart';
import 'package:smartfix_app/models/user.dart';
import 'package:smartfix_app/screens/chatbot_screen.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SmartFixApp());

    // Verify that the login screen appears initially with SmartFix title.
    expect(find.text('SmartFix'), findsWidgets);
  });

  testWidgets('Chatbot answers booking questions', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ChatbotScreen(
        servicesFuture: Future.value([
          ServiceItem(
            id: 1,
            name: 'Plumbing Leak Repair',
            category: 'Plumbing',
            description: 'Repair leaking taps and pipes.',
            price: 349,
          ),
        ]),
        workersFuture: Future.value([
          AppUser(
            id: 1,
            username: 'plumber_mike',
            email: 'mike@smartfix.com',
            role: 'worker',
            category: 'Plumbing',
            isVerified: true,
            isAvailable: true,
          ),
        ]),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tell me what needs fixing'), findsOneWidget);

    await tester.tap(find.text('I have a leaking tap'));
    await tester.pumpAndSettle();

    expect(find.textContaining('This sounds like a Plumbing issue'), findsOneWidget);
    expect(find.text('Book now'), findsOneWidget);
    expect(find.textContaining('plumber_mike'), findsOneWidget);
  });
}
