import 'dart:convert';
import 'dart:io';
import '../utils/test_file_parser.dart';

Future<String> listTests(Map<String, dynamic> arguments) async {
  try {
    final testDir = arguments['test_dir'] as String? ??
        '${Platform.environment['FLUTTER_PROJECT_PATH'] ?? Directory.current.path}/integration_test';

    final tests = await TestFileParser.parseTestDirectory(testDir);

    final result = {
      'tests': tests.map((test) => test.toJson()).toList(),
      'total': tests.length,
    };

    return jsonEncode(result);
  } catch (e, stackTrace) {
    return jsonEncode({
      'error': true,
      'code': 'LIST_TESTS_FAILED',
      'message': 'Failed to list tests: $e',
      'suggestion': 'Ensure the test directory exists and contains valid Dart test files',
      'stack': stackTrace.toString(),
    });
  }
}
