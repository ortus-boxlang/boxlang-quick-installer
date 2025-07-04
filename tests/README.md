# BoxLang Project Test Suite

This directory contains comprehensive tests for the BoxLang project components.

## Test Files

All individual test specifications are located in the `specs/` directory and follow the naming pattern `*_test.sh`:

### `specs/helpers_test.sh`

Core test suite for basic helper functions including:

- Print functions (`print_info`, `print_success`, `print_warning`, `print_error`, `print_header`)
- Command existence check (`command_exists`)
- Color setup (`setup_colors`)
- Version comparison functions (`extract_semantic_version`, `isSnapshotVersion`, `compare_versions`)
- Integration tests

### `specs/preflight_check_test.sh`

Mock-based tests for the `preflight_check()` function:

- Tests dependency checking for `curl`, `unzip`, `jq`
- Platform-specific SHA tools testing (`shasum` on macOS, `sha256sum` on Linux)
- macOS Homebrew requirement testing
- Java version requirement testing
- Various failure scenarios

### `specs/java_version_test.sh`

Comprehensive tests for Java version detection:

- Java 21+ detection (required version)
- Insufficient version handling (Java 8, 17)
- Different Java version formats (OpenJDK, Oracle)
- Multiple installation candidate testing
- JAVA_HOME detection
- System location detection
- Version extraction function testing

### `run.sh`

Global test runner that automatically discovers and executes all test suites in the project:

- Complete test suite execution with automatic discovery
- Individual test suite execution
- Test suite listing
- Comprehensive reporting with pass/fail statistics
- Automatic discovery of all `*_test.sh` files in the specs directory
- Continues running even if individual test suites fail

## Test Discovery

The test runner automatically discovers all test files in the `specs/` directory that follow the naming pattern `*_test.sh`. This means:

- **No manual registration required** - Just add a new test file with the `*_test.sh` suffix
- **Automatic execution** - All discovered tests run when you execute `./tests/run.sh`
- **Flexible naming** - You can create `feature_test.sh`, `integration_test.sh`, etc.
- **Sorted execution** - Tests run in alphabetical order by filename

To add a new test suite:

1. Create a new file in `specs/` with the pattern `your_feature_test.sh`
2. Make it executable: `chmod +x specs/your_feature_test.sh`
3. It will automatically be discovered and run

## Running Tests

### Run All Tests

```bash
# Make the test runner executable
chmod +x tests/run.sh

# Run all test suites
./tests/run.sh
```

### Run Individual Test Suites

```bash
# List available test suites
./tests/run.sh --list

# Run a specific test suite
./tests/run.sh --single helpers_test
./tests/run.sh --single preflight_check_test
./tests/run.sh --single java_version_test
```

### Run Tests Directly

```bash
# Make individual test files executable
chmod +x tests/specs/helpers_test.sh
chmod +x tests/specs/preflight_check_test.sh
chmod +x tests/specs/java_version_test.sh

# Run individual tests
./tests/specs/helpers_test.sh
./tests/specs/preflight_check_test.sh
./tests/specs/java_version_test.sh
```

## Test Framework

The test suite uses a custom lightweight testing framework with:

### Assertion Functions

- `assert_equals(expected, actual, test_name)` - Compare two values
- `assert_contains(substring, string, test_name)` - Check if string contains substring
- `assert_return_code(expected_code, actual_code, test_name)` - Check function return codes

### Mock Testing

- Mock command creation for dependency testing
- Mock Java installations with different versions
- Platform-specific testing capabilities
- Temporary mock directories for isolated testing

### Test Organization

- Test groups with clear headings
- Pass/fail tracking with detailed reporting
- Failed test collection and summary
- Color-coded output for easy reading

## Test Coverage

The test suite covers:

✅ **Print Functions** - All print helper functions with various inputs
✅ **Command Detection** - Testing command existence checking
✅ **Color Setup** - Ensuring color variables are properly initialized
✅ **Version Comparison** - Semantic version parsing and comparison logic
✅ **Snapshot Detection** - Pre-release version identification
✅ **Java Version Detection** - Comprehensive Java installation testing
✅ **Preflight Checks** - Dependency validation with mock scenarios
✅ **Platform Compatibility** - macOS and Linux specific functionality
✅ **Error Handling** - Various failure scenarios and edge cases

## Requirements

The tests require:

- Bash 4.0+ (for array support)
- Standard Unix utilities (`mktemp`, `mkdir`, `rm`, `chmod`)
- Write access to `/tmp` for mock command creation

## Continuous Integration

These tests are designed to be run in CI/CD environments and will:

- Return appropriate exit codes (0 for success, 1 for failure)
- Provide detailed output for debugging failures
- Clean up temporary files and mock environments
- Work across different Unix-like operating systems

## Contributing

When adding new helper functions to `helpers.sh`:

1. Add corresponding test cases to the appropriate test file
2. If creating a new category of functions, consider creating a new test file
3. Update this README with new test coverage information
4. Ensure all tests pass before submitting changes

## Troubleshooting

### Tests Fail on Permission Issues

```bash
# Ensure test files are executable
find tests/ -name "*.sh" -exec chmod +x {} \;
```

### Mock Commands Not Working

- Check that `/tmp` is writable
- Ensure `PATH` modifications are working in your shell
- Check for conflicting environment variables

### Platform-Specific Failures

- Some tests are platform-specific (macOS vs Linux)
- Review the test output for platform detection logic
- Ensure platform-specific tools are available (`brew` on macOS)
