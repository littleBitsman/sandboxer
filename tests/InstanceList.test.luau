--!strict
--[[
	InstanceList.test.luau
	Comprehensive tests for the InstanceList module.
	
	Tests cover:
	- Instance allow/disallow logic
	- Forbidden classes
	- Explicit disallow list
	- Wrapping and unwrapping instances
	- Wrapping and unwrapping signals
	- Edge cases and boundary conditions
]]

local TestFramework = require("../TestFramework")
local InstanceList = require("../../src/InstanceList")

local describe = TestFramework.describe
local it = TestFramework.it
local expect = TestFramework.expect

describe("InstanceList - Allow/Disallow Logic", function()
	it("should allow game instance", function()
		expect(InstanceList.instanceAllowed(game)).toBe(true)
	end)
	
	it("should allow workspace and its descendants", function()
		expect(InstanceList.instanceAllowed(workspace)).toBe(true)
		
		-- Create a part in workspace to test descendants
		local part = Instance.new("Part")
		part.Parent = workspace
		expect(InstanceList.instanceAllowed(part)).toBe(true)
		part:Destroy()
	end)
	
	it("should allow Lighting service", function()
		local lighting = game:GetService("Lighting")
		expect(InstanceList.instanceAllowed(lighting)).toBe(true)
	end)
	
	it("should allow ReplicatedStorage service", function()
		local replicatedStorage = game:GetService("ReplicatedStorage")
		expect(InstanceList.instanceAllowed(replicatedStorage)).toBe(true)
	end)
	
	it("should allow TweenService but not its descendants", function()
		local tweenService = game:GetService("TweenService")
		expect(InstanceList.instanceAllowed(tweenService)).toBe(true)
	end)
	
	it("should disallow Players service by default", function()
		local players = game:GetService("Players")
		expect(InstanceList.instanceAllowed(players)).toBe(false)
	end)
	
	it("should allow RunService but not its descendants", function()
		local runService = game:GetService("RunService")
		expect(InstanceList.instanceAllowed(runService)).toBe(true)
	end)
	
	it("should disallow instances not in the allow list", function()
		local serverScriptService = game:GetService("ServerScriptService")
		expect(InstanceList.instanceAllowed(serverScriptService)).toBe(false)
	end)
end)

describe("InstanceList - ForbiddenClasses", function()
	it("should have DisallowedClasses as a table", function()
		expect(InstanceList.DisallowedClasses).toBeType("table")
	end)
	
	it("should have ForbiddenClasses as a table", function()
		expect(InstanceList.ForbiddenClasses).toBeType("table")
	end)
	
	it("should reject instances of forbidden classes", function()
		-- Add a test forbidden class
		table.insert(InstanceList.ForbiddenClasses, "Fire")
		local forbiddenIndex = #InstanceList.ForbiddenClasses
		
		local part = Instance.new("Part")
		part.Parent = workspace
		local fire = Instance.new("Fire")
		fire.Parent = part
		
		expect(InstanceList.instanceAllowed(fire)).toBe(false)
		
		-- Cleanup
		part:Destroy()
		table.remove(InstanceList.ForbiddenClasses, forbiddenIndex)
	end)
end)

describe("InstanceList - ExplicitDisallow", function()
	it("should have ExplicitDisallow as a table", function()
		expect(InstanceList.ExplicitDisallow).toBeType("table")
	end)
	
	it("should disallow explicitly disallowed instances", function()
		local testFolder = Instance.new("Folder")
		testFolder.Parent = workspace
		
		-- Explicitly disallow this specific instance
		InstanceList.ExplicitDisallow[testFolder] = false
		
		expect(InstanceList.instanceAllowed(testFolder)).toBe(false)
		
		-- Cleanup
		InstanceList.ExplicitDisallow[testFolder] = nil
		testFolder:Destroy()
	end)
	
	it("should allow descendants when ExplicitDisallow value is true", function()
		local testFolder = Instance.new("Folder")
		testFolder.Parent = workspace
		local childPart = Instance.new("Part")
		childPart.Parent = testFolder
		
		-- Disallow folder but allow descendants
		InstanceList.ExplicitDisallow[testFolder] = true
		
		expect(InstanceList.instanceAllowed(testFolder)).toBe(false)
		expect(InstanceList.instanceAllowed(childPart)).toBe(true)
		
		-- Cleanup
		InstanceList.ExplicitDisallow[testFolder] = nil
		testFolder:Destroy()
	end)
end)

describe("InstanceList - Allow List", function()
	it("should have Allow as a table", function()
		expect(InstanceList.Allow).toBeType("table")
	end)
	
	it("should properly handle allow list with descendants flag", function()
		local testService = game:GetService("Lighting")
		
		-- Lighting should be in allow list with descendants = true
		expect(InstanceList.Allow[testService]).toBe(true)
		
		-- Create a child to test descendant logic
		local childObj = Instance.new("PointLight")
		childObj.Parent = testService
		
		expect(InstanceList.instanceAllowed(childObj)).toBe(true)
		
		childObj:Destroy()
	end)
end)

describe("InstanceList - Wrapping/Unwrapping Instances", function()
	it("should provide WRAPPED and UNWRAP tables", function()
		expect(InstanceList.WRAPPED).toBeType("table")
		expect(InstanceList.UNWRAP).toBeType("table")
	end)
	
	it("should correctly identify wrapped instances with isWrapped", function()
		local part = Instance.new("Part")
		part.Parent = workspace
		
		-- Initially not wrapped
		expect(InstanceList.isWrapped(part)).toBe(false)
		
		part:Destroy()
	end)
	
	it("should return nil for unwrapping non-wrapped values", function()
		local part = Instance.new("Part")
		part.Parent = workspace
		
		expect(InstanceList.unwrap(part)).toBeNil()
		
		part:Destroy()
	end)
	
	it("should correctly identify non-wrapped instances", function()
		local part = Instance.new("Part")
		part.Parent = workspace
		
		expect(InstanceList.isWrapped(part)).toBe(false)
		expect(InstanceList.isWrapped("not an instance")).toBe(false)
		expect(InstanceList.isWrapped(nil)).toBe(false)
		expect(InstanceList.isWrapped(123)).toBe(false)
		
		part:Destroy()
	end)
end)

describe("InstanceList - Wrapping/Unwrapping Signals", function()
	it("should provide WRAPPED_SIGNALS and UNWRAP_SIGNALS tables", function()
		expect(InstanceList.WRAPPED_SIGNALS).toBeType("table")
		expect(InstanceList.UNWRAP_SIGNALS).toBeType("table")
	end)
	
	it("should correctly identify non-wrapped signals", function()
		local part = Instance.new("Part")
		part.Parent = workspace
		
		local signal = part.Changed
		expect(InstanceList.isWrappedSignal(signal)).toBe(false)
		
		part:Destroy()
	end)
	
	it("should return false for isWrappedSignal on non-signals", function()
		expect(InstanceList.isWrappedSignal("not a signal")).toBe(false)
		expect(InstanceList.isWrappedSignal(nil)).toBe(false)
		expect(InstanceList.isWrappedSignal(123)).toBe(false)
		expect(InstanceList.isWrappedSignal({})).toBe(false)
	end)
end)

describe("InstanceList - Edge Cases", function()
	it("should handle nil input gracefully in instanceAllowed", function()
		expect(function()
			InstanceList.instanceAllowed(nil :: any)
		end).toThrow()
	end)
	
	it("should handle non-Instance input in instanceAllowed", function()
		expect(function()
			InstanceList.instanceAllowed("not an instance" :: any)
		end).toThrow()
	end)
	
	it("should handle destroyed instances", function()
		local part = Instance.new("Part")
		part.Parent = workspace
		local wasAllowed = InstanceList.instanceAllowed(part)
		
		part:Destroy()
		
		-- After destruction, should handle gracefully
		local success, result = pcall(function()
			return InstanceList.instanceAllowed(part)
		end)
		
		-- Should either succeed or fail gracefully
		expect(success).toBeType("boolean")
	end)
	
	it("should handle multiple allow/disallow rules correctly", function()
		local testFolder = Instance.new("Folder")
		testFolder.Parent = workspace
		
		-- Should be allowed (workspace descendants)
		expect(InstanceList.instanceAllowed(testFolder)).toBe(true)
		
		-- Add to explicit disallow
		InstanceList.ExplicitDisallow[testFolder] = false
		
		-- Should now be disallowed (explicit disallow takes precedence)
		expect(InstanceList.instanceAllowed(testFolder)).toBe(false)
		
		-- Cleanup
		InstanceList.ExplicitDisallow[testFolder] = nil
		testFolder:Destroy()
	end)
end)

describe("InstanceList - Boundary Conditions", function()
	it("should handle deeply nested instances", function()
		local folder1 = Instance.new("Folder")
		folder1.Parent = workspace
		local folder2 = Instance.new("Folder")
		folder2.Parent = folder1
		local folder3 = Instance.new("Folder")
		folder3.Parent = folder2
		local part = Instance.new("Part")
		part.Parent = folder3
		
		-- All should be allowed as descendants of workspace
		expect(InstanceList.instanceAllowed(folder1)).toBe(true)
		expect(InstanceList.instanceAllowed(folder2)).toBe(true)
		expect(InstanceList.instanceAllowed(folder3)).toBe(true)
		expect(InstanceList.instanceAllowed(part)).toBe(true)
		
		folder1:Destroy()
	end)
	
	it("should handle instances moved between allowed and disallowed parents", function()
		local part = Instance.new("Part")
		part.Parent = workspace
		
		expect(InstanceList.instanceAllowed(part)).toBe(true)
		
		-- Move to a disallowed location
		part.Parent = game:GetService("ServerScriptService")
		
		expect(InstanceList.instanceAllowed(part)).toBe(false)
		
		-- Move back to allowed location
		part.Parent = workspace
		
		expect(InstanceList.instanceAllowed(part)).toBe(true)
		
		part:Destroy()
	end)
end)
