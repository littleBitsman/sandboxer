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

const TestFramework = require("../TestFramework")
const InstanceSandboxer = require("../../Sandboxer/InstanceSandboxer")

const describe = TestFramework.describe
const it = TestFramework.it
const expect = TestFramework.expect
const beforeEach = TestFramework.beforeEach
const afterEach = TestFramework.afterEach

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
		const wrapped = InstanceSandboxer.wrapInstance(testPart)
		expect(wrapped):toBeTruthy()
		expect(InstanceSandboxer.isWrapped(wrapped)):toBe(true)
	end)

	it("should return nil for disallowed instances", function()
		const disallowedInstance = Instance.new("Folder")
		disallowedInstance.Parent = game:GetService("ServerScriptService")

		const wrapped = InstanceSandboxer.wrapInstance(disallowedInstance)
		expect(wrapped):toBeNil()

		disallowedInstance:Destroy()
	end)

	it("should return same wrapped instance for multiple wraps", function()
		const wrapped1 = InstanceSandboxer.wrapInstance(testPart)
		const wrapped2 = InstanceSandboxer.wrapInstance(testPart)

		expect(wrapped1):toBe(wrapped2)
	end)

	it("should correctly unwrap wrapped instances", function()
		const wrapped = InstanceSandboxer.wrapInstance(testPart)
		const unwrapped = InstanceSandboxer.unwrap(wrapped)

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
		const signal = testPart.Changed
		const wrapped = InstanceSandboxer.wrapEvent(signal, "Changed")

		expect(wrapped):toBeTruthy()
		expect(InstanceSandboxer.isWrappedSignal(wrapped)):toBe(true)
	end)

	it("should return same wrapped signal for multiple wraps", function()
		const signal = testPart.Changed
		const wrapped1 = InstanceSandboxer.wrapEvent(signal, "Changed")
		const wrapped2 = InstanceSandboxer.wrapEvent(signal, "Changed")

		expect(wrapped1):toBe(wrapped2)
	end)

	it("should correctly unwrap wrapped signals", function()
		const signal = testPart.Changed
		const wrapped = InstanceSandboxer.wrapEvent(signal, "Changed")
		const unwrapped = InstanceSandboxer.unwrap(wrapped)

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
		const part = Instance.new("Part")
		part.Parent = workspace

		const tbl = {
			part = part,
			name = "test"
		}

		const wrapped = InstanceSandboxer.deepWrap(tbl)

		expect(wrapped.name):toBe("test")
		expect(InstanceSandboxer.isWrapped(wrapped.part)):toBe(true)

		part:Destroy()
	end)

	it("should deep wrap nested tables", function()
		const part = Instance.new("Part")
		part.Parent = workspace

		const tbl = {
			nested = {
				part = part,
				value = 42
			}
		}

		const wrapped = InstanceSandboxer.deepWrap(tbl)

		expect(wrapped.nested.value):toBe(42)
		expect(InstanceSandboxer.isWrapped(wrapped.nested.part)):toBe(true)

		part:Destroy()
	end)

	it("should handle circular references in deep wrap", function()
		const tbl: any = {
			value = 1
		}
		tbl.self = tbl

		const wrapped = InstanceSandboxer.deepWrap(tbl)

		expect(wrapped.value):toBe(1)
		expect(wrapped.self):toBe(wrapped)
	end)

	it("should deep wrap functions", function()
		const fn = function(x: number)
			return x * 2
		end

		const tbl = {
			fn = fn
		}

		const wrapped = InstanceSandboxer.deepWrap(tbl)

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
		const part = Instance.new("Part")
		part.Parent = workspace

		const wrapped = InstanceSandboxer.wrapInstance(part)
		const tbl = {
			part = wrapped,
			name = "test"
		}

		const unwrapped = InstanceSandboxer.deepUnwrap(tbl)

		expect(unwrapped.name):toBe("test")
		expect(unwrapped.part):toBe(part)

		part:Destroy()
	end)

	it("should handle circular references in deep unwrap", function()
		const tbl: any = {
			value = 1
		}
		tbl.self = tbl

		const unwrapped = InstanceSandboxer.deepUnwrap(tbl)

		expect(unwrapped.value):toBe(1)
		expect(unwrapped.self):toBe(unwrapped)
	end)
end)

describe("InstanceSandboxer - Argument Wrapping/Unwrapping", function()
	it("should wrap single argument", function()
		const part = Instance.new("Part")
		part.Parent = workspace

		const wrapped = InstanceSandboxer.wrapArgs(part)
		expect(InstanceSandboxer.isWrapped(wrapped)):toBe(true)

		part:Destroy()
	end)

	it("should wrap multiple arguments", function()
		const part1 = Instance.new("Part")
		part1.Parent = workspace
		const part2 = Instance.new("Part")
		part2.Parent = workspace

		const w1, w2, w3 = InstanceSandboxer.wrapArgs(part1, "test", part2)

		expect(InstanceSandboxer.isWrapped(w1)):toBe(true)
		expect(w2):toBe("test")
		expect(InstanceSandboxer.isWrapped(w3)):toBe(true)

		part1:Destroy()
		part2:Destroy()
	end)

	it("should preserve nil arguments when wrapping", function()
		const w1, w2, w3 = InstanceSandboxer.wrapArgs(1, nil, 3)

		expect(w1):toBe(1)
		expect(w2):toBeNil()
		expect(w3):toBe(3)
	end)

	it("should unwrap single argument", function()
		const part = Instance.new("Part")
		part.Parent = workspace
		const wrapped = InstanceSandboxer.wrapInstance(part)

		const unwrapped = InstanceSandboxer.unwrapArgs(wrapped)
		expect(unwrapped):toBe(part)

		part:Destroy()
	end)

	it("should unwrap multiple arguments", function()
		const part1 = Instance.new("Part")
		part1.Parent = workspace
		const part2 = Instance.new("Part")
		part2.Parent = workspace

		const wrapped1 = InstanceSandboxer.wrapInstance(part1)
		const wrapped2 = InstanceSandboxer.wrapInstance(part2)

		const u1, u2, u3 = InstanceSandboxer.unwrapArgs(wrapped1, "test", wrapped2)

		expect(u1):toBe(part1)
		expect(u2):toBe("test")
		expect(u3):toBe(part2)

		part1:Destroy()
		part2:Destroy()
	end)
end)

describe("InstanceSandboxer - Function Wrapping", function()
	it("should wrap functions", function()
		const originalFn = function(x: number)
			return x * 2
		end

		const wrapped = InstanceSandboxer.wrapFn(originalFn)
		expect(typeof(wrapped)):toBe("function")
	end)

	it("should return same wrapped function for multiple wraps", function()
		const originalFn = function(x: number)
			return x * 2
		end

		const wrapped1 = InstanceSandboxer.wrapFn(originalFn)
		const wrapped2 = InstanceSandboxer.wrapFn(originalFn)

		expect(wrapped1):toBe(wrapped2)
	end)

	it("should wrap function arguments and results", function()
		const part = Instance.new("Part")
		part.Parent = workspace

		const fn = function(p: Part)
			return p
		end

		const wrapped = InstanceSandboxer.wrapFn(fn)
		const wrappedPart = InstanceSandboxer.wrapInstance(part)
		const result = wrapped(wrappedPart)

		expect(InstanceSandboxer.isWrapped(result)):toBe(true)

		part:Destroy()
	end)

	it("should reverse wrap functions correctly", function()
		const fn = function(x: number)
			return x + 1
		end

		const reversed = InstanceSandboxer.reverseWrapFn(fn)
		expect(typeof(reversed)):toBe("function")

		const result = reversed(5)
		expect(result):toBe(6)
	end)
end)

describe("InstanceSandboxer - Metamethod Hooking", function()
	it("should hook Instance metamethods", function()
		const part = Instance.new("Part")
		part.Parent = workspace

		local hookCalled = 0
		InstanceSandboxer.hookMetamethod(part, "__index", function(index, proxy, key)
			hookCalled += 1
			if key == "Name" then
				return "HookedName"
			end
			return index(part, key)
		end)

		const wrapped = InstanceSandboxer.wrapInstance(part)
		if wrapped then
			wrapped.GetFullName(wrapped)
		end

		expect(wrapped.Name):toBe("HookedName")
		expect(hookCalled):toBe(2)

		-- Remove hook
		InstanceSandboxer.hookMetamethod(part, "__index", nil)
		part:Destroy()
	end)

	it("should error with invalid parameters", function()
		expect(function()
			InstanceSandboxer.hookMetamethod("notaninstance" :: any, "__index", function() end)
		end):toThrow()

		const part = Instance.new("Part")
		part.Parent = workspace

		expect(function()
			InstanceSandboxer.hookMetamethod(part, "__thisisnotametamethod" :: any, function() end)
		end):toThrow()
		expect(function()
			InstanceSandboxer.hookMetamethod(part, "__index", "notafunction" :: any)
		end):toThrow()

		part:Destroy()
	end)

	it("should remove hooks when passed nil", function()
		const part = Instance.new("Part")
		part.Parent = workspace

		local hookCalled = 0
		InstanceSandboxer.hookMetamethod(part, "__index", function(index, proxy, key)
			hookCalled += 1
			if key == "Name" then
				return "HookedName"
			end
			return index(part, key)
		end)

		-- Remove hook
		InstanceSandboxer.hookMetamethod(part, "__index", nil)

		const wrapped = InstanceSandboxer.wrapInstance(part)
		if wrapped then
			wrapped.GetFullName(wrapped)
		end

		expect(wrapped.Name):toBe(part.Name)

		-- Hook should not be called after removal
		expect(hookCalled):toBe(0)

		part:Destroy()
	end)
end)

describe("InstanceSandboxer - Type Checking", function()
	it("should provide typeof wrapper", function()
		expect(typeof(InstanceSandboxer.typeof)):toBe("function")
	end)

	it("should correctly identify types through typeof wrapper", function()
		const part = Instance.new("Part")
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
	it("should handle wrapping already wrapped instances", function()
		const part = Instance.new("Part")
		part.Parent = workspace

		const wrapped1 = InstanceSandboxer.wrapInstance(part)
		const wrapped2 = InstanceSandboxer.wrapInstance(part)

		expect(wrapped1):toBe(wrapped2)

		part:Destroy()
	end)

	it("should handle empty tables in deep wrap", function()
		const emptyTable = {}
		const wrapped = InstanceSandboxer.deepWrap(emptyTable)

		expect(typeof(wrapped)):toBe("table")
	end)

	it("should handle empty tables in deep unwrap", function()
		const emptyTable = {}
		const unwrapped = InstanceSandboxer.deepUnwrap(emptyTable)

		expect(typeof(unwrapped)):toBe("table")
	end)

	it("should handle tables with numeric keys", function()
		const part1 = Instance.new("Part")
		part1.Parent = workspace
		const part2 = Instance.new("Part")
		part2.Parent = workspace

		const tbl = {part1, part2, "test"}
		const wrapped = InstanceSandboxer.deepWrap(tbl)

		expect(InstanceSandboxer.isWrapped(wrapped[1])):toBe(true)
		expect(InstanceSandboxer.isWrapped(wrapped[2])):toBe(true)
		expect(wrapped[3]):toBe("test")

		part1:Destroy()
		part2:Destroy()
	end)
end)

describe("InstanceSandboxer - Boundary Conditions", function()
	it("should handle very large tables", function()
		const largeTbl = {}
		for i = 1, 100 do
			largeTbl[i] = i
		end

		const wrapped = InstanceSandboxer.deepWrap(largeTbl)

		expect(typeof(wrapped)):toBe("table")
		expect(wrapped[50]):toBe(50)
		expect(wrapped[100]):toBe(100)
	end)

	it("should handle deeply nested tables", function()
		const tbl: any = {value = 1}
		local current = tbl
		for i = 1, 10 do
			current.nested = {value = i}
			current = current.nested
		end

		const wrapped = InstanceSandboxer.deepWrap(tbl)

		expect(typeof(wrapped)):toBe("table")
		expect(wrapped.value):toBe(1)
	end)

	it("should handle mixed type tables", function()
		const part = Instance.new("Part")
		part.Parent = workspace

		const tbl = {
			number = 42,
			string = "test",
			boolean = true,
			instance = part,
			table = {nested = "value"},
			fn = function() return "result" end
		}

		const wrapped = InstanceSandboxer.deepWrap(tbl)

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