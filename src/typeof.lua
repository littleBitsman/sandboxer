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

local InstanceList = require("./InstanceList")
local isWrapped, isWrappedSignal = InstanceList.isWrapped, InstanceList.isWrappedSignal

--[=[
	@function typeof
	@param a any The Luau type that will have its type checked.
	@return string
	@within Sandboxer
	@private
	
	Returns the type of the object specified, as a string. 
	This function is more accurate than Luau's native type function, 
	as it does not denote Roblox-specific types as `userdata`.

	Specially handles wrapped `Instance`s and `RBXScriptSignal`s.
]=]
return function(a: any): string
	if isWrapped(a) then
		return "Instance"
	elseif isWrappedSignal(a) then
		return "RBXScriptSignal"
	else
		return typeof(a)
	end
end