--!strict
--[[
	RunTests.luau
	Main test runner script for the Sandboxer test suite.
	
	This script:
	1. Loads all test files
	2. Executes all test suites
	3. Reports results
	4. Returns exit code (0 for success, 1 for failure)
]]

local TestFramework = require("@self/TestFramework")

-- Print header
print("\n" .. string.rep("=", 70))
print("SANDBOXER TEST SUITE")
print(string.rep("=", 70))
print("Running comprehensive tests for all modules...")
print("")

local totalSuites = 0
local totalTests = 0
local totalPassed = 0
local totalFailed = 0

for _, moduleName in script.Tests:GetChildren() do
	print(`Loading {moduleName}...`)
	local success, err = pcall(require, moduleName)

	if not success then
		warn(`Failed to load test module '{moduleName}': {err}`)
	else
		totalSuites += 1
	end
end

print(`\nLoaded {totalSuites} test suite(s)\n`)

-- Get and print results
local results = TestFramework.runTests()
local allPassed = TestFramework.printResults(results)

-- Calculate totals
for _, suite in results do
	totalTests += #suite.tests
	totalPassed += suite.passed
	totalFailed += suite.failed
end

-- Print summary
print("\n" .. string.rep("=", 70))
print("FINAL SUMMARY")
print(string.rep("=", 70))
print(`Test Suites: {totalSuites}`)
print(`Total Tests: {totalTests}`)
print(`Passed: {totalPassed} ({if totalTests > 0 then math.floor((totalPassed / totalTests) * 100) else 0}%)`)
print(`Failed: {totalFailed} ({if totalTests > 0 then math.floor((totalFailed / totalTests) * 100) else 0}%)`)
print(string.rep("=", 70))

if allPassed then
	print("\n✓ All tests passed!")
	print("\nTest suite execution completed successfully.\n")
	return 0
else
	warn("\n✗ Some tests failed!")
	warn("\nTest suite execution completed with failures.\n")
	return 1
end
