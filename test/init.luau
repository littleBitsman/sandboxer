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

assert(game, "Must run in Roblox")
local script = script :: any

local TestFramework = require("@self/TestFramework")

-- Print header
print()
print(string.rep("=", 60))
print("SANDBOXER TEST SUITE")
print(string.rep("=", 60))
print("Running comprehensive tests for all modules...")
print()

local totalSuites = 0
local totalTests = 0
local totalPassed = 0
local totalFailed = 0

local startTime = os.clock()
for _, moduleName in script.tests:GetChildren() do
	print(`Loading {moduleName}...`)
	local success, err = pcall(require, moduleName)

	if not success then
		warn(`Failed to load test module '{moduleName}': {err}`)
	else
		totalSuites += 1
	end
end
local TestTime = os.clock() - startTime

print()
print("Loaded", totalSuites, "test suite(s)")
print()

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
print()
print(string.rep("=", 60))
print("FINAL SUMMARY")
print(string.rep("=", 60))
print(`Test Suites: {totalSuites}`)
print(`Total Tests: {totalTests}`)
print(`Passed: {totalPassed} ({if totalTests > 0 then math.floor((totalPassed / totalTests) * 100) else 0}%)`)
print(`Failed: {totalFailed} ({if totalTests > 0 then math.floor((totalFailed / totalTests) * 100) else 0}%)`)
print()
print("Execution Time: " .. string.format("%.2f", TestTime) .. " seconds")
print(string.rep("=", 60))

local returnInfo = {
	suites = totalSuites,
	total = totalTests,
	passed = totalPassed,
	failed = totalFailed,
	success = allPassed,

	time = TestTime
}

if allPassed then
	print()
	print("✓ All tests passed!")
	print()
	print("Test suite execution completed successfully.\n")
else
	warn()
	warn("✗ Some tests failed!")
	warn()
	warn("Test suite execution completed with failures.\n")
end
return returnInfo