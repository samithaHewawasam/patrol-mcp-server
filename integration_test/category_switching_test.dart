import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shopping_app/main.dart' as app;

void main() {
  patrolTest(
    'Generate a test that switches between Fashion and Sports categories, verifies th',
    ($) async {
      // Launch the app — required for iOS 26 / Xcode 26
      app.main();

      // Wait for full initialization
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));
      await Future.delayed(const Duration(seconds: 3));
      await $.pumpAndSettle();

      expect($(#product_list_appbar), findsOneWidget);
    },
  );
}
