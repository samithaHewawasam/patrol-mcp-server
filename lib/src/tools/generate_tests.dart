import 'dart:convert';
import 'dart:io';
import '../utils/vm_service_client.dart';

Future<String> generateTests(Map<String, dynamic> arguments) async {
  try {
    final instruction = arguments['instruction'] as String;
    var widgetTree = arguments['widget_tree'] as Map<String, dynamic>?;
    final outputFile = arguments['output_file'] as String?;
    final testStyle = arguments['test_style'] as String? ?? 'single';

    // Fetch widget tree if not provided
    if (widgetTree == null) {
      final treeResult = await VmServiceClient.getWidgetTree();
      if (treeResult['error'] == true) {
        return jsonEncode({
          'error': true,
          'code': 'WIDGET_TREE_REQUIRED',
          'message': 'Could not fetch widget tree automatically',
          'details': treeResult,
          'suggestion': 'Provide widget_tree parameter or ensure Flutter app is running',
        });
      }
      widgetTree = treeResult;
    }

    // Extract widgets with keys (testable widgets)
    final widgets = widgetTree['widgets'] as List? ?? [];
    final testableWidgets = widgets
        .where((w) => w is Map<String, dynamic> && w['testable'] == true)
        .cast<Map<String, dynamic>>()
        .toList();

    if (testableWidgets.isEmpty) {
      return jsonEncode({
        'error': true,
        'code': 'NO_TESTABLE_WIDGETS',
        'message': 'No testable widgets found in widget tree',
        'suggestion': 'Add Key() properties to widgets you want to test',
      });
    }

    // Generate test code based on instruction
    final testCode = _generateTestCode(
      instruction: instruction,
      widgets: testableWidgets,
      testStyle: testStyle,
    );

    // Write to file if specified
    if (outputFile != null) {
      final file = File(outputFile);
      await file.create(recursive: true);
      await file.writeAsString(testCode);
    }

    // Extract widgets covered
    final widgetsCovered = testableWidgets
        .map((w) => w['key'] as String?)
        .where((k) => k != null)
        .toList();

    return jsonEncode({
      'generated_code': testCode,
      if (outputFile != null) 'output_file': outputFile,
      'tests_generated': 1, // Can be enhanced to count actual test cases
      'widgets_covered': widgetsCovered,
    });
  } catch (e, stackTrace) {
    return jsonEncode({
      'error': true,
      'code': 'GENERATE_TESTS_FAILED',
      'message': 'Failed to generate tests: $e',
      'stack': stackTrace.toString(),
    });
  }
}

String _generateTestCode({
  required String instruction,
  required List<Map<String, dynamic>> widgets,
  required String testStyle,
}) {
  final buffer = StringBuffer();

  // Add imports
  buffer.writeln("import 'package:flutter/material.dart';");
  buffer.writeln("import 'package:flutter_test/flutter_test.dart';");
  buffer.writeln("import 'package:patrol/patrol.dart';");
  buffer.writeln("import 'package:shopping_app/main.dart' as app;");
  buffer.writeln();

  // Determine test name from instruction
  final testName = _generateTestName(instruction);

  // Start main function
  buffer.writeln('void main() {');

  // Generate patrolTest based on style
  buffer.writeln('  patrolTest(');
  buffer.writeln("    '$testName',");
  buffer.writeln('    (\$) async {');
  buffer.writeln('      // Launch the app — required for iOS 26 / Xcode 26');
  buffer.writeln('      app.main();');
  buffer.writeln();
  buffer.writeln('      // Wait for full initialization');
  buffer.writeln('      await \$.pumpAndSettle(timeout: const Duration(seconds: 15));');
  buffer.writeln('      await Future.delayed(const Duration(seconds: 3));');
  buffer.writeln('      await \$.pumpAndSettle();');
  buffer.writeln();

  // Generate test assertions based on instruction and widgets
  final assertions = _generateAssertions(instruction, widgets);
  for (final assertion in assertions) {
    buffer.writeln('      $assertion');
  }

  buffer.writeln('    },');
  buffer.writeln('  );');
  buffer.writeln('}');

  return buffer.toString();
}

String _generateTestName(String instruction) {
  // Clean up instruction to make a valid test name
  var name = instruction;

  // Remove common prefixes
  name = name.replaceFirst(RegExp(r'^(generate|create|write|add)\s+(tests?\s+)?for\s+', caseSensitive: false), '');
  name = name.replaceFirst(RegExp(r'^test\s+', caseSensitive: false), '');

  // Capitalize first letter
  if (name.isNotEmpty) {
    name = name[0].toUpperCase() + name.substring(1);
  }

  // Limit length
  if (name.length > 80) {
    name = name.substring(0, 80);
  }

  return name.trim();
}

List<String> _generateAssertions(String instruction, List<Map<String, dynamic>> widgets) {
  final assertions = <String>[];
  final lowerInstruction = instruction.toLowerCase();

  // Generate assertions based on available widgets
  for (final widget in widgets) {
    final key = widget['key'] as String?;
    final type = widget['type'] as String? ?? 'Widget';
    final text = widget['text'] as String?;

    if (key == null) continue;

    // Check if widget is mentioned in instruction
    final isRelevant = lowerInstruction.contains(key.toLowerCase()) ||
        lowerInstruction.contains(type.toLowerCase()) ||
        (text != null && lowerInstruction.contains(text.toLowerCase()));

    if (isRelevant || assertions.isEmpty) {
      // Use symbol key syntax for patrol
      assertions.add("expect(\$(#$key), findsOneWidget);");

      // Add interaction if instruction suggests it
      if (lowerInstruction.contains('tap') ||
          lowerInstruction.contains('click') ||
          lowerInstruction.contains('press')) {
        if (type.toLowerCase().contains('button') || type.toLowerCase().contains('inkwell')) {
          assertions.add("await \$(#$key).tap();");
          assertions.add("await \$.pumpAndSettle();");
        }
      }

      if (lowerInstruction.contains('enter') ||
          lowerInstruction.contains('type') ||
          lowerInstruction.contains('input')) {
        if (type.toLowerCase().contains('textfield') || type.toLowerCase().contains('textformfield')) {
          assertions.add("await \$(#$key).enterText('test input');");
          assertions.add("await \$.pumpAndSettle();");
        }
      }
    }
  }

  // If no specific assertions, add generic checks
  if (assertions.isEmpty && widgets.isNotEmpty) {
    final firstWidget = widgets.first;
    final key = firstWidget['key'] as String?;
    if (key != null) {
      assertions.add("// Verify ${firstWidget['type']} is present");
      assertions.add("expect(\$(#$key), findsOneWidget);");
    }
  }

  return assertions;
}
