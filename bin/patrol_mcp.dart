import 'dart:io';
import 'dart:convert';
import '../lib/src/server.dart';
import '../lib/src/utils/logger.dart';

void main() async {
  final server = PatrolMcpServer();

  log('=================================================');
  log('Patrol MCP Server v1.0.0');
  log('Starting and listening for JSON-RPC requests...');
  log('Log file: ${logFile.path}');
  log('=================================================');

  final input = stdin.transform(utf8.decoder).transform(const LineSplitter());

  await for (final line in input) {
    if (line.trim().isEmpty) {
      log('[Main] Skipping empty line');
      continue;
    }

    stderr.writeln('[Main] Received request: ${line.length} characters');

    try {
      final request = jsonDecode(line) as Map<String, dynamic>;
      log('[Main] Parsed JSON request successfully');

      final response = await server.handleRequest(request);

      log('[Main] Sending response...');
      stdout.writeln(jsonEncode(response));
      log('[Main] Response sent successfully');
    } catch (e, stackTrace) {
      log('[Main] ERROR: Failed to handle request: $e');
      log('[Main] Stack trace: $stackTrace');

      // Send error response
      final errorResponse = {
        'jsonrpc': '2.0',
        'id': null,
        'error': {
          'code': -32700,
          'message': 'Parse error: $e',
        }
      };
      stdout.writeln(jsonEncode(errorResponse));
    }
  }

  stderr.writeln('[Main] Input stream closed, server shutting down...');
}
