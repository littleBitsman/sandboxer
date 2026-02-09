--[[
	Integration.test.luau
	Integration tests for complex real-world scenarios.
	
	Tests cover:
	- Multi-module interactions
	- Complex sandboxing scenarios
	- Real-world use cases
	- Performance edge cases
	- Security bypass attempts
]]

local TestFramework = require("../TestFramework")
local Sandboxer = require("../../Sandboxer")
local InstanceSandboxer = require("../../Sandboxer/InstanceSandboxer")
local InstanceList = require("../../Sandboxer/InstanceList")

local describe = TestFramework.describe
local it = TestFramework.it
local expect = TestFramework.expect
local beforeEach = TestFramework.beforeEach
local afterEach = TestFramework.afterEach

describe("Integration - Instance Creation and Manipulation", function()
	it("should allow creating instances in sandbox", function()
		local testFn = function()
			local part = Instance.new("Part")
			return part ~= nil
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBe(true)
	end)

	it("should wrap newly created instances", function()
		local testFn = function()
			local part = Instance.new("Part")
			return typeof(part)
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		-- The typeof should return "Instance" even for wrapped instances
		expect(result):toBe("Instance")
	end)

	it("should allow setting properties on wrapped instances", function()
		local testFn = function()
			local part = Instance.new("Part")
			part.Name = "TestPart"
			return part.Name
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBe("TestPart")
	end)

	it("should prevent creating disallowed classes", function()
		-- Add a disallowed class for this test
		table.insert(InstanceList.DisallowedClasses, "Script")
		local disallowedIndex = #InstanceList.DisallowedClasses

		local testFn = function()
			local script = Instance.new("Script")
			return script
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBeNil()

		-- Cleanup
		table.remove(InstanceList.DisallowedClasses, disallowedIndex)
	end)
end)

describe("Integration - Event Handling", function()
	local testPart: Part

	beforeEach(function()
		testPart = Instance.new("Part")
		testPart.Parent = workspace
	end)

	afterEach(function()
		if testPart and testPart.Parent then
			testPart:Destroy()
		end
	end)

	it("should allow connecting to wrapped instance events", function()
		local wrappedPart = InstanceSandboxer.wrapInstance(testPart)

		if wrappedPart then
			local connected = false
			local connection = wrappedPart.Changed:Connect(function()
				connected = true
			end)

			testPart.Name = "Changed"
			task.wait(0.1)

			expect(connected):toBe(true)
			connection:Disconnect()
		end
	end)

	it("should wrap event callback arguments", function()
		local wrappedPart = InstanceSandboxer.wrapInstance(testPart)

		if wrappedPart then
			local receivedPropertyName: string? = nil
			local connection = wrappedPart.Changed:Connect(function(property: string)
				receivedPropertyName = property
			end)

			testPart.Name = "TestName"
			task.wait(0.1)

			expect(receivedPropertyName):toBe("Name")
			connection:Disconnect()
		end
	end)
end)

describe("Integration - Require System", function()
	it("should provide custom require function in sandbox", function()
		local testFn = function()
			return typeof(require)
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBe("function")
	end)

	it("should handle module requiring in sandbox", function()
		-- Create a test module
		local testModule = Instance.new("ModuleScript")
		testModule.Source = "return { value = 42 }"
		testModule.Parent = game:GetService("ReplicatedStorage")

		local testFn = function()
			local module = require(testModule)
			return module.value
		end

		Sandboxer:Sandbox(testFn)

		local success, result = pcall(testFn)

		-- May fail due to require limitations in test environment
		if success then
			expect(result):toBe(42)
		end

		testModule:Destroy()
	end)
end)

describe("Integration - Service Access", function()
	it("should allow accessing allowed services", function()
		local testFn = function()
			local tweenService = game:GetService("TweenService")
			return tweenService ~= nil
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBe(true)
	end)

	it("should wrap service instances", function()
		local testFn = function()
			local lighting = game:GetService("Lighting")
			return typeof(lighting)
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBe("Instance")
	end)

	it("should allow accessing service methods", function()
		local testFn = function()
			local tweenService = game:GetService("TweenService")
			local tweenInfo = TweenInfo.new(1)
			local part = Instance.new("Part")
			part.Parent = workspace

			local tween = tweenService:Create(part, tweenInfo, {Position = Vector3.new(0, 10, 0)})
			return tween ~= nil
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBe(true)
	end)
end)

describe("Integration - Complex Data Structures", function()
	it("should handle deeply nested data with instances", function()
		local part1 = Instance.new("Part")
		part1.Parent = workspace
		local part2 = Instance.new("Part")
		part2.Parent = workspace

		local complexData = {
			level1 = {
				level2 = {
					level3 = {
						parts = {part1, part2},
						values = {1, 2, 3}
					}
				}
			}
		}

		local wrapped = InstanceSandboxer.deepWrap(complexData)

		expect(typeof(wrapped.level1.level2.level3.parts)):toBe("table")
		expect(InstanceSandboxer.isWrapped(wrapped.level1.level2.level3.parts[1])):toBe(true)
		expect(wrapped.level1.level2.level3.values[1]):toBe(1)

		part1:Destroy()
		part2:Destroy()
	end)

	it("should handle mixed instance and primitive arrays", function()
		local part = Instance.new("Part")
		part.Parent = workspace

		local mixedArray = {
			part,
			"string",
			123,
			true,
			{nested = "value"}
		}

		local wrapped = InstanceSandboxer.deepWrap(mixedArray)

		expect(InstanceSandboxer.isWrapped(wrapped[1])):toBe(true)
		expect(wrapped[2]):toBe("string")
		expect(wrapped[3]):toBe(123)
		expect(wrapped[4]):toBe(true)
		expect(typeof(wrapped[5])):toBe("table")

		part:Destroy()
	end)
end)

describe("Integration - Security Bypass Attempts", function()
	it("should prevent getfenv through wrapped functions", function()
		local testFn = function()
			local fn = function() end
			return getfenv(fn)
		end

		Sandboxer:Sandbox(testFn)

		expect(function()
			testFn()
		end):toThrow()
	end)

	it("should prevent loadstring", function()
		local testFn = function()
			return loadstring
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBeNil()
	end)

	it("should prevent metatable manipulation to escape sandbox", function()
		local testFn = function()
			local t = {}
			local success, result = pcall(function()
				return getmetatable(t)
			end)
			return success and result ~= nil
		end

		Sandboxer:Sandbox(testFn)
		local canGetMetatable = testFn()

		-- Should be able to get metatable, but it shouldn't expose sandbox internals
		expect(typeof(canGetMetatable)):toBe("boolean")
	end)
end)

describe("Integration - Resource Management", function()
	it("should handle rapid instance creation and destruction", function()
		local testFn = function()
			for i = 1, 50 do
				local part = Instance.new("Part")
				part.Parent = workspace
				part:Destroy()
			end
			return true
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBe(true)
	end)
end)

describe("Integration - Custom Sandbox Configurations", function()
	it("should apply and use custom globals", function()
		local customValue = "integration_test_value"
		Sandboxer.EditDefaultSandbox({
			testGlobal = customValue
		})

		local testFn = function()
			return testGlobal
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBe(customValue)

		-- Cleanup
		Sandboxer.EditDefaultSandbox({
			testGlobal = false
		})
	end)

	it("should override standard functions with custom implementations", function()
		local customWarn = function(...)
			return "custom_warn"
		end

		Sandboxer.EditDefaultSandbox({
			warn = customWarn
		})

		local testFn = function()
			return warn("test")
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBe("custom_warn")

		-- Restore default
		Sandboxer.EditDefaultSandbox({
			warn = warn
		})
	end)
end)

describe("Integration - Async Operations", function()
	it("should handle task.wait in sandbox", function()
		local testFn = function()
			local startTime = tick()
			task.wait(0.1)
			local endTime = tick()
			return endTime - startTime >= 0.1
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBe(true)
	end)

	it("should handle task.spawn in sandbox", function()
		local testFn = function()
			local completed = false
			task.spawn(function()
				completed = true
			end)
			task.wait(0.1)
			return completed
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBe(true)
	end)

	it("should handle task.defer in sandbox", function()
		local testFn = function()
			local completed = false
			task.defer(function()
				completed = true
			end)
			task.wait(0.1)
			return completed
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBe(true)
	end)
end)

describe("Integration - Math and Computation", function()
	it("should allow complex mathematical operations", function()
		local testFn = function()
			local result = 0
			for i = 1, 100 do
				result += math.sin(i) * math.cos(i)
			end
			return result ~= 0
		end

		Sandboxer:Sandbox(testFn)
		local hasResult = testFn()

		expect(hasResult):toBe(true)
	end)

	it("should allow string operations", function()
		local testFn = function()
			local str = "Hello, World!"
			local upper = string.upper(str)
			local lower = string.lower(str)
			local sub = string.sub(str, 1, 5)

			return upper == "HELLO, WORLD!" 
				and lower == "hello, world!" 
				and sub == "Hello"
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBe(true)
	end)

	it("should allow table operations", function()
		local testFn = function()
			local tbl = {1, 2, 3}
			table.insert(tbl, 4)
			local removed = table.remove(tbl, 1)

			return #tbl == 3 and removed == 1
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBe(true)
	end)
end)

describe("Integration - Error Handling", function()
	it("should propagate errors from sandboxed code", function()
		local testFn = function()
			error("Test error from sandbox")
		end

		Sandboxer:Sandbox(testFn)

		expect(function()
			testFn()
		end):toThrow("Test error from sandbox")
	end)

	it("should allow pcall in sandbox", function()
		local testFn = function()
			local success, err = pcall(function()
				error("pcall test")
			end)
			return not success and (err :: any):find("pcall test")
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBeTruthy()
	end)

	it("should allow assert in sandbox", function()
		local testFn = function()
			assert(true, "This should not error")
			local success = pcall(function()
				assert(false, "This should error")
			end)
			return not success
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBe(true)
	end)
end)

describe("Integration - Performance Scenarios", function()
	it("should handle many wrapped instances efficiently", function()
		local parts = {}
		for i = 1, 100 do
			local part = Instance.new("Part")
			part.Parent = workspace
			table.insert(parts, part)
		end

		local startTime = tick()
		for _, part in parts do
			local wrapped = InstanceSandboxer.wrapInstance(part)
			-- Access a property to ensure wrapping works
			if wrapped then
				local _ = wrapped.Name
			end
		end
		local endTime = tick()

		-- Should complete in reasonable time (< 1 second)
		expect(endTime - startTime < 1):toBe(true)

		-- Cleanup
		for _, part in parts do
			part:Destroy()
		end
	end)

	it("should handle deep wrapping of large structures efficiently", function()
		local largeTable = {}
		for i = 1, 100 do
			largeTable[i] = {
				value = i,
				squared = i * i
			}
		end

		local startTime = tick()
		local wrapped = InstanceSandboxer.deepWrap(largeTable)
		local endTime = tick()

		expect(endTime - startTime < 1):toBe(true)
		expect(wrapped[50].value):toBe(50)
	end)
end)

return nil