import 'dart:convert';
import 'dart:io';
import '../utils/xcresult_parser.dart';

Future<String> getLastResults(Map<String, dynamic> arguments) async {
  try {
    final projectPath = arguments['project_path'] as String? ??
        Platform.environment['FLUTTER_PROJECT_PATH'] ??
        Directory.current.path;

    final result = await XcResultParser.parseLatestResult(projectPath);

    return jsonEncode(result);
  } catch (e, stackTrace) {
    return jsonEncode({
      'error': true,
      'code': 'GET_RESULTS_FAILED',
      'message': 'Failed to get last results: $e',
      'stack': stackTrace.toString(),
    });
  }
}
