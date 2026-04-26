import 'dart:io';

class TestInfo {
  final String name;
  final String file;
  final int line;
  final String type;

  TestInfo({
    required this.name,
    required this.file,
    required this.line,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'file': file,
        'line': line,
        'type': type,
      };
}

class TestFileParser {
  static Future<List<TestInfo>> parseTestDirectory(String testDir) async {
    final tests = <TestInfo>[];
    final dir = Directory(testDir);

    if (!await dir.exists()) {
      throw Exception('Test directory not found: $testDir');
    }

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('_test.dart')) {
        final fileTests = await _parseTestFile(entity);
        tests.addAll(fileTests);
      }
    }

    return tests;
  }

  static Future<List<TestInfo>> _parseTestFile(File file) async {
    final tests = <TestInfo>[];
    final lines = await file.readAsLines();

    // Regex patterns for different test types
    final patrolTestPattern = RegExp(
      r'''patrolTest\s*\(\s*['"](.+?)['"]\s*,''',
    );
    final testPattern = RegExp(
      r'''test\s*\(\s*['"](.+?)['"]\s*,''',
    );

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNumber = i + 1;

      // Check for patrolTest
      var match = patrolTestPattern.firstMatch(line);
      if (match != null) {
        tests.add(TestInfo(
          name: match.group(1)!,
          file: file.path,
          line: lineNumber,
          type: 'patrolTest',
        ));
        continue;
      }

      // Check for regular test
      match = testPattern.firstMatch(line);
      if (match != null) {
        tests.add(TestInfo(
          name: match.group(1)!,
          file: file.path,
          line: lineNumber,
          type: 'test',
        ));
      }
    }

    return tests;
  }
}
