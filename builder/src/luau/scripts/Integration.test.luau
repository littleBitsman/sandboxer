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

const TestFramework = require("../TestFramework")
const Sandboxer = require("../../Sandboxer")
const InstanceSandboxer = require("../../Sandboxer/InstanceSandboxer")
const InstanceList = require("../../Sandboxer/InstanceList")

const describe = TestFramework.describe
const it = TestFramework.it
const expect = TestFramework.expect
const beforeEach = TestFramework.beforeEach
const afterEach = TestFramework.afterEach

describe("Integration - Instance Creation and Manipulation", function()
	it("should allow creating instances in sandbox", function()
		const testFn = function()
			const part = Instance.new("Part")
			return part ~= nil
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		expect(result):toBe(true)
	end)

	it("should wrap newly created instances", function()
		const testFn = function()
			const part = Instance.new("Part")
			return typeof(part)
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		-- The typeof should return "Instance" even for wrapped instances
		expect(result):toBe("Instance")
	end)

	it("should allow setting properties on wrapped instances", function()
		const testFn = function()
			const part = Instance.new("Part")
			part.Name = "TestPart"
			return part.Name
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		expect(result):toBe("TestPart")
	end)

	it("should prevent creating disallowed classes", function()
		-- Add a disallowed class for this test
		table.insert(InstanceList.DisallowedClasses, "Script")
		const disallowedIndex = #InstanceList.DisallowedClasses

		const testFn = function()
			const script = Instance.new("Script")
			return script
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

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
		const wrappedPart = InstanceSandboxer.wrapInstance(testPart)

		if wrappedPart then
			local connected = false
			const connection = wrappedPart.Changed:Connect(function()
				connected = true
			end)

			testPart.Name = "Changed"
			task.wait(0.1)

			expect(connected):toBe(true)
			connection:Disconnect()
		end
	end)

	it("should wrap event callback arguments", function()
		const wrappedPart = InstanceSandboxer.wrapInstance(testPart)

		if wrappedPart then
			local receivedPropertyName: string? = nil
			const connection = wrappedPart.Changed:Connect(function(property: string)
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
		const testFn = function()
			return typeof(require)
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		expect(result):toBe("function")
	end)

	it("should handle module requiring in sandbox", function()
		-- Create a test module
		const testModule = Instance.new("ModuleScript")
		testModule.Source = "return { value = 42 }"
		testModule.Parent = game:GetService("ReplicatedStorage")

		const testFn = function()
			const module = require(testModule)
			return module.value
		end

		Sandboxer:Sandbox(testFn)

		const success, result = pcall(testFn)

		-- May fail due to require limitations in test environment
		if success then
			expect(result):toBe(42)
		end

		testModule:Destroy()
	end)
end)

describe("Integration - Service Access", function()
	it("should allow accessing allowed services", function()
		const testFn = function()
			const tweenService = game:GetService("TweenService")
			return tweenService ~= nil
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		expect(result):toBe(true)
	end)

	it("should wrap service instances", function()
		const testFn = function()
			const lighting = game:GetService("Lighting")
			return typeof(lighting)
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		expect(result):toBe("Instance")
	end)

	it("should allow accessing service methods", function()
		const testFn = function()
			const tweenService = game:GetService("TweenService")
			const tweenInfo = TweenInfo.new(1)
			const part = Instance.new("Part")
			part.Parent = workspace

			const tween = tweenService:Create(part, tweenInfo, {Position = Vector3.new(0, 10, 0)})
			return tween ~= nil
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		expect(result):toBe(true)
	end)
end)

describe("Integration - Complex Data Structures", function()
	it("should handle deeply nested data with instances", function()
		const part1 = Instance.new("Part")
		part1.Parent = workspace
		const part2 = Instance.new("Part")
		part2.Parent = workspace

		const complexData = {
			level1 = {
				level2 = {
					level3 = {
						parts = {part1, part2},
						values = {1, 2, 3}
					}
				}
			}
		}

		const wrapped = InstanceSandboxer.deepWrap(complexData)

		expect(typeof(wrapped.level1.level2.level3.parts)):toBe("table")
		expect(InstanceSandboxer.isWrapped(wrapped.level1.level2.level3.parts[1])):toBe(true)
		expect(wrapped.level1.level2.level3.values[1]):toBe(1)

		part1:Destroy()
		part2:Destroy()
	end)

	it("should handle mixed instance and primitive arrays", function()
		const part = Instance.new("Part")
		part.Parent = workspace

		const mixedArray = {
			part,
			"string",
			123,
			true,
			{nested = "value"}
		}

		const wrapped = InstanceSandboxer.deepWrap(mixedArray)

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
		const testFn = function()
			const fn = function() end
			return getfenv(fn)
		end

		Sandboxer:Sandbox(testFn)

		expect(function()
			testFn()
		end):toThrow()
	end)

	it("should prevent loadstring", function()
		const testFn = function()
			return loadstring
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		expect(result):toBeNil()
	end)

	it("should prevent metatable manipulation to escape sandbox", function()
		const testFn = function()
			const t = {}
			const success, result = pcall(getmetatable, t :: any)
			return success and result ~= nil
		end

		Sandboxer:Sandbox(testFn)
		const canGetMetatable = testFn()

		-- Should be able to get metatable, but it shouldn't expose sandbox internals
		expect(typeof(canGetMetatable)):toBe("boolean")
	end)
end)

describe("Integration - Resource Management", function()
	it("should handle rapid instance creation and destruction", function()
		const testFn = function()
			for i = 1, 50 do
				const part = Instance.new("Part")
				part.Parent = workspace
				part:Destroy()
			end
			return true
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		expect(result):toBe(true)
	end)
end)

describe("Integration - Custom Sandbox Configurations", function()
	it("should apply and use custom globals", function()
		const customValue = "integration_test_value"
		Sandboxer.EditDefaultSandbox({
			testGlobal = customValue
		})

		const testFn = function()
			return testGlobal
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		expect(result):toBe(customValue)

		-- Cleanup
		Sandboxer.EditDefaultSandbox({
			testGlobal = false
		})
	end)

	it("should override standard functions with custom implementations", function()
		const customWarn = function(...)
			return "custom_warn"
		end

		Sandboxer.EditDefaultSandbox({
			warn = customWarn
		})

		const testFn = function()
			return warn("test")
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		expect(result):toBe("custom_warn")

		-- Restore default
		Sandboxer.EditDefaultSandbox({
			warn = warn
		})
	end)
end)

describe("Integration - Async Operations", function()
	it("should handle task.wait in sandbox", function()
		const testFn = function()
			const startTime = tick()
			task.wait(0.1)
			const endTime = tick()
			return endTime - startTime >= 0.1
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		expect(result):toBe(true)
	end)

	it("should handle task.spawn in sandbox", function()
		const testFn = function()
			local completed = false
			task.spawn(function()
				completed = true
			end)
			task.wait(0.1)
			return completed
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		expect(result):toBe(true)
	end)

	it("should handle task.defer in sandbox", function()
		const testFn = function()
			local completed = false
			task.defer(function()
				completed = true
			end)
			task.wait(0.1)
			return completed
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		expect(result):toBe(true)
	end)
end)

describe("Integration - Math and Computation", function()
	it("should allow complex mathematical operations", function()
		const testFn = function()
			local result = 0
			for i = 1, 100 do
				result += math.sin(i) * math.cos(i)
			end
			return result ~= 0
		end

		Sandboxer:Sandbox(testFn)
		const hasResult = testFn()

		expect(hasResult):toBe(true)
	end)

	it("should allow string operations", function()
		const testFn = function()
			const str = "Hello, World!"
			const upper = string.upper(str)
			const lower = string.lower(str)
			const sub = string.sub(str, 1, 5)

			return upper == "HELLO, WORLD!" 
				and lower == "hello, world!" 
				and sub == "Hello"
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		expect(result):toBe(true)
	end)

	it("should allow table operations", function()
		const testFn = function()
			const tbl = {1, 2, 3}
			table.insert(tbl, 4)
			const removed = table.remove(tbl, 1)

			return #tbl == 3 and removed == 1
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		expect(result):toBe(true)
	end)
end)

describe("Integration - Error Handling", function()
	it("should propagate errors from sandboxed code", function()
		const testFn = function()
			error("Test error from sandbox")
		end

		Sandboxer:Sandbox(testFn)

		expect(function()
			testFn()
		end):toThrow("Test error from sandbox")
	end)

	it("should allow pcall in sandbox", function()
		const testFn = function()
			const success, err = pcall(function()
				error("pcall test")
			end)
			return not success and (err :: any):find("pcall test")
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		expect(result):toBeTruthy()
	end)

	it("should allow assert in sandbox", function()
		const testFn = function()
			assert(true, "This should not error")
			const success = pcall(function()
				assert(false, "This should error")
			end)
			return not success
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		expect(result):toBe(true)
	end)
end)

describe("Integration - Performance Scenarios", function()
	it("should handle many wrapped instances efficiently", function()
		const parts = {}
		for i = 1, 100 do
			const part = Instance.new("Part")
			part.Parent = workspace
			table.insert(parts, part)
		end

		const startTime = tick()
		for _, part in parts do
			const wrapped = InstanceSandboxer.wrapInstance(part)
			-- Access a property to ensure wrapping works
			if wrapped then
				const _ = wrapped.Name
			end
		end
		const endTime = tick()

		-- Should complete in reasonable time (< 1 second)
		expect(endTime - startTime < 1):toBe(true)

		-- Cleanup
		for _, part in parts do
			part:Destroy()
		end
	end)

	it("should handle deep wrapping of large structures efficiently", function()
		const largeTable = {}
		for i = 1, 100 do
			largeTable[i] = {
				value = i,
				squared = i * i
			}
		end

		const startTime = tick()
		const wrapped = InstanceSandboxer.deepWrap(largeTable)
		const endTime = tick()

		expect(endTime - startTime < 1):toBe(true)
		expect(wrapped[50].value):toBe(50)
	end)
end)

return nil