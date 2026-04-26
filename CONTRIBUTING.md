# Contributing to Patrol MCP Server

Thank you for your interest in contributing to Patrol MCP Server! This document provides guidelines and instructions for contributing.

## Code of Conduct

This project adheres to a Code of Conduct that all contributors are expected to follow. Please read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before contributing.

## How Can I Contribute?

### Reporting Bugs

Before creating a bug report, please check existing issues to avoid duplicates. When creating a bug report, include:

- **Clear title and description**
- **Steps to reproduce** the issue
- **Expected behavior** vs actual behavior
- **Environment details**:
  - Dart SDK version
  - Flutter SDK version
  - Xcode version (for iOS testing)
  - patrol_cli version
  - Operating system
- **Error messages** and stack traces
- **Code samples** or test cases demonstrating the issue

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, include:

- **Clear title and description**
- **Use case** explaining why this enhancement would be useful
- **Proposed solution** or implementation approach
- **Alternative solutions** you've considered
- **Examples** from other projects (if applicable)

### Pull Requests

1. **Fork the repository** and create a branch from `main`
2. **Make your changes** following our coding standards
3. **Add tests** for any new functionality
4. **Update documentation** as needed
5. **Run the test suite** to ensure everything passes
6. **Submit a pull request** with a clear description

## Development Setup

### Prerequisites

- Dart SDK 3.0.0+
- Flutter SDK
- Xcode (for iOS testing)
- patrol_cli 4.3.1+

### Getting Started

```bash
# 1. Fork and clone the repository
git clone https://github.com/yourusername/patrol-mcp-server.git
cd patrol-mcp-server/patrol_mcp

# 2. Install dependencies
dart pub get

# 3. Run tests
dart test

# 4. Run the server locally
dart run bin/patrol_mcp.dart
```

## Coding Standards

### Dart Style Guide

- Follow the [official Dart style guide](https://dart.dev/guides/language/effective-dart)
- Use `dart format .` to format code before committing
- Run `dart analyze` and fix all warnings
- Keep functions small and focused
- Write descriptive variable and function names

### Code Organization

```
patrol_mcp/
├── bin/
│   └── patrol_mcp.dart       # Entry point
├── lib/
│   └── src/
│       ├── server.dart        # MCP protocol handler
│       ├── tools/             # MCP tool implementations
│       │   ├── run_tests.dart
│       │   ├── get_results.dart
│       │   ├── list_tests.dart
│       │   ├── screenshot.dart
│       │   ├── widget_tree.dart
│       │   └── generate_tests.dart
│       └── utils/             # Utility functions
│           ├── xcresult_parser.dart
│           ├── vm_service_client.dart
│           └── test_file_parser.dart
└── test/                      # Test files mirror lib/ structure
```

### Error Handling

All tools must return structured errors:

```dart
{
  "error": true,
  "code": "ERROR_CODE",
  "message": "Human-readable error message",
  "suggestion": "Actionable next step",
  "stack": "Stack trace (when applicable)"
}
```

Common error codes:
- `PATROL_CLI_NOT_FOUND`
- `NO_BOOTED_DEVICE`
- `VM_SERVICE_NOT_FOUND`
- `VM_SERVICE_CONNECTION_FAILED`
- `NO_XCRESULT_FOUND`
- `SCREENSHOT_FAILED`

### Testing

- Write tests for all new functionality
- Maintain or improve code coverage
- Use descriptive test names
- Test both success and error cases
- Mock external dependencies when appropriate

```dart
test('patrol_run_tests returns structured results on success', () async {
  // Test implementation
});

test('patrol_run_tests handles patrol_cli not found error', () async {
  // Test implementation
});
```

### Documentation

- Document all public APIs
- Include code examples in doc comments
- Update README.md for user-facing changes
- Update CLAUDE.md for AI integration changes
- Keep CHANGELOG.md up to date

```dart
/// Runs patrol tests and returns structured results.
///
/// Parameters:
/// - [target]: Path to test file (e.g., "integration_test/app_test.dart")
/// - [device]: Device name (e.g., "iPhone 17 Pro")
/// - [testName]: Optional specific test name to run
///
/// Returns a JSON object with test results including:
/// - status: "passed", "failed", or "error"
/// - total, passed, failed, skipped counts
/// - duration
/// - failures array with details
///
/// Example:
/// ```dart
/// final result = await runTests(
///   target: "integration_test/app_test.dart",
///   device: "iPhone 17 Pro",
/// );
/// ```
Future<Map<String, dynamic>> runTests({...}) async {
  // Implementation
}
```

## Git Workflow

### Branching

- `main` - stable release branch
- `develop` - development branch (if used)
- `feature/feature-name` - new features
- `fix/bug-description` - bug fixes
- `docs/description` - documentation updates

### Commit Messages

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Examples:
```
feat(tools): add support for Android testing

fix(widget_tree): handle null widget keys gracefully

docs(readme): update installation instructions

test(run_tests): add error handling test cases
```

### Pull Request Process

1. **Update your fork** with the latest changes from `main`
2. **Create a feature branch** with a descriptive name
3. **Make your changes** following coding standards
4. **Write/update tests** to cover your changes
5. **Run the full test suite** and ensure it passes
6. **Update documentation** if needed
7. **Push your branch** to your fork
8. **Create a pull request** with:
   - Clear title following commit message format
   - Description of what changes were made and why
   - Reference to related issues (e.g., "Fixes #123")
   - Screenshots or examples (if applicable)
9. **Respond to review feedback** promptly
10. **Squash commits** if requested before merging

### Review Process

- All pull requests require at least one approval
- Maintainers will review PRs within a few days
- Address review comments by pushing new commits
- Once approved, maintainers will merge your PR

## Release Process

Releases follow [Semantic Versioning](https://semver.org/):

- **MAJOR** version: Incompatible API changes
- **MINOR** version: New functionality (backwards compatible)
- **PATCH** version: Bug fixes (backwards compatible)

## Getting Help

- **Questions**: Open a [GitHub Discussion](https://github.com/yourusername/patrol-mcp-server/discussions)
- **Issues**: Check existing issues or create a new one
- **Documentation**: Review [README.md](README.md) and [CLAUDE.md](CLAUDE.md)

## Recognition

Contributors will be recognized in:
- GitHub contributors page
- Release notes
- Project documentation

Thank you for contributing to Patrol MCP Server!
