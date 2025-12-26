--!strict
--!optimize 2
--[[
Sandboxer - a Roblox script sandboxer.
Copyright (C) 2025 littleBitsman

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

debug.setmemorycategory("Sandboxer")

--[=[
	@class InstanceList
	
	A list of `Instance`s that are allowed or disallowed in the sandbox.
	
	You can use this to check if an `Instance` is allowed or disallowed in the sandbox,
	or if an `Instance` or `RBXScriptSignal` is wrapped or not.
]=]
local InstanceList = {}
local SandboxRoot = script.Parent

local DisallowedClasses: {string} = {}
--[=[
	@within InstanceList
	@prop DisallowedClasses {string}
	@readonly
	
	A list of classes that are not allowed to be created by
	`Instance.new` nor `Instance.fromExisting`.
	
	Items can be added to the list, but it cannot be overwritten.
	
	Changes to this list will be reflected in the sandbox, even if
	they are made after the sandbox has been initialized. However,
	if an `Instance` of a disallowed class is already created,
	it will continue to function as normal.
]=]
InstanceList.DisallowedClasses = DisallowedClasses

local ForbiddenClasses: {string} = {}
--[=[
	@within InstanceList
	@prop ForbiddenClasses {string}
	@readonly
	
	A list of classes that are not allowed to be accessed
	via the sandbox, period. Every time an `Instance` reference
	is accessed, its class will be checked against this list, 
	respecting inheritance by using `IsA`. If it matches any of 
	the classes in this list, `nil` will be returned instead.
	
	Items can be added to the list, but it cannot be overwritten.
	
	Changes to this list will be reflected in the sandbox, even if
	they are made after the sandbox has been initialized. However,
	if an `Instance` of a forbidden class is already referenced in
	a variable it will continue to function as normal.
]=]
InstanceList.ForbiddenClasses = ForbiddenClasses

-- [Instance]: AllowDescendants (if true, only the specific Instance is blacklisted)
local ExplicitDisallow: { [Instance]: boolean } = {
	[game:GetService("Players")] = true
}
--[=[
	@within InstanceList
	@prop ExplicitDisallow { [Instance]: boolean }
	@readonly
	
	A list of `Instance`s that are explicitly disallowed in the sandbox.
	This is a mapping of `Instance`s to boolean values, which indicate whether
	the `Instance`'s descendants are allowed or not.

	Items can be added to the list, but it cannot be overwritten.

	Changes to this list will be reflected in the sandbox, even if
	they are made after the sandbox has been initialized. However,
	if a blocked `Instance` is already wrapped, it will continue to
	function as normal.
]=]
InstanceList.ExplicitDisallow = ExplicitDisallow

-- [Instance]: AllowDescendants (if false, only the specific Instance is whitelisted)
local Allow: { [Instance]: boolean } = {
	[game] = false,
	[workspace] = true,
	[game:GetService("Lighting")] = true,
	[game:GetService("ReplicatedStorage")] = true,
	[game:GetService("TweenService")] = true,
	[game:GetService("RunService")] = false,
	[game:GetService("SoundService")] = true,
	[game:GetService("TextService")] = true,
	[game:GetService("TextChatService")] = true,
	[game:GetService("Debris")] = true,
}
--[=[
	@within InstanceList
	@prop Allow { [Instance]: boolean }
	@readonly
	
	A list of `Instance`s that are allowed in the sandbox.
	This is a mapping of `Instance`s to boolean values, which indicate whether
	the `Instance`'s descendants are allowed or not.

	If any `Instance` is present in this list, but it is disallowed in `ExplicitDisallow`,
	it will be disallowed in the sandbox.

	Items can be added to the list, but it cannot be overwritten.

	Changes to this list will be reflected in the sandbox, even if
	they are made after the sandbox has been initialized. However,
	if a blocked `Instance` is already wrapped, it will continue to
	function as normal.
]=]
InstanceList.Allow = Allow

--[=[
	@within InstanceList
	
	Checks if an `Instance` is allowed in the sandbox based on
	`Allow`, `ExplicitDisallow`, and `ForbiddenClasses`.
	
	@param inst -- The `Instance` to check.
]=]
function InstanceList.instanceAllowed(inst: Instance): boolean
	if inst == SandboxRoot or inst:IsDescendantOf(SandboxRoot) then
		return false
	end

	for _, class in ForbiddenClasses do
		if inst:IsA(class) then
			return false
		end
	end

	for a, allowDescs in ExplicitDisallow do
		if inst == a or (not allowDescs and inst:IsDescendantOf(a)) then
			return false
		end
	end
	
	for a, allowDescs in Allow do
		if inst == a or (allowDescs and inst:IsDescendantOf(a)) then
			return true
		end
	end
	return inst.Parent == nil and inst ~= game
end

local WEAK_KEY_METATABLE = { __mode = "k" }
local WEAK_VAL_METATABLE = { __mode = "v" }
local WRAPPED: { [Instance]: any } = setmetatable({}, WEAK_KEY_METATABLE) :: any
local UNWRAP: { [any]: Instance } = setmetatable({}, WEAK_VAL_METATABLE) :: any
InstanceList.WRAPPED, InstanceList.UNWRAP = WRAPPED, UNWRAP

local WRAPPED_SIGNALS: { [RBXScriptSignal]: any } = setmetatable({}, WEAK_KEY_METATABLE) :: any
local UNWRAP_SIGNALS: { [any]: RBXScriptSignal } = setmetatable({}, WEAK_VAL_METATABLE) :: any
InstanceList.WRAPPED_SIGNALS, InstanceList.UNWRAP_SIGNALS = WRAPPED_SIGNALS, UNWRAP_SIGNALS

--[=[
	@within InstanceSandboxer
	
	Unwraps a wrapped `Instance` or `RBXScriptSignal`.
	If the `Instance` or `RBXScriptSignal` is not wrapped, it will return `nil`.
	
	@param a -- The wrapped `Instance` or `RBXScriptSignal` to unwrap.
]=]
function InstanceList.unwrap(a: any): (Instance | RBXScriptSignal)?
	return UNWRAP[a] or UNWRAP_SIGNALS[a]
end
--[=[
	@within InstanceSandboxer
	
	Checks if `a` is a wrapped `Instance`.
	
	@param a 
]=]
function InstanceList.isWrapped(a: any): boolean
	local unwrapped = InstanceList.unwrap(a)
	return typeof(unwrapped) == "Instance" and WRAPPED[unwrapped] == a
end
--[=[
	@within InstanceSandboxer
	
	Checks if `a` is a wrapped `RBXScriptSignal`.
	
	@param a 
]=]
function InstanceList.isWrappedSignal(a: any): boolean
	local unwrapped = InstanceList.unwrap(a)
	return typeof(unwrapped) == "RBXScriptSignal" and WRAPPED_SIGNALS[unwrapped] == a
end

return table.freeze(InstanceList)