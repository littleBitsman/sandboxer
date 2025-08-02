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

local othertypeof = require("./typeof")
local MATH = {"add", "sub", "mul", "div", "idiv", "mod", "unm", "pow"}

local LOCKED = "The metatable is locked"

local INSTANCE: { [string]: ((...any) -> never) | string } = {} do
	INSTANCE.__call = function(_, ...)
		error("attempt to call a Instance value", 0)
	end
	INSTANCE.__concat = function(_, v)
		error(`attempt to concatenate Instance with {othertypeof(v)}`, 0)
	end

	for _, math in MATH do
		INSTANCE[`__{math}`] = function(_)
			error(`attempt to perform arithmetic ({math}) on Instance`, 0)
		end
	end

	INSTANCE.__le = function(lhs, rhs)
		local lhsTy = othertypeof(lhs)
		local rhsTy = othertypeof(rhs)
		error(`attempt to compare {lhsTy} < {rhsTy}`, 0)
	end
	INSTANCE.__lt = function(lhs, rhs)
		local lhsTy = othertypeof(lhs)
		local rhsTy = othertypeof(rhs)
		error(`attempt to compare {lhsTy} <= {rhsTy}`, 0)
	end
	INSTANCE.__len = function(_)
		error("attempt to get length of a Instance value", 0)
	end
	INSTANCE.__iter = function(_)
		error("attempt to iterate over a Instance value", 0)
	end

	INSTANCE.__metatable = LOCKED
end
local SIGNAL: { [string]: any } = {} do
	SIGNAL.__newindex = function(_: any, k, _: any)
		error(`{k} is not a valid member of RBXScriptSignal`, 0)
	end
	SIGNAL.__call = function(_)
		error("attempt to call a RBXScriptSignal value", 0)
	end
	SIGNAL.__concat = function(_, v)
		error(`attempt to concatenate RBXScriptSignal with {othertypeof(v)}`, 0)
	end

	for _, mathOp in MATH do
		SIGNAL[`__{mathOp}`] = function(_)
			error(`attempt to perform arithmetic ({mathOp}) on RBXScriptSignal`, 0)
		end
	end

	SIGNAL.__le = function(lhs, rhs)
		local lhsTy = othertypeof(lhs)
		local rhsTy = othertypeof(rhs)
		error(`attempt to compare {lhsTy} <= {rhsTy}`, 0)
	end
	SIGNAL.__lt = function(lhs, rhs)
		local lhsTy = othertypeof(lhs)
		local rhsTy = othertypeof(rhs)
		error(`attempt to compare {lhsTy} < {rhsTy}`, 0)
	end
	SIGNAL.__len = function(_)
		error("attempt to get length of a RBXScriptSignal value", 0)
	end
	SIGNAL.__iter = function(_)
		error("attempt to iterate over a RBXScriptSignal value", 0)
	end

	SIGNAL.__metatable = LOCKED
end

return {
	Instance = INSTANCE,
	RBXScriptSignal = SIGNAL
}