import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:document_seeker/home_page.dart';

void main() {
  testWidgets('Landing shows login and register', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomePage()),
    );
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });
}
