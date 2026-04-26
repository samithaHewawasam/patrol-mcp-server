# Quick Setup Guide

## 1. Install Dependencies

```bash
cd patrol_mcp
dart pub get
```

## 2. Verify Installation

```bash
dart analyze
```

Expected output: `No issues found!`

## 3. Test the Server

```bash
dart run bin/patrol_mcp.dart
```

Expected output: `Patrol MCP Server starting...`

Press Ctrl+C to stop the server.

## 4. Configure Claude Desktop

1. Open your Claude Desktop config file:
   - macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
   - Windows: `%APPDATA%\Claude\claude_desktop_config.json`
   - Linux: `~/.config/Claude/claude_desktop_config.json`

2. Copy the contents from `claude_config_snippet.json`

3. Replace the placeholders:
   - `/FULL/PATH/TO/patrol_mcp` → absolute path to this directory
   - `/path/to/your/flutter/app` → absolute path to your Flutter project
   - `iPhone 17 Pro` → your target simulator (optional)
   - `com.kodez.shoppingApp` → your app's bundle ID (optional)

4. Restart Claude Desktop

## 5. Test with Claude

Open Claude Desktop and try:

```
List all patrol tests in my project
```

Claude should use the `patrol_list_tests` tool to respond.

## Troubleshooting

### "patrol_cli not found"

Install it globally:
```bash
dart pub global activate patrol_cli
```

Add to PATH (add to ~/.zshrc or ~/.bashrc):
```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

### "No such file or directory"

Ensure you're using absolute paths in the Claude Desktop config, not relative paths like `~/...`.

Replace `~` with the full path:
```bash
# Wrong
~/Documents/patrol_mcp

# Correct
/Users/yourname/Documents/patrol_mcp
```

### "Connection refused" or "VM Service not found"

Start your Flutter app with the observatory port:
```bash
flutter run --observatory-port=8181
```

Or use patrol directly:
```bash
patrol test -t integration_test/app_test.dart
```

## Next Steps

1. Read `README.md` for detailed documentation
2. Read `CLAUDE.md` for Claude-specific usage guide
3. Run `patrol test` in your Flutter project to verify patrol_cli works
4. Ask Claude to "show me the widget tree" while your app is running

## Environment Variables

Optional environment variables you can set:

```bash
export FLUTTER_PROJECT_PATH=/path/to/your/flutter/app
export PATROL_DEVICE="iPhone 17 Pro"
export PATROL_BUNDLE_ID=com.kodez.shoppingApp
```

These can be set in:
- Your shell profile (`~/.zshrc`, `~/.bashrc`)
- Claude Desktop config (recommended)
- Or passed when running the server manually

## Verify Everything Works

1. Boot a simulator:
```bash
xcrun simctl list devices
xcrun simctl boot <device-id>
```

2. Run a patrol test:
```bash
cd /path/to/your/flutter/app
patrol test -t integration_test/app_test.dart -d "iPhone 17 Pro"
```

3. Ask Claude to analyze the results:
```
Show me the results from the last patrol test run
```

## Project Structure

```
patrol_mcp/
├── bin/patrol_mcp.dart        # Entry point (run this)
├── lib/src/
│   ├── server.dart            # MCP protocol handler
│   ├── tools/                 # 6 MCP tools
│   └── utils/                 # Helper utilities
├── pubspec.yaml               # Dependencies
├── claude_config_snippet.json # Copy this to Claude config
├── SETUP.md                   # This file
├── README.md                  # Full documentation
└── CLAUDE.md                  # Usage guide for Claude
```
