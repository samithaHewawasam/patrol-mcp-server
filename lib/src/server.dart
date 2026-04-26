import 'dart:async';
import 'tools/run_tests.dart';
import 'tools/get_results.dart';
import 'tools/list_tests.dart';
import 'tools/screenshot.dart';
import 'tools/widget_tree.dart';
import 'tools/generate_tests.dart';
import 'utils/logger.dart';

class PatrolMcpServer {
  final Map<String, dynamic> _toolDefinitions = {
    'patrol_run_tests': {
      'description': 'Runs patrol tests and returns structured results',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'target': {
            'type': 'string',
            'description': 'Test file to run (e.g., integration_test/app_test.dart)',
          },
          'device': {
            'type': 'string',
            'description': 'Device name (e.g., iPhone 17 Pro)',
          },
          'test_name': {
            'type': 'string',
            'description': 'Specific test name to run (optional)',
          },
        },
      },
    },
    'patrol_get_last_results': {
      'description': 'Parses the latest xcresult bundle',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'project_path': {
            'type': 'string',
            'description': 'Path to Flutter project',
          },
        },
        'required': ['project_path'],
      },
    },
    'patrol_list_tests': {
      'description': 'Lists all patrol tests in the project',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'test_dir': {
            'type': 'string',
            'description': 'Test directory path (default: integration_test/)',
          },
        },
      },
    },
    'patrol_screenshot': {
      'description': 'Takes a screenshot of the current simulator state',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'device_id': {
            'type': 'string',
            'description': 'Simulator device ID (optional, auto-detects if not provided)',
          },
          'output_path': {
            'type': 'string',
            'description': 'Output file path (optional)',
          },
        },
      },
    },
    'patrol_get_widget_tree': {
      'description': 'Connects to Flutter VM Service and returns the live widget tree',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'vm_service_url': {
            'type': 'string',
            'description': 'VM Service URL (optional, auto-detects if not provided)',
          },
          'flatten': {
            'type': 'boolean',
            'description': 'Flatten the widget tree (default: true)',
          },
          'keys_only': {
            'type': 'boolean',
            'description': 'Return only widgets with keys (default: false)',
          },
        },
      },
    },
    'patrol_generate_tests': {
      'description': 'Generates patrol test code based on widget tree and instruction',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'instruction': {
            'type': 'string',
            'description': 'Natural language instruction for test generation',
          },
          'widget_tree': {
            'type': 'object',
            'description': 'Widget tree data (optional, auto-fetches if not provided)',
          },
          'output_file': {
            'type': 'string',
            'description': 'Output file path for generated test',
          },
          'test_style': {
            'type': 'string',
            'description': 'Test style (single or group)',
          },
        },
        'required': ['instruction'],
      },
    },
  };

  Future<Map<String, dynamic>> handleRequest(Map<String, dynamic> request) async {
    final method = request['method'] as String?;
    final id = request['id'];

    log('[PatrolMcpServer] Received request: method=$method, id=$id');

    if (method == null) {
      log('[PatrolMcpServer] ERROR: Missing method in request');
      return _errorResponse(id, -32600, 'Invalid Request: missing method');
    }

    switch (method) {
      case 'initialize':
        log('[PatrolMcpServer] Handling initialize request');
        return _initializeResponse(id, request['params'] as Map<String, dynamic>?);

      case 'tools/list':
        log('[PatrolMcpServer] Handling tools/list request');
        return _listToolsResponse(id);

      case 'tools/call':
        final params = request['params'] as Map<String, dynamic>?;
        if (params == null) {
          log('[PatrolMcpServer] ERROR: Missing params in tools/call');
          return _errorResponse(id, -32602, 'Invalid params');
        }
        log('[PatrolMcpServer] Handling tools/call request');
        return await _callToolResponse(id, params);

      default:
        log('[PatrolMcpServer] ERROR: Unknown method: $method');
        return _errorResponse(id, -32601, 'Method not found: $method');
    }
  }

  Map<String, dynamic> _initializeResponse(dynamic id, Map<String, dynamic>? params) {
    return {
      'jsonrpc': '2.0',
      'id': id,
      'result': {
        'protocolVersion': '2024-11-05',
        'capabilities': {
          'tools': {},
        },
        'serverInfo': {
          'name': 'patrol-mcp',
          'version': '1.0.0',
        },
      },
    };
  }

  Map<String, dynamic> _listToolsResponse(dynamic id) {
    final tools = _toolDefinitions.entries.map((entry) {
      return {
        'name': entry.key,
        'description': entry.value['description'],
        'inputSchema': entry.value['inputSchema'],
      };
    }).toList();

    return {
      'jsonrpc': '2.0',
      'id': id,
      'result': {
        'tools': tools,
      },
    };
  }

  Future<Map<String, dynamic>> _callToolResponse(
    dynamic id,
    Map<String, dynamic> params,
  ) async {
    final toolName = params['name'] as String?;
    final arguments = params['arguments'] as Map<String, dynamic>? ?? {};

    log('[PatrolMcpServer] Tool call: $toolName');

    if (toolName == null) {
      log('[PatrolMcpServer] ERROR: Missing tool name in call');
      return _errorResponse(id, -32602, 'Missing tool name');
    }

    try {
      final result = await _executeTool(toolName, arguments);

      log('[PatrolMcpServer] Tool $toolName completed successfully');
      return {
        'jsonrpc': '2.0',
        'id': id,
        'result': {
          'content': [
            {
              'type': 'text',
              'text': result,
            }
          ],
        },
      };
    } catch (e, stackTrace) {
      log('[PatrolMcpServer] ERROR: Tool $toolName failed with exception: $e');
      log('[PatrolMcpServer] Stack trace: $stackTrace');
      return _errorResponse(
        id,
        -32603,
        'Tool execution error: $e\n$stackTrace',
      );
    }
  }

  Future<String> _executeTool(
    String toolName,
    Map<String, dynamic> arguments,
  ) async {
    log('[PatrolMcpServer] Executing tool: $toolName');
    log('[PatrolMcpServer] Arguments: $arguments');

    switch (toolName) {
      case 'patrol_run_tests':
        log('[PatrolMcpServer] Delegating to runTests...');
        return await runTests(arguments);

      case 'patrol_get_last_results':
        log('[PatrolMcpServer] Delegating to getLastResults...');
        return await getLastResults(arguments);

      case 'patrol_list_tests':
        log('[PatrolMcpServer] Delegating to listTests...');
        return await listTests(arguments);

      case 'patrol_screenshot':
        log('[PatrolMcpServer] Delegating to takeScreenshot...');
        return await takeScreenshot(arguments);

      case 'patrol_get_widget_tree':
        log('[PatrolMcpServer] Delegating to getWidgetTree...');
        return await getWidgetTree(arguments);

      case 'patrol_generate_tests':
        log('[PatrolMcpServer] Delegating to generateTests...');
        return await generateTests(arguments);

      default:
        log('[PatrolMcpServer] ERROR: Unknown tool: $toolName');
        throw Exception('Unknown tool: $toolName');
    }
  }

  Map<String, dynamic> _errorResponse(dynamic id, int code, String message) {
    return {
      'jsonrpc': '2.0',
      'id': id,
      'error': {
        'code': code,
        'message': message,
      },
    };
  }
}
