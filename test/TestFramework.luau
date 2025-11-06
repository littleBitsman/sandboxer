--[[
	TestFramework.luau
	A lightweight testing framework for the Sandboxer project.
	
	Provides utilities for creating and running test suites with support for:
	- Test organization (describe/it blocks)
	- Assertions (expect)
	- Test lifecycle hooks (beforeEach, afterEach)
	- Detailed test reporting
]]

local TestFramework = {}

export type TestResult = {
	name: string,
	success: boolean,
	error: string?
}

export type TestSuite = {
	name: string,
	tests: {TestResult},
	passed: number,
	failed: number,
	skipped: number
}

local currentSuite: TestSuite? = nil
local allSuites: {TestSuite} = {}
local beforeEachCallbacks: {() -> ()} = {}
local afterEachCallbacks: {() -> ()} = {}

--[=[
	Creates a new test suite with the given name and test function.
	
	@param name The name of the test suite
	@param testFn Function containing test cases
]=]
function TestFramework.describe(name: string, testFn: () -> ())
	local previousSuite = currentSuite
	currentSuite = {
		name = name,
		tests = {},
		passed = 0,
		failed = 0,
		skipped = 0
	}

	beforeEachCallbacks = {}
	afterEachCallbacks = {}

	-- Run the test function to register tests
	local success, err = pcall(testFn)
	if not success then
		warn(`[TestFramework] Error in test suite '{name}': {err}`)
	end

	table.insert(allSuites, currentSuite)
	currentSuite = previousSuite
end

--[=[
	Defines a single test case within a test suite.
	
	@param name The name of the test case
	@param testFn Function containing test assertions
]=]
function TestFramework.it(name: string, testFn: () -> ())
	if not currentSuite then
		error("it() must be called within a describe() block", 2)
	end

	local result: TestResult = {
		name = name,
		success = false,
		error = nil
	}

	-- Run beforeEach callbacks
	for _, callback in beforeEachCallbacks do
		pcall(callback)
	end

	-- Run the test
	local success, err = pcall(testFn)
	result.success = success
	if not success then
		result.error = tostring(err)
		currentSuite.failed += 1
	else
		currentSuite.passed += 1
	end

	-- Run afterEach callbacks
	for _, callback in afterEachCallbacks do
		pcall(callback)
	end

	table.insert(currentSuite.tests, result)
end

--[=[
	Registers a callback to run before each test in the current suite.
	
	@param callback Function to run before each test
]=]
function TestFramework.beforeEach(callback: () -> ())
	table.insert(beforeEachCallbacks, callback)
end

--[=[
	Registers a callback to run after each test in the current suite.
	
	@param callback Function to run after each test
]=]
function TestFramework.afterEach(callback: () -> ())
	table.insert(afterEachCallbacks, callback)
end

--[=[
	Assertion utilities for testing.
]=]
local Expect = {}

function Expect:toBe(expected: any)
	if self.value ~= expected then
		error(`Expected {tostring(expected)}, but got {tostring(self.value)}`, 2)
	end
end

function Expect:toEqual(expected: any)
	-- Note: This performs shallow equality checking for tables.
	-- For deep equality of nested tables, self.values are compared with ==.
	-- If you need deep structural comparison, consider using custom comparison logic.
	if typeof(self.value) == "table" and typeof(expected) == "table" then
		for k, v in expected do
			if self.value[k] ~= v then
				error(`Expected table key '{k}' to be {tostring(v)}, but got {tostring(self.value[k])}`, 2)
			end
		end
		for k, v in self.value do
			if expected[k] == nil then
				error(`Unexpected table key '{k}' with self.value {tostring(v)}`, 2)
			end
		end
	elseif self.value ~= expected then
		error(`Expected {tostring(expected)}, but got {tostring(self.value)}`, 2)
	end
end

function Expect:toBeNil()
	if self.value ~= nil then
		error(`Expected nil, but got {tostring(self.value)}`, 2)
	end
end

function Expect:toBeType(expectedType: string)
	local actualType = typeof(self.value)
	if actualType ~= expectedType then
		error(`Expected type {expectedType}, but got {actualType}`, 2)
	end
end

function Expect:toBeTruthy()
	if not self.value then
		error(`Expected truthy self.value, but got {tostring(self.value)}`, 2)
	end
end

function Expect:toBeFalsy()
	if self.value then
		error(`Expected falsy self.value, but got {tostring(self.value)}`, 2)
	end
end

function Expect:toThrow(expectedError: string?)
	if typeof(self.value) ~= "function" then
		error("toThrow() can only be used with functions", 2)
	end

	local success, err = pcall(self.value)
	if success then
		error("Expected function to throw an error, but it did not", 2)
	end

	if expectedError and not string.find(tostring(err), expectedError, 1, true) then
		error(`Expected error containing '{expectedError}', but got: {err}`, 2)
	end
end

function Expect:toContain(item: any)
	if typeof(self.value) == "table" then
		for _, v in self.value do
			if v == item then
				return
			end
		end
		error(`Expected table to contain {tostring(item)}`, 2)
	elseif typeof(self.value) == "string" then
		if not string.find(self.value, item, 1, true) then
			error(`Expected string to contain '{item}'`, 2)
		end
	else
		error("toContain() can only be used with tables or strings", 2)
	end
end

function Expect.new(value: any)
	local self = {
		value = value
	}

	return setmetatable(self, {
		__index = Expect
	})
end

TestFramework.expect = Expect.new

--[=[
	Runs all registered test suites and returns results.
	
	@return Array of TestSuite results
]=]
function TestFramework.runTests(): {TestSuite}
	return allSuites
end

--[=[
	Prints test results to the console.
	
	@param suites Array of TestSuite results to print
]=]
function TestFramework.printResults(suites: {TestSuite})
	local totalPassed = 0
	local totalFailed = 0
	local totalSkipped = 0

	print("\n" .. string.rep("=", 60))
	print("TEST RESULTS")
	print(string.rep("=", 60))

	for _, suite in suites do
		print(`\n{suite.name}`)
		print(string.rep("-", 60))

		for _, test in suite.tests do
			if test.success then
				print(`  ✓ {test.name}`)
			else
				print(`  ✗ {test.name}`)
				if test.error then
					print(`    Error: {test.error}`)
				end
			end
		end

		totalPassed += suite.passed
		totalFailed += suite.failed
		totalSkipped += suite.skipped

		print(`  Passed: {suite.passed}, Failed: {suite.failed}, Skipped: {suite.skipped}`)
	end

	print("\n" .. string.rep("=", 60))
	print(`TOTAL: {totalPassed} passed, {totalFailed} failed, {totalSkipped} skipped`)
	print(string.rep("=", 60) .. "\n")

	return totalFailed == 0
end

return TestFramework
