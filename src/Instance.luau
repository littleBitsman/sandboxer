--!nonstrict
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

local othertypeof = require("./typeof")
local InstanceSandboxer = require("./InstanceSandboxer")
local InstanceList = require("./InstanceList")

--[=[
	@class InstanceConstructors

	A replacement for the `Instance` class that allows you to create new `Instance`s
	and wraps the returned values in a proxy that allows them to be safely used in 
	the sandbox.
]=]
local InstanceMod = {} :: typeof(Instance)
--[=[
	@within InstanceConstructors

	Returns a new `Instance` of the given class, wrapping it in a proxy that allows it to be safely used in the sandbox.
]=]
function InstanceMod.new(...: string | Instance): any
	local class, parent = InstanceSandboxer.requireArguments(1, ...)
	InstanceSandboxer.requireType(class, "string", `invalid argument #1 to 'new' (string expected, got {othertypeof(class)}`)
	if table.find(InstanceList.DisallowedClasses, class) then
		return nil
	end
	local p: Instance? = nil
	if parent then
		p = InstanceSandboxer.unwrap(parent) :: Instance
		InstanceSandboxer.requireType(p, "Instance", `invalid argument #2 to 'new' (Instance expected, got {othertypeof(parent)}`)
	end
	
	return InstanceSandboxer.wrapInstance(Instance.new(class, p))
end

--[=[
    @within InstanceConstructors

    Returns an `Instance` which is a copy of an existing `Instance`.
]=]
function InstanceMod.fromExisting(...: Instance)
	local wrappedInstance = InstanceSandboxer.requireArguments(1, ...)	
	local inst = InstanceSandboxer.unwrap(wrappedInstance) :: Instance
	InstanceSandboxer.requireType(inst, "Instance", `invalid argument #1 to 'new' (Instance expected, got {othertypeof(wrappedInstance)}`)
	if table.find(InstanceList.DisallowedClasses, inst.ClassName) then
		return nil
	end
	return InstanceSandboxer.wrapInstance(Instance.fromExisting(inst))
end
return table.freeze(InstanceMod)