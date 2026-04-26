# Patrol MCP Server — Usage Guide for Claude

This MCP server enables Claude to autonomously run, inspect, and generate Flutter Patrol integration tests.

## Starting the MCP Server

### Prerequisites

- Dart SDK 3.0.0 or higher
- patrol_cli 4.3.1 installed globally: `dart pub global activate patrol_cli`
- Xcode 26 or compatible version (for iOS testing)
- Flutter project with Patrol tests in `integration_test/` directory

### Installation

1. Navigate to the patrol_mcp directory:
```bash
cd patrol_mcp
```

2. Install dependencies:
```bash
dart pub get
```

3. Test the server:
```bash
dart run bin/patrol_mcp.dart
```

The server communicates via JSON-RPC 2.0 over stdin/stdout.

## Connecting to Claude Desktop

Add this configuration to your Claude Desktop config file (`~/Library/Application Support/Claude/claude_desktop_config.json` on macOS):

```json
{
  "mcpServers": {
    "patrol": {
      "command": "dart",
      "args": [
        "run",
        "/FULL/PATH/TO/patrol_mcp/bin/patrol_mcp.dart"
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

Replace `/FULL/PATH/TO/patrol_mcp` with the absolute path to the patrol_mcp directory.

Restart Claude Desktop after adding the configuration.

## Connecting to Claude Code

For Claude Code CLI, add to your MCP settings:

```bash
claude mcp add patrol dart run /FULL/PATH/TO/patrol_mcp/bin/patrol_mcp.dart
```

Set environment variables:
```bash
export FLUTTER_PROJECT_PATH=/path/to/your/flutter/app
export PATROL_DEVICE="iPhone 17 Pro"
export PATROL_BUNDLE_ID=com.kodez.shoppingApp
```

## Available Tools

### 1. patrol_list_tests

Lists all patrol tests in the project.

**Input:**
```json
{
  "test_dir": "integration_test/"
}
```

**Output:**
```json
{
  "tests": [
    {
      "name": "Navigate from product list to product detail",
      "file": "integration_test/app_test.dart",
      "line": 20,
      "type": "patrolTest"
    }
  ],
  "total": 5
}
```

**Example usage with Claude:**
> "List all available patrol tests"

---

### 2. patrol_run_tests

Runs patrol tests and returns structured results.

**Input:**
```json
{
  "target": "integration_test/app_test.dart",
  "device": "iPhone 17 Pro",
  "test_name": "specific test name"
}
```

**Output:**
```json
{
  "status": "failed",
  "total": 5,
  "passed": 3,
  "failed": 2,
  "skipped": 0,
  "duration": "1m 3s",
  "failures": [
    {
      "test": "Navigate from product list",
      "file": "integration_test/app_test.dart",
      "line": 28,
      "error": "Expected exactly one matching candidate",
      "actual": "Found 0 widgets with key product_list_appbar",
      "stack": "..."
    }
  ],
  "raw_log": "..."
}
```

**Example usage with Claude:**
> "Run the patrol tests in integration_test/app_test.dart"

---

### 3. patrol_get_last_results

Parses the latest xcresult bundle from previous test runs.

**Input:**
```json
{
  "project_path": "/path/to/flutter/project"
}
```

**Output:**
```json
{
  "xcresult_path": "/path/to/build/ios_results_*.xcresult",
  "tests": [
    {
      "name": "test name",
      "status": "failed",
      "duration": 5.8,
      "failure_message": "...",
      "file": "...",
      "line": 28
    }
  ]
}
```

**Example usage with Claude:**
> "Show me the results from the last test run"

---

### 4. patrol_screenshot

Takes a screenshot of the current simulator state.

**Input:**
```json
{
  "device_id": "E7E12833-38D9-4826-B10B-8F8F5A713B0D",
  "output_path": "/tmp/screenshot.png"
}
```

**Output:**
```json
{
  "path": "/tmp/patrol_screenshot_1234.png",
  "base64": "iVBORw0KGgoAAAANSUhEUgAA...",
  "device": "iPhone 17 Pro",
  "timestamp": "2026-04-26T12:00:00Z"
}
```

**Example usage with Claude:**
> "Take a screenshot of the current simulator"

---

### 5. patrol_get_widget_tree

Connects to Flutter VM Service and returns the live widget tree. **This is the most powerful tool for test generation.**

**Input:**
```json
{
  "vm_service_url": "ws://127.0.0.1:8181/ws",
  "flatten": true,
  "keys_only": false
}
```

**Output:**
```json
{
  "screen": "ProductListPage",
  "timestamp": "2026-04-26T12:00:00Z",
  "widgets": [
    {
      "key": "product_list_appbar",
      "type": "AppBar",
      "depth": 2,
      "text": "Products",
      "testable": true,
      "bounds": {"x": 0, "y": 0, "width": 390, "height": 96}
    },
    {
      "key": null,
      "type": "Text",
      "depth": 5,
      "text": "$299.99",
      "testable": false,
      "suggestion": "Add Key('text') for testability"
    }
  ],
  "untestable_count": 12,
  "testable_count": 8
}
```

**Example usage with Claude:**
> "Show me the current widget tree of the running app"

#### Auto-Detecting VM Service URL

The tool automatically detects the VM Service URL from:
1. Running Flutter processes (checks for `--observatory-port` flag)
2. Process arguments containing VM service URLs
3. Common Flutter ports (8181, 8080, 8888)

To ensure detection works, start your Flutter app with:
```bash
flutter run --observatory-port=8181
```

Or let Patrol handle it:
```bash
patrol test -t integration_test/app_test.dart -d "iPhone 17 Pro"
```

If auto-detection fails, provide the URL explicitly:
```json
{
  "vm_service_url": "ws://127.0.0.1:8181/ws"
}
```

---

### 6. patrol_generate_tests

Generates patrol test code based on widget tree and natural language instruction.

**Input:**
```json
{
  "instruction": "Generate tests for the product list page",
  "widget_tree": {},
  "output_file": "integration_test/generated_test.dart",
  "test_style": "single"
}
```

**Output:**
```json
{
  "generated_code": "import 'package:patrol/patrol.dart';\n\nvoid main() {\n  patrolTest(...)\n}",
  "output_file": "integration_test/generated_test.dart",
  "tests_generated": 1,
  "widgets_covered": ["product_list_appbar", "product_grid", "product_card_1"]
}
```

**Example usage with Claude:**
> "Generate a test that verifies the product list page loads correctly"

The tool automatically fetches the widget tree if not provided, then generates test code following the working Patrol pattern.

---

## Troubleshooting

### Simulator Not Booted

**Error:**
```json
{
  "error": true,
  "code": "NO_BOOTED_DEVICE",
  "message": "No booted simulator found"
}
```

**Solution:**
```bash
# List available devices
xcrun simctl list devices available

# Boot a simulator
xcrun simctl boot <device-id>
```

### VM Service Not Found

**Error:**
```json
{
  "error": true,
  "code": "VM_SERVICE_NOT_FOUND",
  "message": "Could not detect Flutter VM Service URL"
}
```

**Solutions:**
1. Ensure Flutter app is running:
   ```bash
   flutter run --observatory-port=8181
   ```

2. Check for running Flutter processes:
   ```bash
   ps aux | grep flutter
   ```

3. Provide VM service URL explicitly in the tool call

### patrol_cli Not in PATH

**Error:**
```json
{
  "error": true,
  "code": "PATROL_CLI_NOT_FOUND",
  "message": "patrol_cli not found in PATH"
}
```

**Solution:**
```bash
# Install patrol_cli globally
dart pub global activate patrol_cli

# Ensure Dart global bin is in PATH
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

### xcresult Bundle Not Found

**Error:**
```json
{
  "error": true,
  "code": "NO_XCRESULT_FOUND",
  "message": "No xcresult bundle found in build directory"
}
```

**Solution:**
Run patrol tests first to generate results:
```bash
patrol test -t integration_test/app_test.dart -d "iPhone 17 Pro"
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Claude (AI)                           │
└─────────────────────────┬───────────────────────────────────┘
                          │ JSON-RPC 2.0
                          │ (stdin/stdout)
┌─────────────────────────▼───────────────────────────────────┐
│                   Patrol MCP Server                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  MCP Protocol Handler (server.dart)                   │  │
│  └─────────┬─────────────────────────────────────────────┘  │
│            │                                                  │
│  ┌─────────▼──────────────────────────────────────────────┐ │
│  │  Tools Layer                                            │ │
│  │  • patrol_list_tests     • patrol_screenshot           │ │
│  │  • patrol_run_tests      • patrol_get_widget_tree      │ │
│  │  • patrol_get_last_results • patrol_generate_tests     │ │
│  └─────────┬──────────────────────────────────────────────┘ │
│            │                                                  │
│  ┌─────────▼──────────────────────────────────────────────┐ │
│  │  Utilities Layer                                        │ │
│  │  • test_file_parser.dart                               │ │
│  │  • xcresult_parser.dart                                │ │
│  │  • vm_service_client.dart                              │ │
│  └─────────┬──────────────────────────────────────────────┘ │
└────────────┼──────────────────────────────────────────────────┘
             │
    ┌────────┼─────────┬──────────────┬─────────────────┐
    │        │         │              │                 │
┌───▼──┐ ┌──▼────┐ ┌──▼────────┐ ┌───▼──────┐ ┌──────▼──────┐
│patrol│ │xcrun  │ │VM Service │ │Flutter   │ │File System  │
│ CLI  │ │simctl │ │(websocket)│ │Process   │ │(Dart files) │
└──────┘ └───────┘ └───────────┘ └──────────┘ └─────────────┘
```

---

## Test Pattern

All generated tests follow this working pattern for iOS 26 / Xcode 26:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shopping_app/main.dart' as app;

void main() {
  patrolTest(
    'Test name here',
    ($) async {
      // Launch the app — required for iOS 26 / Xcode 26
      app.main();

      // Wait for full initialization
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));
      await Future.delayed(const Duration(seconds: 3));
      await $.pumpAndSettle();

      // Test assertions using widget keys
      expect($(#product_list_appbar), findsOneWidget);
      await $(#product_card_1).tap();
      await $.pumpAndSettle();
    },
  );
}
```

Key requirements:
- Call `app.main()` to launch the app
- Use generous timeouts and delays for initialization
- Use symbol syntax `$(#key)` for widget selectors
- Always call `pumpAndSettle()` after interactions

---

## Tips for Claude

When working with this MCP server:

1. **Always list tests first** to understand what's available
2. **Check widget tree** before generating tests to ensure accurate selectors
3. **Run tests incrementally** - start with one test file at a time
4. **Use screenshots** to debug visual issues
5. **Parse xcresult** to get detailed failure information
6. **Generate tests** based on actual widget tree, not assumptions

Example workflow:
```
1. List tests → see what exists
2. Get widget tree → understand current UI state
3. Generate test → create new test based on widget tree
4. Run test → verify it works
5. Get results → analyze any failures
6. Take screenshot → debug visual issues
```

---

## Error Handling

All tools return structured errors with:
- `error`: boolean flag
- `code`: error code for programmatic handling
- `message`: human-readable error message
- `suggestion`: actionable next step
- `stack`: stack trace (when applicable)

Example:
```json
{
  "error": true,
  "code": "SIMULATOR_NOT_BOOTED",
  "message": "No booted simulator found",
  "suggestion": "Boot a simulator: xcrun simctl boot <device-id>"
}
```

All operations have timeouts:
- Test runs: 5 minutes
- All other operations: 30 seconds
- VM service connections: 3 retry attempts with exponential backoff

---

## Environment Variables

The MCP server recognizes these environment variables:

- `FLUTTER_PROJECT_PATH`: Default Flutter project path
- `PATROL_DEVICE`: Default simulator device name
- `PATROL_BUNDLE_ID`: App bundle ID for iOS

Set these in your Claude Desktop config or shell environment.
