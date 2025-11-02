--!strict
--[[
	ExampleTestUsage.luau
	
	This script demonstrates how to use the test suite in a Roblox environment.
	You can use this as a template for integrating the tests into your project.
]]

-- Example 1: Running all tests
print("=== Example 1: Running All Tests ===")
local RunTests = require(script.Parent.tests.RunTests)
-- The test runner will automatically execute all tests and print results

print("\n")

-- Example 2: Running a specific test file
print("=== Example 2: Running Specific Test File ===")
local TestFramework = require(script.Parent.tests.TestFramework)
local InstanceListTests = require(script.Parent.tests["InstanceList.test"])

local results = TestFramework.runTests()
TestFramework.printResults(results)

print("\n")

-- Example 3: Creating a custom test
print("=== Example 3: Creating Custom Test ===")

local describe = TestFramework.describe
local it = TestFramework.it
local expect = TestFramework.expect

describe("Custom Test Suite", function()
	it("should demonstrate basic assertion", function()
		local value = 42
		expect(value).toBe(42)
	end)
	
	it("should demonstrate type checking", function()
		local str = "hello"
		expect(str).toBeType("string")
	end)
	
	it("should demonstrate error checking", function()
		local errorFn = function()
			error("Expected error")
		end
		
		expect(errorFn).toThrow("Expected error")
	end)
end)

local customResults = TestFramework.runTests()
TestFramework.printResults(customResults)

print("\n")

-- Example 4: Using test lifecycle hooks
print("=== Example 4: Test Lifecycle Hooks ===")

local beforeEach = TestFramework.beforeEach
local afterEach = TestFramework.afterEach

describe("Test with Lifecycle Hooks", function()
	local testPart: Part?
	
	beforeEach(function()
		-- This runs before each test
		testPart = Instance.new("Part")
		testPart.Parent = workspace
		print("  [Setup] Created test part")
	end)
	
	afterEach(function()
		-- This runs after each test
		if testPart and testPart.Parent then
			testPart:Destroy()
			print("  [Cleanup] Destroyed test part")
		end
	end)
	
	it("should have access to testPart from beforeEach", function()
		expect(testPart).toBeTruthy()
		expect(testPart.Parent).toBe(workspace)
	end)
	
	it("should create a new testPart for each test", function()
		expect(testPart).toBeTruthy()
		testPart.Name = "CustomName"
		expect(testPart.Name).toBe("CustomName")
	end)
end)

local lifecycleResults = TestFramework.runTests()
TestFramework.printResults(lifecycleResults)

print("\n")

-- Example 5: Testing your own sandboxed code
print("=== Example 5: Testing Sandboxed Code ===")

local Sandboxer = require(script.Parent.src.Sandboxer)

describe("My Sandboxed Code", function()
	it("should execute safely in sandbox", function()
		local myCode = function()
			-- This code runs in a sandboxed environment
			local part = Instance.new("Part")
			part.Parent = workspace
			part.Name = "SandboxedPart"
			
			return part.Name
		end
		
		Sandboxer:Sandbox(myCode)
		local result = myCode()
		
		expect(result).toBe("SandboxedPart")
		
		-- Clean up
		local part = workspace:FindFirstChild("SandboxedPart")
		if part then
			part:Destroy()
		end
	end)
	
	it("should prevent access to forbidden globals", function()
		local maliciousCode = function()
			-- Attempt to access getfenv (should be nil in sandbox)
			return getfenv == nil
		end
		
		Sandboxer:Sandbox(maliciousCode)
		local getfenvRemoved = maliciousCode()
		
		expect(getfenvRemoved).toBe(true)
	end)
end)

local sandboxResults = TestFramework.runTests()
TestFramework.printResults(sandboxResults)

print("\n=== All Examples Complete ===")
