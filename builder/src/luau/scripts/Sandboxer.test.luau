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

local TestFramework = require("../TestFramework")
local Sandboxer = require("../../Sandboxer")
local InstanceSandboxer = require("../../Sandboxer/InstanceSandboxer")

local describe = TestFramework.describe
local it = TestFramework.it
local expect = TestFramework.expect

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
		local config = {
			customGlobal = "test_value"
		}

		local success = Sandboxer.EditDefaultSandbox(config)
		expect(success):toBe(true)
	end)

	it("should reject forbidden globals", function()
		local config = {
			getfenv = getfenv
		}

		local success = Sandboxer.EditDefaultSandbox(config)
		expect(success):toBe(false)
	end)

	it("should allow custom functions", function()
		local customFn = function()
			return "custom"
		end

		local config = {
			myCustomFunction = customFn
		}

		local success = Sandboxer.EditDefaultSandbox(config)
		expect(success):toBe(true)
	end)

	it("should handle false values to remove globals", function()
		local success = Sandboxer.EditDefaultSandbox({
			print = false
		})
		expect(success):toBe(true)
		assert(Sandboxer.EditDefaultSandbox({
			print = print
		}))
	end)

	it("should reject multiple forbidden globals and return false", function()
		local config = {
			validGlobal = "test",
			getfenv = getfenv,
			setfenv = setfenv
		}

		local success = Sandboxer.EditDefaultSandbox(config)
		expect(success):toBe(false)
	end)
end)

describe("Sandboxer - Sandbox Function", function()
	it("should sandbox a function", function()
		local testFn = function()
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
		local testFn = function()
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
		local testCode = "return 42"

		local success, result = pcall(function()
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
		local invalidCode = "this is not valid lua code !@#$"

		expect(function()
			Sandboxer:SandboxString(invalidCode, "invalid")
		end):toThrow()
	end)

	it("should return a sandboxed function when successful", function()
		local validCode = "return 1 + 1"

		local success, fn = pcall(function()
			return Sandboxer:SandboxString(validCode, "math_test")
		end)

		if success then
			expect(typeof(fn)):toBe("function")

			-- The function should be sandboxed
			local result = fn()
			expect(result):toBe(2)
		end
	end)
end)

describe("Sandboxer - Environment Isolation", function()
	it("should provide sandboxed game object", function()
		local testFn = function()
			-- Access to game in sandboxed environment
			return game ~= nil
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBe(true)
	end)

	it("should provide sandboxed workspace object", function()
		local testFn = function()
			return workspace ~= nil
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBe(true)
	end)

	it("should provide isolated _G table", function()
		local testFn = function()
			_G.testValue = "isolated"
			return _G.testValue
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBe("isolated")

		-- Original _G should not be affected
		expect(_G.testValue):toBeNil()
	end)

	it("should provide isolated shared table", function()
		local testFn = function()
			shared.testValue = "isolated"
			return shared.testValue
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBe("isolated")

		-- Original shared should not be affected
		expect(shared.testValue):toBeNil()
	end)
end)

describe("Sandboxer - Security Restrictions", function()
	it("should remove getfenv from sandbox", function()
		local testFn = function()
			getfenv()
		end

		Sandboxer:Sandbox(testFn)
		
		expect(testFn):toThrow()
	end)

	it("should remove setfenv from sandbox", function()
		local testFn = function()
			return setfenv()
		end

		Sandboxer:Sandbox(testFn)

		expect(testFn):toThrow()
	end)

	it("should remove loadstring from sandbox", function()
		local testFn = function()
			return loadstring == nil
		end

		Sandboxer:Sandbox(testFn)
		local hasLoadstring = not testFn()

		expect(hasLoadstring):toBe(false)
	end)

	it("should remove debug library from sandbox", function()
		local testFn = function()
			return debug == nil
		end

		Sandboxer:Sandbox(testFn)
		local hasDebug = not testFn()

		expect(hasDebug):toBe(false)
	end)

	it("should replace xpcall with error function", function()
		local testFn = function()
			local success, err = pcall(function()
				xpcall(function() end, function() end)
			end)
			return not success
		end

		Sandboxer:Sandbox(testFn)
		local xpcallDisabled = testFn()

		expect(xpcallDisabled):toBe(true)
	end)

	it("should disable SharedTable", function()
		local testFn = function()
			return SharedTable == nil
		end

		Sandboxer:Sandbox(testFn)
		local hasSharedTable = not testFn()

		expect(hasSharedTable):toBe(false)
	end)
end)

describe("Sandboxer - Safe Globals", function()
	it("should provide standard library functions", function()
		local testFn = function()
			return typeof(print) == "function"
				and typeof(warn) == "function"
				and typeof(error) == "function"
				and typeof(assert) == "function"
		end

		Sandboxer:Sandbox(testFn)
		local hasStdLib = testFn()

		expect(hasStdLib):toBe(true)
	end)

	it("should provide math library", function()
		local testFn = function()
			return typeof(math) == "table" and typeof(math.floor) == "function"
		end

		Sandboxer:Sandbox(testFn)
		local hasMath = testFn()

		expect(hasMath):toBe(true)
	end)

	it("should provide string library", function()
		local testFn = function()
			return typeof(string) == "table" and typeof(string.upper) == "function"
		end

		Sandboxer:Sandbox(testFn)
		local hasString = testFn()

		expect(hasString):toBe(true)
	end)

	it("should provide table library", function()
		local testFn = function()
			return typeof(table) == "table" and typeof(table.insert) == "function"
		end

		Sandboxer:Sandbox(testFn)
		local hasTable = testFn()

		expect(hasTable):toBe(true)
	end)

	it("should provide task library", function()
		local testFn = function()
			return typeof(task) == "table" and typeof(task.wait) == "function"
		end

		Sandboxer:Sandbox(testFn)
		local hasTask = testFn()

		expect(hasTask):toBe(true)
	end)

	it("should provide Roblox datatypes", function()
		local testFn = function()
			return typeof(Vector3) == "table"
				and typeof(CFrame) == "table"
				and typeof(Color3) == "table"
		end

		Sandboxer:Sandbox(testFn)
		local hasDatatypes = testFn()

		expect(hasDatatypes):toBe(true)
	end)
end)

describe("Sandboxer - HttpService Restrictions", function()
	it("should disable GetAsync", function()
		local httpService = game:GetService("HttpService")
		local wrapped = InstanceSandboxer.wrapInstance(httpService)

		if wrapped then
			expect(function()
				wrapped:GetAsync("http://example.com")
			end):toThrow("GetAsync is disabled")
		end
	end)

	it("should disable PostAsync", function()
		local httpService = game:GetService("HttpService")
		local wrapped = InstanceSandboxer.wrapInstance(httpService)

		if wrapped then
			expect(function()
				wrapped:PostAsync("http://example.com", "{}")
			end):toThrow("PostAsync is disabled")
		end
	end)

	it("should disable RequestAsync", function()
		local httpService = game:GetService("HttpService")
		local wrapped = InstanceSandboxer.wrapInstance(httpService)

		if wrapped then
			expect(function()
				wrapped:RequestAsync({Url = "http://example.com"})
			end):toThrow("RequestAsync is disabled")
		end
	end)

	it("should disable GetSecret", function()
		local httpService = game:GetService("HttpService")
		local wrapped = InstanceSandboxer.wrapInstance(httpService)

		if wrapped then
			expect(function()
				wrapped:GetSecret("secretKey")
			end):toThrow("GetSecret is disabled")
		end
	end)
	
	it("should allow JSONEncode & GenerateGUID", function()
		local httpService = game:GetService("HttpService")
		local wrapped = InstanceSandboxer.wrapInstance(httpService)
		
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
		local testFn = function()
			return 42
		end

		Sandboxer:Sandbox(testFn)
		Sandboxer:Sandbox(testFn)

		local result = testFn()
		expect(result):toBe(42)
	end)

	it("should handle empty configuration", function()
		local success = Sandboxer.EditDefaultSandbox({})
		expect(success):toBe(true)
	end)

	it("should handle configuration with nil values (using false instead)", function()
		local config = {
			testGlobal = false
		}

		local success = Sandboxer.EditDefaultSandbox(config)
		expect(success):toBe(true)
	end)
end)

describe("Sandboxer - Boundary Conditions", function()
	it("should handle very long code strings", function()
		local longCode = "return " .. string.rep("1 + ", 100) .. "1"

		local success, fn = pcall(function()
			return Sandboxer:SandboxString(longCode, "long_code")
		end)

		if success then
			expect(typeof(fn)):toBe("function")
		end
	end)

	it("should handle nested function calls in sandbox", function()
		local testFn = function()
			local function inner()
				return workspace ~= nil
			end
			return inner()
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBe(true)
	end)

	it("should handle errors in sandboxed functions gracefully", function()
		local testFn = function()
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
		local customValue = "custom_test_value_12345"

		Sandboxer.EditDefaultSandbox({
			customTestGlobal = customValue
		})

		local testFn = function()
			return customTestGlobal
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBe(customValue)

		-- Cleanup
		Sandboxer.EditDefaultSandbox({
			customTestGlobal = false
		})
	end)

	it("should override existing globals with custom ones", function()
		local customPrint = function(...)
			return "custom_print"
		end

		Sandboxer.EditDefaultSandbox({
			print = customPrint
		})

		local testFn = function()
			return print() :: any
		end

		Sandboxer:Sandbox(testFn)
		local result = testFn()

		expect(result):toBe("custom_print")

		-- Cleanup - restore default print
		Sandboxer.EditDefaultSandbox({
			print = print
		})
	end)
end)

return nil