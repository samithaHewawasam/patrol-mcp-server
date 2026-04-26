# Connecting Patrol MCP to Claude Code

## Quick Setup

### Step 1: Add the MCP Server

Run this command from anywhere:

```bash
claude mcp add patrol dart run /Users/samithahewawasam/Documents/workspace/kodez/patrol-mcp-server/patrol_mcp/bin/patrol_mcp.dart
```

### Step 2: Set Environment Variables (Optional but Recommended)

Add to your shell profile (`~/.zshrc` or `~/.bashrc`):

```bash
# Patrol MCP Configuration
export FLUTTER_PROJECT_PATH="/path/to/your/flutter/app"
export PATROL_DEVICE="iPhone 17 Pro"
export PATROL_BUNDLE_ID="com.kodez.shoppingApp"
```

Replace `/path/to/your/flutter/app` with your actual Flutter project path.

Then reload your shell:
```bash
source ~/.zshrc  # or source ~/.bashrc
```

### Step 3: Verify the Connection

Restart Claude Code (exit and start again), then ask:

```
What MCP servers are available?
```

You should see "patrol" in the list.

### Step 4: Test a Tool

Try asking:

```
Use the patrol MCP to list all tests in my project
```

---

## Method 2: Manual Configuration

If the CLI command doesn't work, you can manually edit the MCP config file.

### Find Your Claude Code Config Directory

```bash
# Check where Claude Code stores settings
ls -la ~/.config/claude-code/
```

Or:

```bash
ls -la ~/Library/Application\ Support/Claude\ Code/
```

### Edit mcp_settings.json

Look for a file named `mcp_settings.json` or similar. Add this configuration:

```json
{
  "mcpServers": {
    "patrol": {
      "command": "dart",
      "args": [
        "run",
        "/Users/samithahewawasam/Documents/workspace/kodez/patrol-mcp-server/patrol_mcp/bin/patrol_mcp.dart"
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

---

## Testing the Connection

Once configured, test with these commands in Claude Code:

### 1. List Available Tools
```
What tools does the patrol MCP server provide?
```

### 2. List Tests
```
List all patrol tests in my project
```

### 3. Get Widget Tree (requires Flutter app running)
```
Show me the current widget tree
```

### 4. Generate a Test
```
Generate a test that verifies the product list page loads correctly
```

---

## Troubleshooting

### "MCP server not found" or "patrol not available"

1. Verify Dart is in PATH:
   ```bash
   which dart
   ```

2. Test the server manually:
   ```bash
   dart run /Users/samithahewawasam/Documents/workspace/kodez/patrol-mcp-server/patrol_mcp/bin/patrol_mcp.dart
   ```

   Should output: `Patrol MCP Server starting...`

3. Restart Claude Code completely

### "patrol_cli not found"

Install globally:
```bash
dart pub global activate patrol_cli
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

### Environment Variables Not Working

Set them directly in the MCP config instead of relying on shell variables.

---

## Usage Examples

Once connected, you can use natural language:

- "Run the patrol tests in integration_test/app_test.dart"
- "Show me the results from the last test run"
- "Take a screenshot of the simulator"
- "What widgets are currently visible?"
- "Generate tests for the login page"

Claude Code will automatically use the patrol MCP tools to fulfill these requests.

---

## Checking MCP Server Status

To see if the MCP server is running:

```bash
# Check for running Dart processes
ps aux | grep patrol_mcp
```

To view MCP server logs (if Claude Code provides them):
```bash
# Location varies by Claude Code version
tail -f ~/Library/Logs/Claude\ Code/mcp-patrol.log
```

---

## Removing the MCP Server

If you need to remove it:

```bash
claude mcp remove patrol
```

Or manually delete the entry from your MCP config file.
