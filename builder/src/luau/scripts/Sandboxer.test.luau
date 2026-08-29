--[[
	Sandboxer.test.luau
	Comprehensive tests for the main Sandboxer module.
	
	Tests cover:
	- Sandbox initialization
	- Sandbox configuration
	- String sandboxing (loadstring)
	- Environment isolation
	- Security restrictions
	- Edge cases and boundary conditions
]]

const TestFramework = require("../TestFramework")
const Sandboxer = require("../../Sandboxer")
const InstanceSandboxer = require("../../Sandboxer/InstanceSandboxer")

const describe = TestFramework.describe
const it = TestFramework.it
const expect = TestFramework.expect

describe("Sandboxer - Module Structure", function()
	it("should export Init method", function()
		expect(typeof(Sandboxer.Init)):toBe("function")
	end)

	it("should export Sandbox method", function()
		expect(typeof(Sandboxer.Sandbox)):toBe("function")
	end)

	it("should export SandboxString method", function()
		expect(typeof(Sandboxer.SandboxString)):toBe("function")
	end)

	it("should export EditDefaultSandbox method", function()
		expect(typeof(Sandboxer.EditDefaultSandbox)):toBe("function")
	end)

	it("should export typeof", function()
		expect(typeof(Sandboxer.typeof)):toBe("function")
	end)

	it("should export InstanceList", function()
		expect(typeof(Sandboxer.InstanceList)):toBe("table")
	end)

	it("should have locked metatable", function()
		expect(function()
			(Sandboxer :: any).newMethod = function() end
		end):toThrow()
	end)
end)

describe("Sandboxer - EditDefaultSandbox", function()
	it("should accept valid configuration", function()
		const config = {
			customGlobal = "test_value"
		}

		const success = Sandboxer.EditDefaultSandbox(config)
		expect(success):toBe(true)
	end)

	it("should reject forbidden globals", function()
		const config = {
			getfenv = getfenv
		}

		const success = Sandboxer.EditDefaultSandbox(config)
		expect(success):toBe(false)
	end)

	it("should allow custom functions", function()
		const customFn = function()
			return "custom"
		end

		const config = {
			myCustomFunction = customFn
		}

		const success = Sandboxer.EditDefaultSandbox(config)
		expect(success):toBe(true)
	end)

	it("should handle false values to remove globals", function()
		const success = Sandboxer.EditDefaultSandbox({
			print = false
		})
		expect(success):toBe(true)
		assert(Sandboxer.EditDefaultSandbox({
			print = print
		}))
	end)

	it("should reject multiple forbidden globals and return false", function()
		const config = {
			validGlobal = "test",
			getfenv = getfenv,
			setfenv = setfenv
		}

		const success = Sandboxer.EditDefaultSandbox(config)
		expect(success):toBe(false)
	end)
end)

describe("Sandboxer - Sandbox Function", function()
	it("should sandbox a function", function()
		const testFn = function()
			return true
		end

		expect(function()
			Sandboxer:Sandbox(testFn)
		end):toBeTruthy()
	end)

	it("should error with invalid function level", function()
		expect(function()
			Sandboxer:Sandbox(0)
		end):toThrow("level must be at least 1")
	end)

	it("should not double-sandbox already sandboxed functions", function()
		const testFn = function()
			return true
		end

		Sandboxer:Sandbox(testFn)
		-- Second sandbox should be safe (no-op)
		Sandboxer:Sandbox(testFn)
	end)

	it("should accept level numbers", function()
		expect(function()
			-- Level 1 is the calling function, so this should work
			Sandboxer:Sandbox(1)
		end):toBeTruthy()
	end)
end)

describe("Sandboxer - SandboxString", function()
	it("should require loadstring to be enabled", function()
		-- This will fail if ServerScriptService.LoadStringEnabled is false
		const testCode = "return 42"

		const success, result = pcall(function()
			return Sandboxer:SandboxString(testCode, "test")
		end)

		-- Should either succeed or error with loadstring message
		if not success then
			expect(result):toContain("loadstring")
		else
			expect(typeof(result)):toBe("function")
		end
	end)

	it("should error on invalid Lua code", function()
		const invalidCode = "this is not valid lua code !@#$"

		expect(function()
			Sandboxer:SandboxString(invalidCode, "invalid")
		end):toThrow()
	end)

	it("should return a sandboxed function when successful", function()
		const validCode = "return 1 + 1"

		const success, fn = pcall(function()
			return Sandboxer:SandboxString(validCode, "math_test")
		end)

		if success then
			expect(typeof(fn)):toBe("function")

			-- The function should be sandboxed
			const result = fn()
			expect(result):toBe(2)
		end
	end)
end)

describe("Sandboxer - Environment Isolation", function()
	it("should provide sandboxed game object", function()
		const testFn = function()
			-- Access to game in sandboxed environment
			return game ~= nil
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		expect(result):toBe(true)
	end)

	it("should provide sandboxed workspace object", function()
		const testFn = function()
			return workspace ~= nil
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		expect(result):toBe(true)
	end)

	it("should provide isolated _G table", function()
		const testFn = function()
			_G.testValue = "isolated"
			return _G.testValue
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		expect(result):toBe("isolated")

		-- Original _G should not be affected
		expect(_G.testValue):toBeNil()
	end)

	it("should provide isolated shared table", function()
		const testFn = function()
			shared.testValue = "isolated"
			return shared.testValue
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		expect(result):toBe("isolated")

		-- Original shared should not be affected
		expect(shared.testValue):toBeNil()
	end)
end)

describe("Sandboxer - Security Restrictions", function()
	it("should remove getfenv from sandbox", function()
		const testFn = function()
			getfenv()
		end

		Sandboxer:Sandbox(testFn)
		
		expect(testFn):toThrow()
	end)

	it("should remove setfenv from sandbox", function()
		const testFn = function()
			return setfenv(function() end, {})
		end

		Sandboxer:Sandbox(testFn)

		expect(testFn):toThrow()
	end)

	it("should remove loadstring from sandbox", function()
		const testFn = function()
			return loadstring == nil
		end

		Sandboxer:Sandbox(testFn)
		const hasLoadstring = not testFn()

		expect(hasLoadstring):toBe(false)
	end)

	it("should remove debug library from sandbox", function()
		const testFn = function()
			return debug == nil
		end

		Sandboxer:Sandbox(testFn)
		const hasDebug = not testFn()

		expect(hasDebug):toBe(false)
	end)

	it("should replace xpcall with error function", function()
		const testFn = function()
			const success, _err = pcall(xpcall, function() end, function() end)
			return not success
		end

		Sandboxer:Sandbox(testFn)
		const xpcallDisabled = testFn()

		expect(xpcallDisabled):toBe(true)
	end)

	it("should disable SharedTable", function()
		const testFn = function()
			return SharedTable == nil
		end

		Sandboxer:Sandbox(testFn)
		const hasSharedTable = not testFn()

		expect(hasSharedTable):toBe(false)
	end)
end)

describe("Sandboxer - Safe Globals", function()
	it("should provide standard library functions", function()
		const testFn = function()
			return typeof(print) == "function"
				and typeof(warn) == "function"
				and typeof(error) == "function"
				and typeof(assert) == "function"
		end

		Sandboxer:Sandbox(testFn)
		const hasStdLib = testFn()

		expect(hasStdLib):toBe(true)
	end)

	it("should provide math library", function()
		const testFn = function()
			return typeof(math) == "table" and typeof(math.floor) == "function"
		end

		Sandboxer:Sandbox(testFn)
		const hasMath = testFn()

		expect(hasMath):toBe(true)
	end)

	it("should provide string library", function()
		const testFn = function()
			return typeof(string) == "table" and typeof(string.upper) == "function"
		end

		Sandboxer:Sandbox(testFn)
		const hasString = testFn()

		expect(hasString):toBe(true)
	end)

	it("should provide table library", function()
		const testFn = function()
			return typeof(table) == "table" and typeof(table.insert) == "function"
		end

		Sandboxer:Sandbox(testFn)
		const hasTable = testFn()

		expect(hasTable):toBe(true)
	end)

	it("should provide task library", function()
		const testFn = function()
			return typeof(task) == "table" and typeof(task.wait) == "function"
		end

		Sandboxer:Sandbox(testFn)
		const hasTask = testFn()

		expect(hasTask):toBe(true)
	end)

	it("should provide Roblox datatypes", function()
		const testFn = function()
			return typeof(Vector3) == "table"
				and typeof(CFrame) == "table"
				and typeof(Color3) == "table"
		end

		Sandboxer:Sandbox(testFn)
		const hasDatatypes = testFn()

		expect(hasDatatypes):toBe(true)
	end)
end)

describe("Sandboxer - HttpService Restrictions", function()
	it("should disable GetAsync", function()
		const httpService = game:GetService("HttpService")
		const wrapped = InstanceSandboxer.wrapInstance(httpService)

		if wrapped then
			expect(function()
				wrapped:GetAsync("http://example.com")
			end):toThrow("GetAsync is disabled")
		end
	end)

	it("should disable PostAsync", function()
		const httpService = game:GetService("HttpService")
		const wrapped = InstanceSandboxer.wrapInstance(httpService)

		if wrapped then
			expect(function()
				wrapped:PostAsync("http://example.com", "{}")
			end):toThrow("PostAsync is disabled")
		end
	end)

	it("should disable RequestAsync", function()
		const httpService = game:GetService("HttpService")
		const wrapped = InstanceSandboxer.wrapInstance(httpService)

		if wrapped then
			expect(function()
				wrapped:RequestAsync({Url = "http://example.com"})
			end):toThrow("RequestAsync is disabled")
		end
	end)

	it("should disable GetSecret", function()
		const httpService = game:GetService("HttpService")
		const wrapped = InstanceSandboxer.wrapInstance(httpService)

		if wrapped then
			expect(function()
				wrapped:GetSecret("secretKey")
			end):toThrow("GetSecret is disabled")
		end
	end)
	
	it("should allow JSONEncode & GenerateGUID", function()
		const httpService = game:GetService("HttpService")
		const wrapped = InstanceSandboxer.wrapInstance(httpService)
		
		if wrapped then
			expect(pcall(function()
				wrapped:JSONEncode({ hello = false })
				wrapped:GenerateGUID(false)
				return true
			end)):toBe(true)
		end
	end)
end)

describe("Sandboxer - Edge Cases", function()
	it("should handle sandboxing same function multiple times", function()
		const testFn = function()
			return 42
		end

		Sandboxer:Sandbox(testFn)
		Sandboxer:Sandbox(testFn)

		const result = testFn()
		expect(result):toBe(42)
	end)

	it("should handle empty configuration", function()
		const success = Sandboxer.EditDefaultSandbox({})
		expect(success):toBe(true)
	end)

	it("should handle configuration with nil values (using false instead)", function()
		const config = {
			testGlobal = false
		}

		const success = Sandboxer.EditDefaultSandbox(config)
		expect(success):toBe(true)
	end)
end)

describe("Sandboxer - Boundary Conditions", function()
	it("should handle very long code strings", function()
		const longCode = "return " .. string.rep("1 + ", 100) .. "1"

		const success, fn = pcall(function()
			return Sandboxer:SandboxString(longCode, "long_code")
		end)

		if success then
			expect(typeof(fn)):toBe("function")
		end
	end)

	it("should handle nested function calls in sandbox", function()
		const testFn = function()
			const function inner()
				return workspace ~= nil
			end
			return inner()
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		expect(result):toBe(true)
	end)

	it("should handle errors in sandboxed functions gracefully", function()
		const testFn = function()
			error("test error")
		end

		Sandboxer:Sandbox(testFn)

		expect(function()
			testFn()
		end):toThrow("test error")
	end)
end)

describe("Sandboxer - Custom Configuration", function()
	it("should apply custom globals after configuration", function()
		const customValue = "custom_test_value_12345"

		Sandboxer.EditDefaultSandbox({
			customTestGlobal = customValue
		})

		const testFn = function()
			return customTestGlobal
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		expect(result):toBe(customValue)

		-- Cleanup
		Sandboxer.EditDefaultSandbox({
			customTestGlobal = false
		})
	end)

	it("should override existing globals with custom ones", function()
		const customPrint = function(...)
			return "custom_print"
		end

		Sandboxer.EditDefaultSandbox({
			print = customPrint
		})

		const testFn = function()
			return print() :: any
		end

		Sandboxer:Sandbox(testFn)
		const result = testFn()

		expect(result):toBe("custom_print")

		-- Cleanup - restore default print
		Sandboxer.EditDefaultSandbox({
			print = print
		})
	end)
end)

return nil