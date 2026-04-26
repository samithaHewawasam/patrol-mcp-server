import 'dart:async';
import 'dart:io';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

class WidgetInfo {
  final String? key;
  final String type;
  final int depth;
  final String? text;
  final bool testable;
  final Map<String, dynamic>? bounds;
  final String? suggestion;
  final int? childCount;

  WidgetInfo({
    this.key,
    required this.type,
    required this.depth,
    this.text,
    required this.testable,
    this.bounds,
    this.suggestion,
    this.childCount,
  });

  Map<String, dynamic> toJson() => {
        if (key != null) 'key': key,
        'type': type,
        'depth': depth,
        if (text != null) 'text': text,
        'testable': testable,
        if (bounds != null) 'bounds': bounds,
        if (suggestion != null) 'suggestion': suggestion,
        if (childCount != null) 'child_count': childCount,
      };
}

class VmServiceClient {
  static Future<String?> detectVmServiceUrl() async {
    try {
      print('[VmServiceClient] Starting VM service URL detection...');

      // Method 1: Check for running Flutter processes
      print('[VmServiceClient] Method 1: Checking running Flutter processes...');
      final result = await Process.run('ps', ['aux']);
      if (result.exitCode == 0) {
        final output = result.stdout as String;
        final lines = output.split('\n');

        for (final line in lines) {
          // Look for --vm-service-uri flag (used by Flutter development-service)
          if (line.contains('--vm-service-uri=')) {
            final uriMatch = RegExp(r'--vm-service-uri=(http://127\.0\.0\.1:\d+/[^\s]+)').firstMatch(line);
            if (uriMatch != null) {
              final httpUrl = uriMatch.group(1)!;
              // Convert HTTP to WebSocket URL
              final wsUrl = _convertToWebSocketUrl(httpUrl);
              print('[VmServiceClient] Found --vm-service-uri in process: $wsUrl (converted from $httpUrl)');
              return wsUrl;
            }
          }

          // Look for observatory-port flag
          if (line.contains('flutter') && line.contains('observatory-port')) {
            // Extract observatory port from command line
            final portMatch = RegExp(r'observatory-port[=\s]+(\d+)').firstMatch(line);
            if (portMatch != null) {
              final port = portMatch.group(1);
              final url = 'ws://127.0.0.1:$port/ws';
              print('[VmServiceClient] Found observatory-port in process: $url');
              return url;
            }
          }

          // Look for WebSocket VM service URL in process arguments
          if (line.contains('ws://127.0.0.1:')) {
            final urlMatch = RegExp(r'(ws://127\.0\.0\.1:\d+/[^\s]+)').firstMatch(line);
            if (urlMatch != null) {
              final url = urlMatch.group(1);
              print('[VmServiceClient] Found VM service URL in process arguments: $url');
              return url;
            }
          }

          // Look for HTTP VM service URL in process arguments and convert to WebSocket
          if (line.contains('http://127.0.0.1:')) {
            final urlMatch = RegExp(r'(http://127\.0\.0\.1:\d+/[^\s]+)').firstMatch(line);
            if (urlMatch != null) {
              final httpUrl = urlMatch.group(1)!;
              final wsUrl = _convertToWebSocketUrl(httpUrl);
              print('[VmServiceClient] Found HTTP VM service URL in process arguments: $wsUrl (converted from $httpUrl)');
              return wsUrl;
            }
          }
        }
      }

      // Method 2: Check common Flutter ports
      print('[VmServiceClient] Method 2: Checking common Flutter ports...');
      for (final port in [8181, 8080, 8888]) {
        final url = 'ws://127.0.0.1:$port/ws';
        print('[VmServiceClient] Testing port $port...');
        if (await _testVmServiceUrl(url)) {
          print('[VmServiceClient] Successfully connected to VM service at $url');
          return url;
        }
      }

      print('[VmServiceClient] WARNING: No VM service URL detected');
      return null;
    } catch (e) {
      print('[VmServiceClient] ERROR during VM service URL detection: $e');
      return null;
    }
  }

  static Future<bool> _testVmServiceUrl(String url) async {
    try {
      final service = await vmServiceConnectUri(url).timeout(
        const Duration(seconds: 2),
      );
      await service.getVersion();
      await service.dispose();
      print('[VmServiceClient] Port test successful for: $url');
      return true;
    } catch (e) {
      print('[VmServiceClient] Port test failed for $url: $e');
      return false;
    }
  }

  /// Converts an HTTP VM service URL to a WebSocket URL
  /// Example: http://127.0.0.1:64252/nfJugFiHDoI=/ -> ws://127.0.0.1:64252/nfJugFiHDoI=/ws
  static String _convertToWebSocketUrl(String httpUrl) {
    var wsUrl = httpUrl.replaceFirst('http://', 'ws://');

    // Ensure URL ends with /ws
    if (!wsUrl.endsWith('/ws')) {
      // Remove trailing slash if present
      if (wsUrl.endsWith('/')) {
        wsUrl = wsUrl.substring(0, wsUrl.length - 1);
      }
      wsUrl = '$wsUrl/ws';
    }

    return wsUrl;
  }

  static Future<Map<String, dynamic>> getWidgetTree({
    String? vmServiceUrl,
    bool flatten = true,
    bool keysOnly = false,
    int maxRetries = 3,
  }) async {
    VmService? service;

    try {
      print('[VmServiceClient] Starting getWidgetTree request...');
      print('[VmServiceClient] Parameters: flatten=$flatten, keysOnly=$keysOnly, maxRetries=$maxRetries');

      // Auto-detect URL if not provided
      print('[VmServiceClient] Detecting VM service URL...');
      final url = vmServiceUrl ?? await detectVmServiceUrl();

      if (url == null) {
        print('[VmServiceClient] ERROR: Could not detect VM service URL');
        return {
          'error': true,
          'code': 'VM_SERVICE_NOT_FOUND',
          'message': 'Could not detect Flutter VM Service URL',
          'suggestion':
              'Ensure Flutter app is running with --observatory-port flag or provide vm_service_url parameter',
        };
      }

      print('[VmServiceClient] Using VM service URL: $url');

      // Connect to VM service with retries
      print('[VmServiceClient] Attempting to connect to VM service (max retries: $maxRetries)...');
      Exception? lastError;
      for (var i = 0; i < maxRetries; i++) {
        try {
          print('[VmServiceClient] Connection attempt ${i + 1}/$maxRetries...');
          service = await vmServiceConnectUri(url).timeout(
            const Duration(seconds: 30),
          );
          print('[VmServiceClient] Successfully connected to VM service');
          break;
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          print('[VmServiceClient] Connection attempt ${i + 1} failed: $e');
          if (i < maxRetries - 1) {
            final delaySeconds = i + 1;
            print('[VmServiceClient] Retrying in $delaySeconds seconds...');
            await Future.delayed(Duration(seconds: delaySeconds));
          }
        }
      }

      if (service == null) {
        print('[VmServiceClient] ERROR: Failed to connect after $maxRetries attempts');
        return {
          'error': true,
          'code': 'VM_SERVICE_CONNECTION_FAILED',
          'message': 'Failed to connect to VM Service after $maxRetries attempts',
          'details': lastError?.toString(),
          'suggestion': 'Check if Flutter app is running and VM Service is accessible at $url',
        };
      }

      // Get isolate - try different methods based on what the VM service supports
      print('[VmServiceClient] Retrieving isolate information...');

      String? isolateId;

      // Method 1: Try getVM (standard VM service)
      try {
        print('[VmServiceClient] Attempting getVM...');
        final vm = await service.getVM().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('getVM timed out after 10 seconds');
          },
        );

        print('[VmServiceClient] getVM successful: ${vm.isolates?.length ?? 0} isolates found');

        if (vm.isolates != null && vm.isolates!.isNotEmpty) {
          isolateId = vm.isolates!.first.id;
          print('[VmServiceClient] Using isolate from getVM: $isolateId');
        }
      } catch (e) {
        print('[VmServiceClient] getVM failed: $e');
        print('[VmServiceClient] This might be a DDS proxy or limited VM service');
      }

      // Method 2: Try streamListen and get isolate from events (works with DDS)
      if (isolateId == null) {
        print('[VmServiceClient] Trying streamListen to discover isolates...');
        try {
          await service.streamListen('Isolate').timeout(const Duration(seconds: 5));
          print('[VmServiceClient] Subscribed to Isolate stream');

          // Wait a moment for events to arrive
          await Future.delayed(const Duration(milliseconds: 500));

          // Try getVM again after subscribing to stream
          try {
            final vm = await service.getVM().timeout(const Duration(seconds: 5));
            if (vm.isolates != null && vm.isolates!.isNotEmpty) {
              isolateId = vm.isolates!.first.id;
              print('[VmServiceClient] Found isolate after stream subscription: $isolateId');
            }
          } catch (e) {
            print('[VmServiceClient] getVM still failed after stream subscription: $e');
          }
        } catch (e) {
          print('[VmServiceClient] streamListen failed: $e');
        }
      }

      // Method 3: Try to call Flutter extensions directly with a guessed isolate ID
      if (isolateId == null) {
        print('[VmServiceClient] Trying to discover isolate via service extensions...');

        // Common isolate IDs used by Flutter - expanded list
        final commonIds = [
          'isolates/1',
          'isolates/2',
          'main',
          'isolate/1',
          'isolate/2',
        ];

        for (final testId in commonIds) {
          try {
            print('[VmServiceClient] Testing isolate ID: $testId');
            await service.callServiceExtension(
              'ext.flutter.inspector.getRootWidget',
              isolateId: testId,
              args: {'objectGroup': 'patrol-mcp-test'},
            ).timeout(const Duration(seconds: 5));

            isolateId = testId;
            print('[VmServiceClient] Found working isolate ID: $isolateId');
            break;
          } catch (e) {
            print('[VmServiceClient] Isolate ID $testId failed: $e');
          }
        }
      }

      if (isolateId == null) {
        print('[VmServiceClient] ERROR: Could not determine isolate ID');
        return {
          'error': true,
          'code': 'NO_ISOLATES',
          'message': 'Could not find or determine isolate ID',
          'suggestion': 'The VM service may not be fully accessible. Try using --observatory-port flag.',
        };
      }

      // Get isolate details if possible
      Isolate? isolate;
      try {
        print('[VmServiceClient] Fetching isolate details for: $isolateId');
        isolate = await service.getIsolate(isolateId).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('getIsolate timed out after 10 seconds');
          },
        );
        print('[VmServiceClient] Isolate details retrieved, pause event: ${isolate.pauseEvent?.kind}');
      } catch (e) {
        print('[VmServiceClient] WARNING: Could not get isolate details: $e');
        // Continue anyway - we'll try to use the isolate ID
      }

      print('[VmServiceClient] Proceeding with isolate ID: $isolateId');

      // Check if isolate is runnable (if we have isolate details)
      if (isolate?.pauseEvent?.kind == 'PauseExit') {
        print('[VmServiceClient] ERROR: Isolate is not runnable (PauseExit)');
        return {
          'error': true,
          'code': 'ISOLATE_NOT_RUNNABLE',
          'message': 'Isolate is not in a runnable state',
          'suggestion': 'The Flutter app may have exited. Try restarting the app.',
        };
      }

      // Get root widget with summary tree first (faster)
      print('[VmServiceClient] Calling Flutter inspector to get root widget summary...');
      final rootResponse = await service.callServiceExtension(
        'ext.flutter.inspector.getRootWidgetSummaryTree',
        isolateId: isolateId,
        args: {
          'objectGroup': 'patrol-mcp',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('getRootWidgetSummaryTree timed out after 10 seconds');
        },
      );

      print('[VmServiceClient] Root widget summary received');

      final widgetTree = rootResponse.json?['result'];
      if (widgetTree == null) {
        print('[VmServiceClient] ERROR: Widget tree is null in response');
        return {
          'error': true,
          'code': 'NO_WIDGET_TREE',
          'message': 'Could not retrieve widget tree',
        };
      }

      print('[VmServiceClient] Widget tree retrieved successfully, parsing...');

      // Parse widget tree with timeout
      final widgets = await _parseWidgetTree(
        service,
        isolateId,
        widgetTree,
        flatten: flatten,
        keysOnly: keysOnly,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Widget tree parsing timed out after 30 seconds');
        },
      );

      print('[VmServiceClient] Widget tree parsing complete: ${widgets.length} widgets found');

      // Get screen name from root widget
      final screenName = _extractScreenName(widgetTree);
      print('[VmServiceClient] Screen name: $screenName');

      // Count testable vs untestable widgets
      final testableCount = widgets.where((w) => w.testable).length;
      final untestableCount = widgets.where((w) => !w.testable).length;
      print('[VmServiceClient] Testable widgets: $testableCount, Untestable widgets: $untestableCount');

      // Dispose object group (best effort - ignore errors)
      print('[VmServiceClient] Cleaning up object group...');
      try {
        await service.callServiceExtension(
          'ext.flutter.inspector.disposeGroup',
          isolateId: isolateId,
          args: {'objectGroup': 'patrol-mcp'},
        ).timeout(
          const Duration(seconds: 5),
        );
        print('[VmServiceClient] Object group disposed successfully');
      } catch (e) {
        print('[VmServiceClient] WARNING: Failed to dispose object group (non-critical): $e');
      }

      print('[VmServiceClient] Widget tree retrieval completed successfully');
      return {
        'screen': screenName,
        'timestamp': DateTime.now().toIso8601String(),
        'widgets': widgets.map((w) => w.toJson()).toList(),
        'testable_count': testableCount,
        'untestable_count': untestableCount,
      };
    } on TimeoutException catch (e) {
      print('[VmServiceClient] ERROR: Timeout exception: $e');
      return {
        'error': true,
        'code': 'TIMEOUT',
        'message': 'Operation timed out: $e',
        'suggestion': 'The Flutter app may be unresponsive or the widget tree is very large. Try restarting the app or simplifying the UI.',
      };
    } catch (e, stackTrace) {
      print('[VmServiceClient] ERROR: Exception occurred: $e');
      print('[VmServiceClient] Stack trace: $stackTrace');
      return {
        'error': true,
        'code': 'WIDGET_TREE_ERROR',
        'message': 'Failed to get widget tree: $e',
        'stack': stackTrace.toString(),
      };
    } finally {
      if (service != null) {
        print('[VmServiceClient] Disposing VM service connection...');
        await service.dispose();
        print('[VmServiceClient] VM service connection disposed');
      }
    }
  }

  static Future<List<WidgetInfo>> _parseWidgetTree(
    VmService service,
    String isolateId,
    Map<String, dynamic> widget, {
    bool flatten = true,
    bool keysOnly = false,
    int depth = 0,
  }) async {
    final widgets = <WidgetInfo>[];

    try {
      final type = widget['description'] as String? ?? 'Unknown';
      final key = _extractKey(widget);
      final text = await _extractText(service, isolateId, widget);
      final testable = key != null;
      final bounds = await _extractBounds(service, isolateId, widget);
      final childCount = await _getChildCount(service, isolateId, widget);

      String? suggestion;
      if (!testable && depth > 2) {
        // Only suggest keys for widgets deeper in tree
        suggestion = "Add Key('${_generateKeyName(type)}') for testability";
      }

      final widgetInfo = WidgetInfo(
        key: key,
        type: type,
        depth: depth,
        text: text,
        testable: testable,
        bounds: bounds,
        suggestion: suggestion,
        childCount: childCount,
      );

      if (!keysOnly || testable) {
        widgets.add(widgetInfo);
      }

      // Recursively parse children if flattening
      if (flatten) {
        final children = await _getChildren(service, isolateId, widget);
        for (final child in children) {
          final childWidgets = await _parseWidgetTree(
            service,
            isolateId,
            child,
            flatten: flatten,
            keysOnly: keysOnly,
            depth: depth + 1,
          );
          widgets.addAll(childWidgets);
        }
      }
    } catch (e) {
      // Skip widgets that can't be parsed
    }

    return widgets;
  }

  static String? _extractKey(Map<String, dynamic> widget) {
    final description = widget['description'] as String?;
    if (description == null) return null;

    // Extract key from description like "Container-[<'my_key'>]"
    final keyMatch = RegExp(r"\[<'(.+?)'>\]").firstMatch(description);
    if (keyMatch != null) {
      return keyMatch.group(1);
    }

    // Extract key from ValueKey pattern
    final valueKeyMatch = RegExp(r"ValueKey<.+?>\('(.+?)'\)").firstMatch(description);
    if (valueKeyMatch != null) {
      return valueKeyMatch.group(1);
    }

    return null;
  }

  static Future<String?> _extractText(
    VmService service,
    String isolateId,
    Map<String, dynamic> widget,
  ) async {
    try {
      // Check if widget has text property
      final properties = widget['properties'] as List?;
      if (properties != null) {
        for (final prop in properties) {
          if (prop is Map<String, dynamic>) {
            final name = prop['name'] as String?;
            final value = prop['value'] as String?;

            if ((name == 'data' || name == 'text') && value != null) {
              return value;
            }
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _extractBounds(
    VmService service,
    String isolateId,
    Map<String, dynamic> widget,
  ) async {
    try {
      // Get render object bounds
      final properties = widget['properties'] as List?;
      if (properties != null) {
        for (final prop in properties) {
          if (prop is Map<String, dynamic>) {
            final name = prop['name'] as String?;

            if (name == 'renderObject') {
              // Would need to call getRenderObject service extension
              // Simplified version - return null for now
              return null;
            }
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<int?> _getChildCount(
    VmService service,
    String isolateId,
    Map<String, dynamic> widget,
  ) async {
    try {
      final children = widget['children'] as List?;
      return children?.length;
    } catch (e) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> _getChildren(
    VmService service,
    String isolateId,
    Map<String, dynamic> widget,
  ) async {
    try {
      final children = widget['children'] as List?;
      if (children == null) return [];

      return children.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      return [];
    }
  }

  static String _extractScreenName(Map<String, dynamic> widget) {
    final description = widget['description'] as String? ?? '';

    // Look for common page/screen widgets
    final patterns = [
      RegExp(r'(\w+Page)'),
      RegExp(r'(\w+Screen)'),
      RegExp(r'(\w+View)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(description);
      if (match != null) {
        return match.group(1)!;
      }
    }

    return 'UnknownScreen';
  }

  static String _generateKeyName(String widgetType) {
    // Convert widget type to snake_case key name
    final name = widgetType.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)}_${match.group(2)}',
    ).toLowerCase();

    return name;
  }
}
