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

local InstanceList = require("./InstanceList")
local Metatables = require("./Metatables")
local othertypeof = require("./typeof")
local WRAPPED, UNWRAP = InstanceList.WRAPPED, InstanceList.UNWRAP
local WRAPPED_SIGNAL, UNWRAP_SIGNAL = InstanceList.WRAPPED_SIGNALS, InstanceList.UNWRAP_SIGNALS
module.unwrap, module.isWrapped, module.isWrappedSignal = InstanceList.unwrap, InstanceList.isWrapped, InstanceList.isWrappedSignal
module.instanceAllowed = InstanceList.instanceAllowed

type AnyFn = (...any) -> (...any)
local METHOD_CACHE: { [AnyFn]: AnyFn } = {}

function module.deepWrap(v: any, instance: Instance?, key: string?, visited: { [any]: any }?): any
	local visited: { [any]: any } = visited or {}

	if visited[v] ~= nil then
		return visited[v]
	end

	local ty = typeof(v)
	if ty == "Instance" then
		local wrapped = module.wrapInstance(v)
		visited[v] = wrapped
		return wrapped
	elseif ty == "RBXScriptSignal" then
		local wrapped = module.wrapEvent(v, key or "")
		visited[v] = wrapped
		return wrapped
	elseif ty == "table" then
		local new = {}
		visited[v] = new
		for k, val in v do
			local wrappedKey = module.deepWrap(k, nil, k, visited)
			local wrappedVal = module.deepWrap(val, nil, k, visited)
			new[wrappedKey] = wrappedVal
		end
		return new
	elseif ty == "function" then
		local cached = METHOD_CACHE[v]
		if cached then
			return cached
		else
			cached = function(...)
				return module.wrapArgs(v(unpack(module.unwrapArgs(...))))
			end
			METHOD_CACHE[v] = cached
			return cached
		end
	else
		return v
	end
end

function module.deepUnwrap(v: any, visited: { [any]: any }?): any
	local visited: { [any]: any } = visited or {}

	if visited[v] ~= nil then
		return visited[v]
	end

	local raw = module.unwrap(v)
	if raw then
		visited[v] = raw
		return raw
	end

	local ty = typeof(v)
	if ty == "table" then
		local new = {}
		visited[v] = new
		for k, val in v do
			local unwrappedKey = module.deepUnwrap(k, visited)
			local unwrappedVal = module.deepUnwrap(val, visited)
			new[unwrappedKey] = unwrappedVal
		end
		return new
	else
		return v
	end
end

function module.wrapArgs(...: any): { any }
	local args = {...}
	local visited = {}
	for i = 1, #args do
		args[i] = module.deepWrap(args[i], nil, nil, visited)
	end
	return unpack(args)
end

function module.unwrapArgs(...: any): { any }
	local args = {...}
	local visited = {}
	for i = 1, #args do
		args[i] = module.deepUnwrap(args[i], visited)
	end
	return args
end

function requireType(item: any, ty: string, err: string?)
	if typeof(item) ~= ty then
		error(err or `Expected {ty}, got {typeof(item)}`, 0)
	end
end
local SIGNAL_WRAPPER = {
	Connect = function(self: any, cb: (...any) -> ())
		local signal = module.unwrap(self) :: RBXScriptSignal
		requireType(signal, "RBXScriptSignal", `invalid argument #1 to 'Connect' (RBXScriptSignal expected, got {othertypeof(self)}`)
		requireType(cb, "function", "Attempt to connect failed: Passed value is not a function")
		return signal:Connect(function(...)
			cb(module.wrapArgs(...))
		end)
	end,
	Once = function(self: any, cb: (...any) -> ())
		local signal = module.unwrap(self) :: RBXScriptSignal
		requireType(signal, "RBXScriptSignal", `invalid argument #1 to 'Once' (RBXScriptSignal expected, got {othertypeof(self)}`)
		requireType(cb, "function", "Attempt to connect failed: Passed value is not a function")
		return signal:Once(function(...)
			cb(module.wrapArgs(...))
		end)
	end,
	Wait = function(self: any)
		local signal = module.unwrap(self) :: RBXScriptSignal
		requireType(signal, "RBXScriptSignal", `invalid argument #1 to 'Wait' (RBXScriptSignal expected, got {othertypeof(self)}`)
		return module.wrapArgs(signal:Wait())
	end,
	ConnectParallel = function(self: any, cb: (...any) -> ())
		local signal = module.unwrap(self) :: RBXScriptSignal
		requireType(signal, "RBXScriptSignal", `invalid argument #1 to 'ConnectParallel' (RBXScriptSignal expected, got {othertypeof(self)}`)
		requireType(cb, "function", "Attempt to connect failed: Passed value is not a function")
		return signal:ConnectParallel(function(...)
			cb(module.wrapArgs(...))
		end)
	end
}
local SIGNAL_INDEX_METAMETHOD = function(self: any, k: any)
	local fn = SIGNAL_WRAPPER[k]
	if fn then
		return fn
	else
		error(`{k} is not a valid member of RBXScriptSignal`, 0)
	end
end
function module.wrapEvent(signal: RBXScriptSignal, name: string)
	if WRAPPED_SIGNAL[signal] then
		return WRAPPED_SIGNAL[signal]
	end
	local proxy = newproxy(true)
	local metatable = getmetatable(proxy)
	
	metatable.__index = SIGNAL_INDEX_METAMETHOD
	
	local STRING = `Signal {name}`
	metatable.__tostring = function()
		return STRING
	end
	
	for k, v in Metatables.RBXScriptSignal do
		metatable[k] = v
	end
	
	WRAPPED_SIGNAL[signal] = proxy
	UNWRAP_SIGNAL[proxy] = signal
	
	return proxy
end

function module.wrapInstance(instance: Instance): any?
	if not InstanceList.instanceAllowed(instance) then
		return nil
	end

	if WRAPPED[instance] then
		return WRAPPED[instance]
	end

	local proxy = newproxy(true)
	local mt = getmetatable(proxy)

	local function check(a: any)
		if module.unwrap(a) ~= module.unwrap(proxy) or not rawequal(a, proxy) then
			error("unreachable", 0)
		end
	end

	mt.__index = function(self: any, key: any): any
		check(self)
		key = module.deepUnwrap(key)
		local success, value = pcall(function()
			return (instance :: any)[key]
		end)

		if not success then
			error(`{key} is not a valid member of {instance.ClassName} "{instance.Name}"`, 0)
		end

		return module.deepWrap(value, instance, key)
	end

	mt.__newindex = function(self: any, key: any, value: any)
		check(self)
		key = module.deepUnwrap(key)
		value = module.deepUnwrap(value)
		local s = pcall(function()
			(instance :: any)[key] = value
		end)
		if not s then
			error(`{key} is not a valid member of {instance.ClassName} "{instance.Name}"`, 0)
		end
	end

	mt.__tostring = function(self: any)
		check(self)
		return tostring(instance)
	end
	mt.__eq = function(self: any, rhs: any)
		check(self)
		return module.unwrap(self) == module.unwrap(rhs) and rawequal(self, rhs)
	end

	--[[ the error-y ones: 
		- __call 	(object())
		- __concat 	(object .. any)
		- __unm 	(-object)
		- __add 	(object + any)
		- __sub 	(object - any)
		- __mul 	(object * any)
		- __div 	(object / any)
		- __idiv 	(object // any)
		- __mod 	(object % any)
		- __pow 	(object ^ any)
		- __lt		(object < any)
		- __le  	(object <= any)
		- __len 	(#object)
		- __iter 	(for k, v in object)
		
		As well as __metatable
	]]
	for k, v in Metatables.Instance do
		mt[k] = v
	end

	WRAPPED[instance] = proxy
	UNWRAP[proxy] = instance

	return proxy
end

-- Pass in variadic arguments and use local assignment to get their actual values.
-- Example:
-- `local class, parent = module.requireArguments(1, ...)`
function module.requireArguments(count: number, ...): ...any
	local n = select("#", ...)
	if n < count then
		error(`missing argument #{n + 1}`, 0)
	end
	return ...
end

local DISALLOWED_CLASSES = {}
module.Instance = {} -- Instance functions (new, fromExisting)
function module.Instance.new(...)
	local class, parent = module.requireArguments(1, ...)
	requireType(class, "string", `invalid argument #1 to 'new' (string expected, got {othertypeof(class)}`)
	if table.find(DISALLOWED_CLASSES, class) then
		return nil
	end
	local p: Instance? = nil
	if parent then
		p = module.unwrap(parent) :: Instance
		requireType(p, "Instance", `invalid argument #2 to 'new' (Instance expected, got {othertypeof(parent)}`)
	end
	
	return module.wrapInstance(Instance.new(class, p))
end
function module.Instance.fromExisting(...)
	local wrappedInstance = module.requireArguments(1, ...)	
	local inst = module.unwrap(wrappedInstance) :: Instance
	requireType(inst, "Instance", `invalid argument #1 to 'new' (Instance expected, got {othertypeof(wrappedInstance)}`)
	if table.find(DISALLOWED_CLASSES, inst.ClassName) then
		return nil
	end
	return module.wrapInstance(Instance.fromExisting(inst))
end
table.freeze(module.Instance)

return module