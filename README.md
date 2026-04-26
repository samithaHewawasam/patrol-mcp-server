# Patrol MCP Server

[![Dart](https://img.shields.io/badge/Dart-3.0%2B-blue.svg)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![MCP](https://img.shields.io/badge/MCP-Compatible-green.svg)](https://modelcontextprotocol.io/)

A Model Context Protocol (MCP) server that enables AI assistants like Claude to autonomously run, inspect, and generate Flutter [Patrol](https://github.com/leancodepl/patrol) integration tests.

This server bridges the gap between AI-powered development workflows and Flutter E2E testing, making it easier to write, debug, and maintain integration tests through natural language interactions.

## Why Use This?

- **Natural Language Testing**: Write and generate tests using plain English instead of manually coding everything
- **Faster Debugging**: Quickly inspect widget trees, take screenshots, and analyze test failures
- **AI-Powered Test Generation**: Automatically generate patrol tests based on your app's current state
- **Seamless Integration**: Works with Claude Desktop, Claude Code CLI, and any MCP-compatible AI assistant
- **iOS/Xcode Compatibility**: Fully compatible with iOS 26 and Xcode 26

## Features

- **Run Patrol Tests**: Execute integration tests and get structured results
- **Parse Test Results**: Extract detailed information from xcresult bundles
- **List Tests**: Discover all patrol tests in your project
- **Take Screenshots**: Capture simulator state during test runs
- **Inspect Widget Tree**: Connect to Flutter VM Service and get live widget hierarchy
- **Generate Tests**: Automatically create patrol tests from natural language instructions

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Claude (AI)                           │
│                 Natural Language Interface                   │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          │ JSON-RPC 2.0
                          │ (stdin/stdout transport)
                          │
┌─────────────────────────▼───────────────────────────────────┐
│                   Patrol MCP Server (Dart)                   │
│  ┌───────────────────────────────────────────────────────┐  │
│  │         MCP Protocol Handler (server.dart)            │  │
│  │  • initialize    • tools/list    • tools/call         │  │
│  └─────────┬─────────────────────────────────────────────┘  │
│            │                                                  │
│  ┌─────────▼──────────────────────────────────────────────┐ │
│  │                    Tools Layer                          │ │
│  │  ┌────────────────┐  ┌──────────────────┐             │ │
│  │  │ patrol_        │  │ patrol_          │             │ │
│  │  │ list_tests     │  │ screenshot       │             │ │
│  │  └────────────────┘  └──────────────────┘             │ │
│  │  ┌────────────────┐  ┌──────────────────┐             │ │
│  │  │ patrol_        │  │ patrol_get_      │             │ │
│  │  │ run_tests      │  │ widget_tree      │             │ │
│  │  └────────────────┘  └──────────────────┘             │ │
│  │  ┌────────────────┐  ┌──────────────────┐             │ │
│  │  │ patrol_get_    │  │ patrol_          │             │ │
│  │  │ last_results   │  │ generate_tests   │             │ │
│  │  └────────────────┘  └──────────────────┘             │ │
│  └─────────┬──────────────────────────────────────────────┘ │
│            │                                                  │
│  ┌─────────▼──────────────────────────────────────────────┐ │
│  │                  Utilities Layer                        │ │
│  │  • test_file_parser.dart   (Dart file parsing)         │ │
│  │  • xcresult_parser.dart    (iOS test result parsing)   │ │
│  │  • vm_service_client.dart  (Flutter VM integration)    │ │
│  └─────────┬──────────────────────────────────────────────┘ │
└────────────┼──────────────────────────────────────────────────┘
             │
    ┌────────┼─────────┬──────────────┬─────────────────┐
    │        │         │              │                 │
┌───▼──┐ ┌──▼────┐ ┌──▼────────┐ ┌───▼──────┐ ┌──────▼──────┐
│patrol│ │xcrun  │ │VM Service │ │Flutter   │ │File System  │
│ CLI  │ │xcresul│ │(websocket)│ │Process   │ │integration_ │
│      │ │t/simct│ │port 8181  │ │          │ │test/*.dart  │
└──────┘ └───────┘ └───────────┘ └──────────┘ └─────────────┘
```

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/yourusername/patrol-mcp-server.git
cd patrol-mcp-server/patrol_mcp

# 2. Install dependencies
dart pub get

# 3. Install patrol_cli globally
dart pub global activate patrol_cli

# 4. Test the server
dart run bin/patrol_mcp.dart
```

The server should start and wait for JSON-RPC input. Press `Ctrl+C` to stop.

## Installation

### Prerequisites

Before you begin, ensure you have the following installed:

- **Dart SDK** 3.0.0 or higher ([Install Dart](https://dart.dev/get-dart))
- **Flutter SDK** ([Install Flutter](https://flutter.dev/docs/get-started/install))
- **Xcode** (for iOS testing on macOS)
- **patrol_cli** 4.3.1 or higher:
  ```bash
  dart pub global activate patrol_cli
  ```

Make sure Dart global binaries are in your PATH:
```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

### Setup

1. Clone or download this repository:
   ```bash
   git clone https://github.com/yourusername/patrol-mcp-server.git
   cd patrol-mcp-server/patrol_mcp
   ```

2. Install dependencies:
   ```bash
   dart pub get
   ```

3. Verify the installation:
   ```bash
   dart run bin/patrol_mcp.dart
   ```

   The server should start and display a message indicating it's ready. Press `Ctrl+C` to stop.

## Configuration

### Claude Desktop

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "patrol": {
      "command": "dart",
      "args": [
        "run",
        "/absolute/path/to/patrol_mcp/bin/patrol_mcp.dart"
      ],
      "env": {
        "FLUTTER_PROJECT_PATH": "/path/to/your/flutter/app",
        "PATROL_DEVICE": "iPhone 17 Pro",
        "PATROL_BUNDLE_ID": "com.kodez.shoppingApp"
      }
    }
  }
}
```

Restart Claude Desktop after adding the configuration.

### Claude Code CLI

```bash
claude mcp add patrol dart run /absolute/path/to/patrol_mcp/bin/patrol_mcp.dart
```

## Tool Examples

### 1. patrol_list_tests

List all patrol tests in the project.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "patrol_list_tests",
    "arguments": {
      "test_dir": "integration_test/"
    }
  }
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"tests\":[{\"name\":\"Navigate from product list to product detail\",\"file\":\"integration_test/app_test.dart\",\"line\":20,\"type\":\"patrolTest\"},{\"name\":\"Add product to cart\",\"file\":\"integration_test/app_test.dart\",\"line\":45,\"type\":\"patrolTest\"}],\"total\":2}"
      }
    ]
  }
}
```

### 2. patrol_run_tests

Run patrol tests and get structured results.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "patrol_run_tests",
    "arguments": {
      "target": "integration_test/app_test.dart",
      "device": "iPhone 17 Pro"
    }
  }
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"status\":\"passed\",\"total\":2,\"passed\":2,\"failed\":0,\"skipped\":0,\"duration\":\"1m 23s\",\"failures\":[],\"raw_log\":\"...\"}"
      }
    ]
  }
}
```

### 3. patrol_get_last_results

Parse the latest xcresult bundle.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "patrol_get_last_results",
    "arguments": {
      "project_path": "/path/to/flutter/project"
    }
  }
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"xcresult_path\":\"/path/to/build/ios_results_123.xcresult\",\"tests\":[{\"name\":\"Navigate from product list to product detail\",\"status\":\"passed\",\"duration\":12.5}]}"
      }
    ]
  }
}
```

### 4. patrol_screenshot

Take a screenshot of the simulator.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "tools/call",
  "params": {
    "name": "patrol_screenshot",
    "arguments": {}
  }
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"path\":\"/tmp/patrol_screenshot_1234567890.png\",\"base64\":\"iVBORw0KGgoAAAANSUhEUgAA...\",\"device\":\"iPhone 17 Pro\",\"timestamp\":\"2026-04-26T12:00:00.000Z\"}"
      }
    ]
  }
}
```

### 5. patrol_get_widget_tree

Get the live widget tree from running Flutter app.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "method": "tools/call",
  "params": {
    "name": "patrol_get_widget_tree",
    "arguments": {
      "flatten": true,
      "keys_only": false
    }
  }
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"screen\":\"ProductListPage\",\"timestamp\":\"2026-04-26T12:00:00.000Z\",\"widgets\":[{\"key\":\"product_list_appbar\",\"type\":\"AppBar\",\"depth\":2,\"text\":\"Products\",\"testable\":true},{\"type\":\"Text\",\"depth\":5,\"text\":\"$299.99\",\"testable\":false,\"suggestion\":\"Add Key('text') for testability\"}],\"testable_count\":8,\"untestable_count\":12}"
      }
    ]
  }
}
```

### 6. patrol_generate_tests

Generate patrol test code from natural language.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 6,
  "method": "tools/call",
  "params": {
    "name": "patrol_generate_tests",
    "arguments": {
      "instruction": "Generate a test that verifies the product list page loads",
      "output_file": "integration_test/generated_test.dart"
    }
  }
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "id": 6,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"generated_code\":\"import 'package:flutter/material.dart';\\nimport 'package:flutter_test/flutter_test.dart';\\nimport 'package:patrol/patrol.dart';\\nimport 'package:shopping_app/main.dart' as app;\\n\\nvoid main() {\\n  patrolTest(\\n    'Verify the product list page loads',\\n    (\\$) async {\\n      app.main();\\n      await \\$.pumpAndSettle(timeout: const Duration(seconds: 15));\\n      await Future.delayed(const Duration(seconds: 3));\\n      await \\$.pumpAndSettle();\\n      expect(\\$(#product_list_appbar), findsOneWidget);\\n    },\\n  );\\n}\",\"output_file\":\"integration_test/generated_test.dart\",\"tests_generated\":1,\"widgets_covered\":[\"product_list_appbar\"]}"
      }
    ]
  }
}
```

## Usage with Claude

Once configured, you can interact with Claude naturally:

**Examples:**

- "List all the patrol tests in my project"
- "Run the patrol tests in integration_test/app_test.dart"
- "Show me the results from the last test run"
- "Take a screenshot of the current simulator"
- "What widgets are currently visible in the app?"
- "Generate a test that verifies the product list loads correctly"

Claude will automatically use the appropriate MCP tools to fulfill your requests.

## Project Structure

```
patrol_mcp/
├── bin/
│   └── patrol_mcp.dart           # MCP server entry point
├── lib/
│   └── src/
│       ├── server.dart            # MCP protocol handler
│       ├── tools/
│       │   ├── run_tests.dart     # patrol_run_tests tool
│       │   ├── get_results.dart   # patrol_get_last_results tool
│       │   ├── list_tests.dart    # patrol_list_tests tool
│       │   ├── screenshot.dart    # patrol_screenshot tool
│       │   ├── widget_tree.dart   # patrol_get_widget_tree tool
│       │   └── generate_tests.dart # patrol_generate_tests tool
│       └── utils/
│           ├── xcresult_parser.dart
│           ├── vm_service_client.dart
│           └── test_file_parser.dart
├── pubspec.yaml
├── README.md
└── CLAUDE.md                      # Detailed usage guide for Claude
```

## Error Handling

All tools return structured error responses:

```json
{
  "error": true,
  "code": "ERROR_CODE",
  "message": "Human-readable error message",
  "suggestion": "Actionable next step",
  "stack": "Stack trace (if applicable)"
}
```

Common error codes:
- `PATROL_CLI_NOT_FOUND`: patrol_cli not installed or not in PATH
- `NO_BOOTED_DEVICE`: No iOS simulator is currently booted
- `VM_SERVICE_NOT_FOUND`: Cannot detect Flutter VM service URL
- `VM_SERVICE_CONNECTION_FAILED`: Failed to connect to VM service
- `NO_XCRESULT_FOUND`: No test results available
- `SCREENSHOT_FAILED`: Failed to capture screenshot

## Troubleshooting

See [CLAUDE.md](CLAUDE.md) for detailed troubleshooting steps.

Quick fixes:

1. **patrol_cli not found**: `dart pub global activate patrol_cli`
2. **No booted simulator**: `xcrun simctl boot <device-id>`
3. **VM service not found**: Start Flutter with `flutter run --observatory-port=8181`
4. **No test results**: Run tests first with `patrol test`

## Development

### Running Tests

```bash
dart test
```

### Linting

```bash
dart analyze
```

### Format Code

```bash
dart format .
```

## Contributing

We welcome contributions from the community! Whether you're fixing bugs, adding features, or improving documentation, your help is appreciated.

Please read our [Contributing Guide](CONTRIBUTING.md) for details on:
- Code of Conduct
- Development workflow
- Coding standards
- How to submit pull requests

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Related Projects

- [Patrol](https://github.com/leancodepl/patrol) - Flutter E2E testing framework
- [MCP](https://modelcontextprotocol.io/) - Model Context Protocol specification
- [Claude](https://claude.ai/) - AI assistant by Anthropic

## Support

### Getting Help

- **Issues**: Found a bug or have a feature request? [Open an issue](https://github.com/yourusername/patrol-mcp-server/issues)
- **Discussions**: Questions or ideas? Start a [discussion](https://github.com/yourusername/patrol-mcp-server/discussions)
- **Documentation**: Check our [detailed guides](CLAUDE.md) and [troubleshooting section](#troubleshooting)

### Related Resources

- **Patrol Framework**: [Official Documentation](https://patrol.leancode.co/)
- **MCP Specification**: [Model Context Protocol](https://modelcontextprotocol.io/)
- **Claude**: [Anthropic's AI Assistant](https://claude.ai/)

## Acknowledgments

This project builds upon the excellent work of:
- The [Patrol team](https://github.com/leancodepl/patrol) for creating a powerful Flutter E2E testing framework
- [Anthropic](https://anthropic.com/) for developing the Model Context Protocol
- The Flutter community for their continuous support and feedback

---

Made with ❤️ for the Flutter testing community
