import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<String> takeScreenshot(Map<String, dynamic> arguments) async {
  try {
    // Get or detect device ID
    var deviceId = arguments['device_id'] as String?;

    if (deviceId == null) {
      deviceId = await _detectBootedDevice();
      if (deviceId == null) {
        return jsonEncode({
          'error': true,
          'code': 'NO_BOOTED_DEVICE',
          'message': 'No booted simulator found',
          'suggestion': 'Boot a simulator first or provide device_id parameter',
        });
      }
    }

    // Get output path or generate one
    final outputPath = arguments['output_path'] as String? ??
        '/tmp/patrol_screenshot_${DateTime.now().millisecondsSinceEpoch}.png';

    // Take screenshot using simctl
    final result = await Process.run(
      'xcrun',
      ['simctl', 'io', deviceId, 'screenshot', outputPath],
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('Screenshot timed out after 30 seconds'),
    );

    if (result.exitCode != 0) {
      return jsonEncode({
        'error': true,
        'code': 'SCREENSHOT_FAILED',
        'message': 'Failed to take screenshot: ${result.stderr}',
        'suggestion': 'Ensure the simulator is booted and accessible',
      });
    }

    // Read and encode screenshot
    final file = File(outputPath);
    if (!await file.exists()) {
      return jsonEncode({
        'error': true,
        'code': 'SCREENSHOT_NOT_FOUND',
        'message': 'Screenshot file was not created',
      });
    }

    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);

    // Get device info
    final deviceInfo = await _getDeviceInfo(deviceId);

    final response = {
      'path': outputPath,
      'base64': base64Image,
      'device': deviceInfo['name'] ?? deviceId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    return jsonEncode(response);
  } catch (e, stackTrace) {
    return jsonEncode({
      'error': true,
      'code': 'SCREENSHOT_ERROR',
      'message': 'Failed to take screenshot: $e',
      'stack': stackTrace.toString(),
    });
  }
}

Future<String?> _detectBootedDevice() async {
  try {
    final result = await Process.run('xcrun', ['simctl', 'list', 'devices', 'booted']);

    if (result.exitCode != 0) {
      return null;
    }

    final output = result.stdout as String;

    // Parse device ID from output
    // Format: "    iPhone 17 Pro (DEVICE-ID) (Booted)"
    final devicePattern = RegExp(r'\(([A-F0-9-]+)\)\s+\(Booted\)');
    final match = devicePattern.firstMatch(output);

    return match?.group(1);
  } catch (e) {
    return null;
  }
}

Future<Map<String, String>> _getDeviceInfo(String deviceId) async {
  try {
    final result = await Process.run('xcrun', ['simctl', 'list', 'devices']);

    if (result.exitCode != 0) {
      return {};
    }

    final output = result.stdout as String;

    // Find device name by ID
    final devicePattern = RegExp(r'(.+?)\s+\($deviceId\)');
    final match = devicePattern.firstMatch(output);

    if (match != null) {
      return {'name': match.group(1)!.trim()};
    }

    return {};
  } catch (e) {
    return {};
  }
}
