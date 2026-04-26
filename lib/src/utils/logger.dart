import 'dart:io';

final logFile = File('/tmp/patrol_mcp_server.log');
final _logFile = logFile; // Keep for backward compatibility

void log(String message) {
  final timestamp = DateTime.now().toIso8601String();
  final logMessage = '[$timestamp] $message\n';

  // Write to stderr (for console when run manually)
  stderr.write(logMessage);

  // Write to file (for monitoring when run by Claude Code)
  try {
    _logFile.writeAsStringSync(logMessage, mode: FileMode.append);
  } catch (e) {
    stderr.writeln('[Logger] Failed to write to log file: $e');
  }
}
