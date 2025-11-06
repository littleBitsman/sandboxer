--[[
	InstanceSandboxer.test.luau
	Comprehensive tests for the InstanceSandboxer module.
	
	Tests cover:
	- Wrapping and unwrapping instances
	- Wrapping and unwrapping signals
	- Deep wrapping and unwrapping
	- Function wrapping
	- Argument wrapping/unwrapping
	- Function hooking
	- Edge cases and boundary conditions
]]

local TestFramework = require("../TestFramework")
local InstanceSandboxer = require("../../Sandboxer/InstanceSandboxer")
local InstanceList = require("../../Sandboxer/InstanceList")

local describe = TestFramework.describe
local it = TestFramework.it
local expect = TestFramework.expect
local beforeEach = TestFramework.beforeEach
local afterEach = TestFramework.afterEach

describe("InstanceSandboxer - Instance Wrapping", function()
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

	it("should wrap allowed instances", function()
		local wrapped = InstanceSandboxer.wrapInstance(testPart)
		expect(wrapped):toBeTruthy()
		expect(InstanceSandboxer.isWrapped(wrapped)):toBe(true)
	end)

	it("should return nil for disallowed instances", function()
		local disallowedInstance = Instance.new("Folder")
		disallowedInstance.Parent = game:GetService("ServerScriptService")

		local wrapped = InstanceSandboxer.wrapInstance(disallowedInstance)
		expect(wrapped):toBeNil()

		disallowedInstance:Destroy()
	end)

	it("should return same wrapped instance for multiple wraps", function()
		local wrapped1 = InstanceSandboxer.wrapInstance(testPart)
		local wrapped2 = InstanceSandboxer.wrapInstance(testPart)

		expect(wrapped1):toBe(wrapped2)
	end)

	it("should correctly unwrap wrapped instances", function()
		local wrapped = InstanceSandboxer.wrapInstance(testPart)
		local unwrapped = InstanceSandboxer.unwrap(wrapped)

		expect(unwrapped):toBe(testPart)
	end)

	it("should return nil when unwrapping non-wrapped values", function()
		expect(InstanceSandboxer.unwrap(testPart)):toBeNil()
		expect(InstanceSandboxer.unwrap("string")):toBeNil()
		expect(InstanceSandboxer.unwrap(123)):toBeNil()
		expect(InstanceSandboxer.unwrap(nil)):toBeNil()
	end)
end)

describe("InstanceSandboxer - Signal Wrapping", function()
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

	it("should wrap RBXScriptSignals", function()
		local signal = testPart.Changed
		local wrapped = InstanceSandboxer.wrapEvent(signal, "Changed")

		expect(wrapped):toBeTruthy()
		expect(InstanceSandboxer.isWrappedSignal(wrapped)):toBe(true)
	end)

	it("should return same wrapped signal for multiple wraps", function()
		local signal = testPart.Changed
		local wrapped1 = InstanceSandboxer.wrapEvent(signal, "Changed")
		local wrapped2 = InstanceSandboxer.wrapEvent(signal, "Changed")

		expect(wrapped1):toBe(wrapped2)
	end)

	it("should correctly unwrap wrapped signals", function()
		local signal = testPart.Changed
		local wrapped = InstanceSandboxer.wrapEvent(signal, "Changed")
		local unwrapped = InstanceSandboxer.unwrap(wrapped)

		expect(unwrapped):toBe(signal)
	end)
end)

describe("InstanceSandboxer - Deep Wrapping", function()
	it("should deep wrap simple values", function()
		expect(InstanceSandboxer.deepWrap(123)):toBe(123)
		expect(InstanceSandboxer.deepWrap("string")):toBe("string")
		expect(InstanceSandboxer.deepWrap(true)):toBe(true)
		expect(InstanceSandboxer.deepWrap(nil)):toBeNil()
	end)

	it("should deep wrap instances in tables", function()
		local part = Instance.new("Part")
		part.Parent = workspace

		local tbl = {
			part = part,
			name = "test"
		}

		local wrapped = InstanceSandboxer.deepWrap(tbl)

		expect(wrapped.name):toBe("test")
		expect(InstanceSandboxer.isWrapped(wrapped.part)):toBe(true)

		part:Destroy()
	end)

	it("should deep wrap nested tables", function()
		local part = Instance.new("Part")
		part.Parent = workspace

		local tbl = {
			nested = {
				part = part,
				value = 42
			}
		}

		local wrapped = InstanceSandboxer.deepWrap(tbl)

		expect(wrapped.nested.value):toBe(42)
		expect(InstanceSandboxer.isWrapped(wrapped.nested.part)):toBe(true)

		part:Destroy()
	end)

	it("should handle circular references in deep wrap", function()
		local tbl: any = {
			value = 1
		}
		tbl.self = tbl

		local wrapped = InstanceSandboxer.deepWrap(tbl)

		expect(wrapped.value):toBe(1)
		expect(wrapped.self):toBe(wrapped)
	end)

	it("should deep wrap functions", function()
		local fn = function(x: number)
			return x * 2
		end

		local tbl = {
			fn = fn
		}

		local wrapped = InstanceSandboxer.deepWrap(tbl)

		expect(typeof(wrapped.fn)):toBe("function")
	end)
end)

describe("InstanceSandboxer - Deep Unwrapping", function()
	it("should deep unwrap simple values", function()
		expect(InstanceSandboxer.deepUnwrap(123)):toBe(123)
		expect(InstanceSandboxer.deepUnwrap("string")):toBe("string")
		expect(InstanceSandboxer.deepUnwrap(true)):toBe(true)
		expect(InstanceSandboxer.deepUnwrap(nil)):toBeNil()
	end)

	it("should deep unwrap wrapped instances in tables", function()
		local part = Instance.new("Part")
		part.Parent = workspace

		local wrapped = InstanceSandboxer.wrapInstance(part)
		local tbl = {
			part = wrapped,
			name = "test"
		}

		local unwrapped = InstanceSandboxer.deepUnwrap(tbl)

		expect(unwrapped.name):toBe("test")
		expect(unwrapped.part):toBe(part)

		part:Destroy()
	end)

	it("should handle circular references in deep unwrap", function()
		local tbl: any = {
			value = 1
		}
		tbl.self = tbl

		local unwrapped = InstanceSandboxer.deepUnwrap(tbl)

		expect(unwrapped.value):toBe(1)
		expect(unwrapped.self):toBe(unwrapped)
	end)
end)

describe("InstanceSandboxer - Argument Wrapping/Unwrapping", function()
	it("should wrap single argument", function()
		local part = Instance.new("Part")
		part.Parent = workspace

		local wrapped = InstanceSandboxer.wrapArgs(part)
		expect(InstanceSandboxer.isWrapped(wrapped)):toBe(true)

		part:Destroy()
	end)

	it("should wrap multiple arguments", function()
		local part1 = Instance.new("Part")
		part1.Parent = workspace
		local part2 = Instance.new("Part")
		part2.Parent = workspace

		local w1, w2, w3 = InstanceSandboxer.wrapArgs(part1, "test", part2)

		expect(InstanceSandboxer.isWrapped(w1)):toBe(true)
		expect(w2):toBe("test")
		expect(InstanceSandboxer.isWrapped(w3)):toBe(true)

		part1:Destroy()
		part2:Destroy()
	end)

	it("should preserve nil arguments when wrapping", function()
		local w1, w2, w3 = InstanceSandboxer.wrapArgs(1, nil, 3)

		expect(w1):toBe(1)
		expect(w2):toBeNil()
		expect(w3):toBe(3)
	end)

	it("should unwrap single argument", function()
		local part = Instance.new("Part")
		part.Parent = workspace
		local wrapped = InstanceSandboxer.wrapInstance(part)

		local unwrapped = InstanceSandboxer.unwrapArgs(wrapped)
		expect(unwrapped):toBe(part)

		part:Destroy()
	end)

	it("should unwrap multiple arguments", function()
		local part1 = Instance.new("Part")
		part1.Parent = workspace
		local part2 = Instance.new("Part")
		part2.Parent = workspace

		local wrapped1 = InstanceSandboxer.wrapInstance(part1)
		local wrapped2 = InstanceSandboxer.wrapInstance(part2)

		local u1, u2, u3 = InstanceSandboxer.unwrapArgs(wrapped1, "test", wrapped2)

		expect(u1):toBe(part1)
		expect(u2):toBe("test")
		expect(u3):toBe(part2)

		part1:Destroy()
		part2:Destroy()
	end)
end)

describe("InstanceSandboxer - Function Wrapping", function()
	it("should wrap functions", function()
		local originalFn = function(x: number)
			return x * 2
		end

		local wrapped = InstanceSandboxer.wrapFn(originalFn)
		expect(typeof(wrapped)):toBe("function")
	end)

	it("should return same wrapped function for multiple wraps", function()
		local originalFn = function(x: number)
			return x * 2
		end

		local wrapped1 = InstanceSandboxer.wrapFn(originalFn)
		local wrapped2 = InstanceSandboxer.wrapFn(originalFn)

		expect(wrapped1):toBe(wrapped2)
	end)

	it("should wrap function arguments and results", function()
		local part = Instance.new("Part")
		part.Parent = workspace

		local fn = function(p: Part)
			return p
		end

		local wrapped = InstanceSandboxer.wrapFn(fn)
		local wrappedPart = InstanceSandboxer.wrapInstance(part)
		local result = wrapped(wrappedPart)

		expect(InstanceSandboxer.isWrapped(result)):toBe(true)

		part:Destroy()
	end)

	it("should reverse wrap functions correctly", function()
		local fn = function(x: number)
			return x + 1
		end

		local reversed = InstanceSandboxer.reverseWrapFn(fn)
		expect(typeof(reversed)):toBe("function")

		local result = reversed(5)
		expect(result):toBe(6)
	end)
end)

describe("InstanceSandboxer - Function Hooking", function()
	it("should hook instance methods", function()
		local part = Instance.new("Part")
		part.Parent = workspace

		local hookCalled = false
		InstanceSandboxer.hookFunction(part, "GetFullName", function(origFn, ...)
			hookCalled = true
			return origFn(part)
		end)

		local wrapped = InstanceSandboxer.wrapInstance(part)
		if wrapped then
			wrapped.GetFullName(wrapped)
		end

		expect(hookCalled):toBe(true)

		-- Remove hook
		InstanceSandboxer.hookFunction(part, "GetFullName", nil)
		part:Destroy()
	end)

	it("should error when hooking invalid methods", function()
		local part = Instance.new("Part")
		part.Parent = workspace

		expect(function()
			InstanceSandboxer.hookFunction(part, "NonExistentMethod", function() end)
		end):toThrow()

		part:Destroy()
	end)

	it("should remove hooks when passed nil", function()
		local part = Instance.new("Part")
		part.Parent = workspace

		local hookCalled = false
		InstanceSandboxer.hookFunction(part, "GetFullName", function(origFn, ...)
			hookCalled = true
			return origFn(part)
		end)

		-- Remove hook
		InstanceSandboxer.hookFunction(part, "GetFullName", nil)

		local wrapped = InstanceSandboxer.wrapInstance(part)
		if wrapped then
			wrapped.GetFullName(wrapped)
		end

		-- Hook should not be called after removal
		expect(hookCalled):toBe(false)

		part:Destroy()
	end)
end)

describe("InstanceSandboxer - Type Checking", function()
	it("should provide typeof wrapper", function()
		expect(typeof(InstanceSandboxer.typeof)):toBe("function")
	end)

	it("should correctly identify types through typeof wrapper", function()
		local part = Instance.new("Part")
		part.Parent = workspace

		expect(InstanceSandboxer.typeof(part)):toBe("Instance")
		expect(InstanceSandboxer.typeof("string")):toBe("string")
		expect(InstanceSandboxer.typeof(123)):toBe("number")
		expect(InstanceSandboxer.typeof(true)):toBe("boolean")

		part:Destroy()
	end)

	it("should handle requireType correctly", function()
		expect(function()
			InstanceSandboxer.requireType("test", "string")
		end):toBeTruthy()

		expect(function()
			InstanceSandboxer.requireType("test", "number")
		end):toThrow()
	end)

	it("should handle requireArguments correctly", function()
		expect(function()
			InstanceSandboxer.requireArguments(2, "testFn", {"string", "number"}, "hello", 42)
		end):toBeTruthy()

		expect(function()
			InstanceSandboxer.requireArguments(3, "testFn", {"string", "number", "boolean"}, "hello")
		end):toThrow()
	end)
end)

describe("InstanceSandboxer - Edge Cases", function()
	it("should handle wrapping nil", function()
		local wrapped = InstanceSandboxer.wrapInstance(nil)
		expect(wrapped):toBeNil()
	end)

	it("should handle wrapping already wrapped instances", function()
		local part = Instance.new("Part")
		part.Parent = workspace

		local wrapped1 = InstanceSandboxer.wrapInstance(part)
		local wrapped2 = InstanceSandboxer.wrapInstance(part)

		expect(wrapped1):toBe(wrapped2)

		part:Destroy()
	end)

	it("should handle empty tables in deep wrap", function()
		local emptyTable = {}
		local wrapped = InstanceSandboxer.deepWrap(emptyTable)

		expect(typeof(wrapped)):toBe("table")
	end)

	it("should handle empty tables in deep unwrap", function()
		local emptyTable = {}
		local unwrapped = InstanceSandboxer.deepUnwrap(emptyTable)

		expect(typeof(unwrapped)):toBe("table")
	end)

	it("should handle tables with numeric keys", function()
		local part1 = Instance.new("Part")
		part1.Parent = workspace
		local part2 = Instance.new("Part")
		part2.Parent = workspace

		local tbl = {part1, part2, "test"}
		local wrapped = InstanceSandboxer.deepWrap(tbl)

		expect(InstanceSandboxer.isWrapped(wrapped[1])):toBe(true)
		expect(InstanceSandboxer.isWrapped(wrapped[2])):toBe(true)
		expect(wrapped[3]):toBe("test")

		part1:Destroy()
		part2:Destroy()
	end)
end)

describe("InstanceSandboxer - Boundary Conditions", function()
	it("should handle very large tables", function()
		local largeTbl = {}
		for i = 1, 100 do
			largeTbl[i] = i
		end

		local wrapped = InstanceSandboxer.deepWrap(largeTbl)

		expect(typeof(wrapped)):toBe("table")
		expect(wrapped[50]):toBe(50)
		expect(wrapped[100]):toBe(100)
	end)

	it("should handle deeply nested tables", function()
		local tbl: any = {value = 1}
		local current = tbl
		for i = 1, 10 do
			current.nested = {value = i}
			current = current.nested
		end

		local wrapped = InstanceSandboxer.deepWrap(tbl)

		expect(typeof(wrapped)):toBe("table")
		expect(wrapped.value):toBe(1)
	end)

	it("should handle mixed type tables", function()
		local part = Instance.new("Part")
		part.Parent = workspace

		local tbl = {
			number = 42,
			string = "test",
			boolean = true,
			instance = part,
			table = {nested = "value"},
			fn = function() return "result" end
		}

		local wrapped = InstanceSandboxer.deepWrap(tbl)

		expect(wrapped.number):toBe(42)
		expect(wrapped.string):toBe("test")
		expect(wrapped.boolean):toBe(true)
		expect(InstanceSandboxer.isWrapped(wrapped.instance)):toBe(true)
		expect(typeof(wrapped.table)):toBe("table")
		expect(typeof(wrapped.fn)):toBe("function")

		part:Destroy()
	end)
end)

return nil