import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:process_run/shell.dart';

class TestFailure {
  final String test;
  final String file;
  final int line;
  final String error;
  final String actual;
  final String stack;

  TestFailure({
    required this.test,
    required this.file,
    required this.line,
    required this.error,
    required this.actual,
    required this.stack,
  });

  Map<String, dynamic> toJson() => {
        'test': test,
        'file': file,
        'line': line,
        'error': error,
        'actual': actual,
        'stack': stack,
      };
}

class TestResults {
  final String status;
  final int total;
  final int passed;
  final int failed;
  final int skipped;
  final String duration;
  final List<TestFailure> failures;
  final String rawLog;

  TestResults({
    required this.status,
    required this.total,
    required this.passed,
    required this.failed,
    required this.skipped,
    required this.duration,
    required this.failures,
    required this.rawLog,
  });

  Map<String, dynamic> toJson() => {
        'status': status,
        'total': total,
        'passed': passed,
        'failed': failed,
        'skipped': skipped,
        'duration': duration,
        'failures': failures.map((f) => f.toJson()).toList(),
        'raw_log': rawLog,
      };
}

Future<String> runTests(Map<String, dynamic> arguments) async {
  try {
    print('[RunTests] Starting test execution...');

    // Check if patrol_cli is available
    print('[RunTests] Checking for patrol_cli...');
    final patrolCheck = await _checkPatrolCli();
    if (!patrolCheck['available']) {
      print('[RunTests] ERROR: patrol_cli not found');
      return jsonEncode({
        'error': true,
        'code': 'PATROL_CLI_NOT_FOUND',
        'message': 'patrol_cli not found in PATH',
        'suggestion': 'Install patrol_cli: dart pub global activate patrol_cli',
      });
    }
    print('[RunTests] patrol_cli found at: ${patrolCheck['path']}');

    final target = arguments['target'] as String?;
    final device = arguments['device'] as String? ??
        Platform.environment['PATROL_DEVICE'] ??
        'iPhone 17 Pro';
    final testName = arguments['test_name'] as String?;

    print('[RunTests] Target: $target');
    print('[RunTests] Device: $device');
    if (testName != null) {
      print('[RunTests] Test name filter: $testName');
    }

    if (target == null) {
      print('[RunTests] ERROR: No target specified');
      return jsonEncode({
        'error': true,
        'code': 'MISSING_TARGET',
        'message': 'Test target file is required',
        'suggestion': 'Provide a target parameter, e.g., "integration_test/app_test.dart"',
      });
    }

    // Build patrol command
    var command = 'patrol test -t $target -d "$device"';
    if (testName != null) {
      command += ' --name "$testName"';
    }

    final workingDir = Platform.environment['FLUTTER_PROJECT_PATH'] ?? Directory.current.path;
    print('[RunTests] Working directory: $workingDir');
    print('[RunTests] Executing command: $command');

    final shell = Shell(
      workingDirectory: workingDir,
      commandVerbose: false,
      commentVerbose: false,
    );

    final stopwatch = Stopwatch()..start();
    final output = StringBuffer();

    try {
      print('[RunTests] Starting patrol test execution (timeout: 5 minutes)...');
      final processes = await shell.run(command).timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw TimeoutException('Test execution timed out after 5 minutes');
        },
      );

      print('[RunTests] Collecting test output...');
      for (final process in processes) {
        for (final line in process.outLines) {
          output.writeln(line);
        }
        for (final line in process.errLines) {
          output.writeln(line);
        }
      }
      print('[RunTests] Test execution completed');
    } catch (e) {
      if (e is! ShellException) {
        print('[RunTests] ERROR: Unexpected exception during test execution: $e');
        rethrow;
      }
      print('[RunTests] Patrol returned non-zero exit code (likely test failures)');
      // Continue - patrol returns non-zero exit code on test failures
      // We'll parse the output to determine actual results
    }

    stopwatch.stop();
    print('[RunTests] Tests finished in ${stopwatch.elapsed}');

    print('[RunTests] Parsing test output...');
    final results = _parseTestOutput(
      output.toString(),
      stopwatch.elapsed,
    );

    print('[RunTests] Results: ${results.total} tests, ${results.passed} passed, ${results.failed} failed, ${results.skipped} skipped');
    return jsonEncode(results.toJson());
  } catch (e, stackTrace) {
    print('[RunTests] FATAL ERROR: $e');
    print('[RunTests] Stack trace: $stackTrace');
    return jsonEncode({
      'error': true,
      'code': 'TEST_EXECUTION_FAILED',
      'message': 'Failed to execute tests: $e',
      'stack': stackTrace.toString(),
    });
  }
}

Future<Map<String, dynamic>> _checkPatrolCli() async {
  try {
    final result = await Process.run('which', ['patrol']);
    return {
      'available': result.exitCode == 0,
      'path': result.stdout.toString().trim(),
    };
  } catch (e) {
    return {'available': false};
  }
}

TestResults _parseTestOutput(String output, Duration elapsed) {
  print('[RunTests] Parsing test output (${output.length} characters)...');

  final failures = <TestFailure>[];
  int total = 0;
  int passed = 0;
  int failed = 0;
  int skipped = 0;

  // Parse test summary
  print('[RunTests] Looking for test summary...');
  final summaryPattern = RegExp(r'(\d+) tests?, (\d+) passed?, (\d+) failed?');
  final summaryMatch = summaryPattern.firstMatch(output);
  if (summaryMatch != null) {
    total = int.parse(summaryMatch.group(1)!);
    passed = int.parse(summaryMatch.group(2)!);
    failed = int.parse(summaryMatch.group(3)!);
    print('[RunTests] Found summary: $total tests, $passed passed, $failed failed');
  } else {
    print('[RunTests] WARNING: Could not find test summary in output');
  }

  // Parse individual test failures
  print('[RunTests] Parsing individual test failures...');
  final failurePattern = RegExp(
    r'(?:FAILED|Error)\s+(.+?)\s+\((.+?):(\d+)\)',
    multiLine: true,
  );

  final allMatches = failurePattern.allMatches(output).toList();
  print('[RunTests] Found ${allMatches.length} failure patterns');

  for (final match in allMatches) {
    final testName = match.group(1)!.trim();
    final file = match.group(2)!.trim();
    final line = int.tryParse(match.group(3)!) ?? 0;

    // Extract error message (next few lines after the failure)
    final errorPattern = RegExp(
      r'${RegExp.escape(match.group(0)!)}\s*\n(.+?)(?:\n\n|\n.*?FAILED|\Z)',
      multiLine: true,
      dotAll: true,
    );

    var errorMessage = 'Test failed';
    var actualMessage = '';
    var stackTrace = '';

    final errorMatch = errorPattern.firstMatch(output);
    if (errorMatch != null) {
      final errorBlock = errorMatch.group(1)!;
      final lines = errorBlock.split('\n');

      // Try to extract expected/actual from error
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('Expected:')) {
          errorMessage = line.trim();
        } else if (line.contains('Actual:') || line.contains('Found:')) {
          actualMessage = line.trim();
        } else if (line.contains('at ') || line.contains('.dart:')) {
          stackTrace += '${line.trim()}\n';
        }
      }

      if (errorMessage == 'Test failed' && lines.isNotEmpty) {
        errorMessage = lines.first.trim();
      }
    }

    failures.add(TestFailure(
      test: testName,
      file: file,
      line: line,
      error: errorMessage,
      actual: actualMessage,
      stack: stackTrace.trim(),
    ));
  }

  // If we couldn't parse summary, try to infer from failures
  if (total == 0 && failures.isNotEmpty) {
    print('[RunTests] Inferring totals from failures count');
    failed = failures.length;
    total = failed;
  }

  final duration = '${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s';
  final status = failed > 0 ? 'failed' : 'passed';

  print('[RunTests] Final parsed results: status=$status, total=$total, passed=$passed, failed=$failed, duration=$duration');

  return TestResults(
    status: status,
    total: total,
    passed: passed,
    failed: failed,
    skipped: skipped,
    duration: duration,
    failures: failures,
    rawLog: output,
  );
}
