--!strict
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

local module = {}

-- [Instance]: AllowDescendants (if true, only the specific Instance is blacklisted)
local ExplicitDisallow: { [Instance]: boolean } = {
	[game:GetService("Players")] = true
}
module.ExplicitDisallow = ExplicitDisallow

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
module.Allow = Allow

function module.instanceAllowed(inst: Instance): boolean
	for a, allowDescs in ExplicitDisallow do
		if inst == a then
			return false
		elseif inst:IsDescendantOf(a) then
			return allowDescs
		end
	end
	for a, allowDescs in Allow do
		if inst == a or (allowDescs and inst:IsDescendantOf(a)) then
			return true
		end
	end
	return false
end

local WEAK_METATABLE = { __mode = "kv" }
local WRAPPED: { [Instance]: any } = setmetatable({}, WEAK_METATABLE) :: any
local UNWRAP: { [any]: Instance } = setmetatable({}, WEAK_METATABLE) :: any
module.WRAPPED, module.UNWRAP = WRAPPED, UNWRAP

local WRAPPED_SIGNALS: { [RBXScriptSignal]: any } = setmetatable({}, WEAK_METATABLE) :: any
local UNWRAP_SIGNALS: { [any]: RBXScriptSignal } = setmetatable({}, WEAK_METATABLE) :: any
module.WRAPPED_SIGNALS, module.UNWRAP_SIGNALS = WRAPPED_SIGNALS, UNWRAP_SIGNALS

function module.unwrap(a: any): (Instance | RBXScriptSignal)?
	return UNWRAP[a] or UNWRAP_SIGNALS[a]
end
function module.isWrapped(a: any)
	local unwrapped = module.unwrap(a)
	return typeof(unwrapped) == "Instance" and WRAPPED[unwrapped] == a
end
function module.isWrappedSignal(a: any)
	local unwrapped = module.unwrap(a)
	return typeof(unwrapped) == "RBXScriptSignal" and WRAPPED_SIGNALS[unwrapped] == a
end

return table.freeze(module)