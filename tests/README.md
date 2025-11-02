# Sandboxer Test Suite

This directory contains a comprehensive test suite for the Sandboxer project. The test suite is designed to validate all critical functionalities, edge cases, and boundary conditions to ensure the robustness and security of the sandboxing system.

## Overview

The test suite covers three main modules:
1. **InstanceList** - Instance allow/disallow logic, wrapping/unwrapping
2. **InstanceSandboxer** - Instance and signal wrapping, function hooking, deep wrap/unwrap
3. **Sandboxer** - Main sandboxing functionality, environment isolation, security restrictions

## Structure

```
tests/
├── README.md                    # This file
├── TestFramework.luau          # Lightweight testing framework
├── RunTests.luau               # Main test runner
├── ExampleTestUsage.luau       # Example showing how to use the test suite
├── InstanceList.test.luau      # Tests for InstanceList module
├── InstanceSandboxer.test.luau # Tests for InstanceSandboxer module
├── Sandboxer.test.luau         # Tests for Sandboxer module
└── Integration.test.luau       # Integration tests for complex scenarios
```

## Test Framework

The test suite uses a custom lightweight testing framework (`TestFramework.luau`) that provides:

- **Test Organization**: `describe()` and `it()` functions for structuring tests
- **Assertions**: `expect()` API with various matchers (toBe, toEqual, toThrow, etc.)
- **Lifecycle Hooks**: `beforeEach()` and `afterEach()` for test setup/teardown
- **Test Reporting**: Detailed console output with pass/fail status

### Assertion API

The `expect()` function provides the following matchers:

- `toBe(expected)` - Checks equality using `==`
- `toEqual(expected)` - Deep equality check for tables
- `toBeNil()` - Checks if value is nil
- `toBeType(expectedType)` - Checks typeof value
- `toBeTruthy()` - Checks if value is truthy
- `toBeFalsy()` - Checks if value is falsy
- `toThrow(expectedError?)` - Checks if function throws (optionally with specific error)
- `toContain(item)` - Checks if table/string contains item

## Test Coverage

### InstanceList Tests (80+ test cases)

- **Allow/Disallow Logic**
  - Service instance permissions
  - Descendant handling
  - Default allow list behavior
  
- **ForbiddenClasses**
  - Class-based filtering
  - IsA() checking

- **ExplicitDisallow**
  - Specific instance blocking
  - Descendant exception handling

- **Wrapping/Unwrapping**
  - Instance wrapping
  - Signal wrapping
  - Wrap state tracking

- **Edge Cases**
  - Nil inputs
  - Invalid types
  - Destroyed instances
  - Multiple rules interaction

### InstanceSandboxer Tests (100+ test cases)

- **Instance Wrapping**
  - Allowed instance wrapping
  - Disallowed instance handling
  - Wrap caching
  - Unwrapping

- **Signal Wrapping**
  - RBXScriptSignal wrapping
  - Signal caching
  - Signal unwrapping

- **Deep Wrapping/Unwrapping**
  - Simple values
  - Tables with instances
  - Nested tables
  - Circular references
  - Functions
  - Mixed type tables

- **Argument Processing**
  - Single/multiple arguments
  - Nil preservation
  - Wrapping/unwrapping

- **Function Wrapping**
  - Function caching
  - Argument transformation
  - Result transformation
  - Reverse wrapping

- **Function Hooking**
  - Method interception
  - Hook removal
  - Invalid method handling

- **Edge Cases**
  - Nil handling
  - Double wrapping
  - Empty tables
  - Numeric keys
  - Very large tables
  - Deeply nested structures

### Sandboxer Tests (70+ test cases)

- **Module Structure**
  - API exports
  - Metatable locking

- **Configuration**
  - Custom globals
  - Forbidden global rejection
  - Global removal
  - Configuration validation

- **Sandboxing**
  - Function sandboxing
  - Level-based sandboxing
  - Double-sandbox prevention
  - String sandboxing (loadstring)

- **Environment Isolation**
  - Sandboxed game/workspace
  - Isolated _G and shared tables
  - No environment leakage

- **Security Restrictions**
  - getfenv removal
  - setfenv removal
  - loadstring removal
  - debug library removal
  - xpcall replacement
  - SharedTable removal

- **Safe Globals**
  - Standard library availability
  - Roblox libraries (math, string, table, task)
  - Roblox datatypes (Vector3, CFrame, etc.)

- **HttpService Restrictions**
  - GetAsync disabled
  - PostAsync disabled
  - RequestAsync disabled
  - GetSecret disabled

- **Edge Cases**
  - Multiple sandboxing
  - Empty configurations
  - Long code strings
  - Nested functions
  - Error handling

### Integration Tests (50+ test cases)

- **Multi-Module Interactions**
  - Instance creation and manipulation
  - Event handling with wrapped instances
  - Service access patterns
  - Complex data structures

- **Real-World Scenarios**
  - Async operations (task.wait, task.spawn, task.defer)
  - Math and computation
  - String and table operations
  - Error handling and propagation

- **Security Testing**
  - Bypass attempt prevention
  - Metatable manipulation protection
  - Function environment isolation
  - Resource access control

- **Performance Testing**
  - Many wrapped instances
  - Large data structure wrapping
  - Rapid creation/destruction

- **Advanced Features**
  - Custom sandbox configurations
  - Function hooking in real scenarios
  - Module requiring system
  - Resource cleanup

## Running the Tests

### In Roblox Studio

1. Place the `tests` folder in your Roblox project (e.g., in ReplicatedStorage)
2. Place the `src` folder with the Sandboxer modules in the appropriate location
3. Create a script and run:

```lua
local RunTests = require(path.to.tests.RunTests)
```

### Using the Example Script

For a demonstration of how to use the test framework:

```lua
local ExampleTestUsage = require(path.to.tests.ExampleTestUsage)
```

This example demonstrates:
- Running all tests
- Running specific test files
- Creating custom tests
- Using lifecycle hooks (beforeEach, afterEach)
- Testing sandboxed code

### Expected Output

The test runner will:
1. Load all test modules
2. Execute all test suites sequentially
3. Display results for each test case
4. Show a final summary with pass/fail statistics

Example output:
```
======================================================================
SANDBOXER TEST SUITE
======================================================================
Running comprehensive tests for all modules...

Loading InstanceList.test...
Loading InstanceSandboxer.test...
Loading Sandboxer.test...

Loaded 3 test suite(s)

============================================================
TEST RESULTS
============================================================

InstanceList - Allow/Disallow Logic
------------------------------------------------------------
  ✓ should allow game instance
  ✓ should allow workspace and its descendants
  ✓ should allow Lighting service
  ...

============================================================
TOTAL: 250 passed, 0 failed, 0 skipped
============================================================

✓ All tests passed!
```

## Adding New Tests

To add new test cases:

1. Open the relevant test file (or create a new one)
2. Add a new `describe()` block or add `it()` cases to existing blocks:

```lua
describe("New Feature", function()
    it("should do something", function()
        local result = someFunction()
        expect(result).toBe(expectedValue)
    end)
end)
```

3. Run the test suite to verify your new tests

## Best Practices

1. **Test One Thing**: Each `it()` block should test a single behavior
2. **Descriptive Names**: Use clear, descriptive names for test cases
3. **Clean Up**: Always clean up created instances in `afterEach()` or at end of test
4. **Edge Cases**: Include tests for nil, invalid inputs, and boundary conditions
5. **Security**: Test security restrictions thoroughly to prevent sandbox escapes
6. **Documentation**: Document complex test scenarios with comments

## Continuous Integration

The test suite can be integrated into CI/CD pipelines by:

1. Running tests automatically on code changes
2. Failing builds if tests don't pass
3. Generating test coverage reports
4. Tracking test metrics over time

## Known Limitations

1. **loadstring**: Some tests require `ServerScriptService.LoadStringEnabled = true`
2. **Roblox Environment**: Tests must run in a Roblox environment (Studio or server)
3. **Async Testing**: Current framework doesn't support async test patterns
4. **Mocking**: No built-in mocking capabilities

## Contributing

When adding new features to Sandboxer:

1. Write tests first (TDD approach recommended)
2. Ensure all existing tests still pass
3. Add tests for edge cases and error conditions
4. Update this README if adding new test files

## Security Testing

Special attention is given to security-related tests:

- Environment isolation verification
- Forbidden global removal
- Instance access control
- Function hooking security
- Sandbox escape prevention

All security tests should maintain or improve the security posture of the sandboxer.

## License

The test suite is part of the Sandboxer project and follows the same license (GNU Affero General Public License v3.0).
