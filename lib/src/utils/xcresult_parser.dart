import 'dart:convert';
import 'dart:io';

class XcTestResult {
  final String name;
  final String status;
  final double duration;
  final String? failureMessage;
  final String? file;
  final int? line;

  XcTestResult({
    required this.name,
    required this.status,
    required this.duration,
    this.failureMessage,
    this.file,
    this.line,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'status': status,
        'duration': duration,
        if (failureMessage != null) 'failure_message': failureMessage,
        if (file != null) 'file': file,
        if (line != null) 'line': line,
      };
}

class XcResultParser {
  static Future<Map<String, dynamic>> parseLatestResult(String projectPath) async {
    try {
      // Find latest xcresult bundle
      final xcresultPath = await _findLatestXcresult(projectPath);
      if (xcresultPath == null) {
        return {
          'error': true,
          'code': 'NO_XCRESULT_FOUND',
          'message': 'No xcresult bundle found in build directory',
          'suggestion': 'Run patrol tests first to generate results',
        };
      }

      // Parse xcresult using xcrun
      final tests = await _parseXcresult(xcresultPath);

      return {
        'xcresult_path': xcresultPath,
        'tests': tests.map((t) => t.toJson()).toList(),
      };
    } catch (e, stackTrace) {
      return {
        'error': true,
        'code': 'XCRESULT_PARSE_FAILED',
        'message': 'Failed to parse xcresult: $e',
        'stack': stackTrace.toString(),
      };
    }
  }

  static Future<String?> _findLatestXcresult(String projectPath) async {
    final buildDir = Directory('$projectPath/build');
    if (!await buildDir.exists()) {
      return null;
    }

    DateTime? latestTime;
    String? latestPath;

    await for (final entity in buildDir.list(recursive: true)) {
      if (entity is Directory && entity.path.endsWith('.xcresult')) {
        final stat = await entity.stat();
        if (latestTime == null || stat.modified.isAfter(latestTime)) {
          latestTime = stat.modified;
          latestPath = entity.path;
        }
      }
    }

    return latestPath;
  }

  static Future<List<XcTestResult>> _parseXcresult(String xcresultPath) async {
    final tests = <XcTestResult>[];

    try {
      // Get test results as JSON
      final result = await Process.run(
        'xcrun',
        [
          'xcresulttool',
          'get',
          '--path',
          xcresultPath,
          '--format',
          'json',
        ],
      );

      if (result.exitCode != 0) {
        throw Exception('xcresulttool failed: ${result.stderr}');
      }

      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;

      // Navigate to test summaries
      final actions = json['actions'] as Map<String, dynamic>?;
      if (actions == null) return tests;

      final values = actions['_values'] as List?;
      if (values == null) return tests;

      for (final action in values) {
        if (action is! Map<String, dynamic>) continue;

        final actionResult = action['actionResult'] as Map<String, dynamic>?;
        if (actionResult == null) continue;

        final testsRef = actionResult['testsRef'] as Map<String, dynamic>?;
        if (testsRef == null) continue;

        final testSummaries = await _getTestSummaries(xcresultPath, testsRef);
        tests.addAll(testSummaries);
      }
    } catch (e) {
      throw Exception('Failed to parse xcresult JSON: $e');
    }

    return tests;
  }

  static Future<List<XcTestResult>> _getTestSummaries(
    String xcresultPath,
    Map<String, dynamic> testsRef,
  ) async {
    final tests = <XcTestResult>[];

    try {
      final refId = testsRef['id'] as Map<String, dynamic>?;
      if (refId == null) return tests;

      final id = refId['_value'] as String?;
      if (id == null) return tests;

      // Get test details
      final result = await Process.run(
        'xcrun',
        [
          'xcresulttool',
          'get',
          '--path',
          xcresultPath,
          '--id',
          id,
          '--format',
          'json',
        ],
      );

      if (result.exitCode != 0) {
        return tests;
      }

      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;

      // Parse test summaries
      final summaries = json['summaries'] as Map<String, dynamic>?;
      if (summaries == null) return tests;

      final values = summaries['_values'] as List?;
      if (values == null) return tests;

      for (final summary in values) {
        if (summary is! Map<String, dynamic>) continue;

        final testableSummaries = summary['testableSummaries'] as Map<String, dynamic>?;
        if (testableSummaries == null) continue;

        final testResults = _parseTestSummaries(testableSummaries);
        tests.addAll(testResults);
      }
    } catch (e) {
      // Ignore errors in parsing individual test summaries
    }

    return tests;
  }

  static List<XcTestResult> _parseTestSummaries(Map<String, dynamic> summaries) {
    final tests = <XcTestResult>[];

    final values = summaries['_values'] as List?;
    if (values == null) return tests;

    for (final value in values) {
      if (value is! Map<String, dynamic>) continue;

      final testCases = value['tests'] as Map<String, dynamic>?;
      if (testCases == null) continue;

      final testValues = testCases['_values'] as List?;
      if (testValues == null) continue;

      for (final test in testValues) {
        if (test is! Map<String, dynamic>) continue;

        final parsedTest = _parseTestCase(test);
        if (parsedTest != null) {
          tests.add(parsedTest);
        }
      }
    }

    return tests;
  }

  static XcTestResult? _parseTestCase(Map<String, dynamic> testCase) {
    try {
      final name = _extractString(testCase['name']) ?? 'Unknown Test';
      final testStatus = _extractString(testCase['testStatus']) ?? 'Unknown';
      final duration = _extractDouble(testCase['duration']) ?? 0.0;

      String status;
      switch (testStatus.toLowerCase()) {
        case 'success':
          status = 'passed';
          break;
        case 'failure':
          status = 'failed';
          break;
        default:
          status = testStatus.toLowerCase();
      }

      // Extract failure info if test failed
      String? failureMessage;
      String? file;
      int? line;

      if (status == 'failed') {
        final summaries = testCase['summaries'] as Map<String, dynamic>?;
        if (summaries != null) {
          final values = summaries['_values'] as List?;
          if (values != null && values.isNotEmpty) {
            final summary = values.first as Map<String, dynamic>?;
            if (summary != null) {
              failureMessage = _extractString(summary['message']);

              final location = summary['documentLocation'] as Map<String, dynamic>?;
              if (location != null) {
                file = _extractString(location['url']);
                line = _extractInt(location['lineNumber']);
              }
            }
          }
        }
      }

      return XcTestResult(
        name: name,
        status: status,
        duration: duration,
        failureMessage: failureMessage,
        file: file,
        line: line,
      );
    } catch (e) {
      return null;
    }
  }

  static String? _extractString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map<String, dynamic>) {
      return value['_value'] as String?;
    }
    return null;
  }

  static double? _extractDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is Map<String, dynamic>) {
      final v = value['_value'];
      if (v is num) return v.toDouble();
    }
    return null;
  }

  static int? _extractInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is Map<String, dynamic>) {
      final v = value['_value'];
      if (v is int) return v;
    }
    return null;
  }
}
