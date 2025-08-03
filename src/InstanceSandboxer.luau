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

--[=[
	@class InstanceSandboxer

	A class for wrapping and unwrapping `Instance`s and `RBXScriptSignal`s.
]=]
local InstanceSandboxer = {}

local InstanceList = require("./InstanceList")
local WRAPPED, UNWRAP = InstanceList.WRAPPED, InstanceList.UNWRAP
local WRAPPED_SIGNAL, UNWRAP_SIGNAL = InstanceList.WRAPPED_SIGNALS, InstanceList.UNWRAP_SIGNALS
InstanceSandboxer.unwrap = InstanceList.unwrap
InstanceSandboxer.isWrapped = InstanceList.isWrapped
InstanceSandboxer.isWrappedSignal = InstanceList.isWrappedSignal
InstanceSandboxer.instanceAllowed = InstanceList.instanceAllowed

-- Thank you Luau, very cool!
InstanceSandboxer.wrapArgs = nil :: any
InstanceSandboxer.unwrapArgs = nil :: any

local MATH = {"add", "sub", "mul", "div", "idiv", "mod", "unm", "pow"}
local LOCKED = "The metatable is locked"

--[=[
	@within InstanceSandboxer
	@type AnyFn (...any) -> ...any

	Function type that all functions can be reduced to.
]=]
export type AnyFn = (...any) -> ...any
local METHOD_CACHE: { [AnyFn]: AnyFn } = setmetatable({}, { __mode = "k" }) :: any

--[=[
	@within InstanceSandboxer
	@private

	Requires a specific number of arguments to be passed to the function.
	If not enough arguments are passed, it will throw an error.
	
	@param count number -- The number of arguments required.
	@param ... any
	@return ...any -- The variadic arguments passed to the function.
]=]
function InstanceSandboxer.requireArguments(count: number, fn: string, types: {string}, ...): ...any
	local n = select("#", ...)
	if n < count then
		error(`missing argument #{n + 1}` 
			.. (types and types[n + 1]) and ` to '{fn}' ({types[n + 1]} expected)` or "", 
			0
		)
	end
	return ...
end

--[=[
	@within InstanceSandboxer

	Wraps a function in a proxy that allows it to be safely used in the sandbox.
	The wrapped function will return wrapped arguments when called.

	@param fn AnyFn -- The function to wrap.
	@return AnyFn -- The wrapped function.
]=]
function InstanceSandboxer.wrapFn(fn: AnyFn): AnyFn
	if METHOD_CACHE[fn] then
		return METHOD_CACHE[fn]
	end
	-- Wow guys look its debug.info
	local parameters: number, isVariadic: boolean = debug.info(fn, "a")
	if parameters == 0 and not isVariadic then
		local function wrapped()
			return InstanceSandboxer.wrapArgs(fn())
		end
		METHOD_CACHE[fn] = wrapped
	else
		local function wrapped(...)
			return InstanceSandboxer.wrapArgs(fn(InstanceSandboxer.unwrapArgs(...)))
		end
		METHOD_CACHE[fn] = wrapped
	end

	return METHOD_CACHE[fn]
end
InstanceSandboxer.typeof = InstanceSandboxer.wrapFn(typeof)
local NEWINDEX_FAIL = function(self, k: string, _: any)
	error(`{k} is not a valid member of {InstanceSandboxer.typeof(self)}`)
end

function InstanceSandboxer.requireType(item: any, ty: string, err: string?)
	if typeof(item) ~= ty then
		error(err or `Expected {ty}, got {typeof(item)}`, 0)
	end
end

local DEFAULT_METATABLE: { [string]: any } = {} do
	DEFAULT_METATABLE.__call = function(self, ...)
		error(`attempt to call a {InstanceSandboxer.typeof(self)} value`, 0)
	end
	DEFAULT_METATABLE.__concat = function(self, v)
		error(`attempt to concatenate {InstanceSandboxer.typeof(self)} with {InstanceSandboxer.typeof(v)}`, 0)
	end

	for _, math in MATH do
		DEFAULT_METATABLE[`__{math}`] = function(self)
			error(`attempt to perform arithmetic ({math}) on {InstanceSandboxer.typeof(self)}`, 0)
		end
	end

	DEFAULT_METATABLE.__le = function(lhs, rhs)
		local lhsTy = InstanceSandboxer.typeof(lhs)
		local rhsTy = InstanceSandboxer.typeof(rhs)
		error(`attempt to compare {lhsTy} < {rhsTy}`, 0)
	end
	DEFAULT_METATABLE.__lt = function(lhs, rhs)
		local lhsTy = InstanceSandboxer.typeof(lhs)
		local rhsTy = InstanceSandboxer.typeof(rhs)
		error(`attempt to compare {lhsTy} <= {rhsTy}`, 0)
	end
	DEFAULT_METATABLE.__len = function(self)
		error(`attempt to get length of a {InstanceSandboxer.typeof(self)} value`, 0)
	end
	DEFAULT_METATABLE.__iter = function(self)
		error(`attempt to iterate over a {InstanceSandboxer.typeof(self)} value`, 0)
	end

	DEFAULT_METATABLE.__metatable = LOCKED
end

--[=[
	@within InstanceSandboxer

	Wraps an `Instance` in a proxy that allows it to be safely used in the sandbox.
	The proxy will have the same properties, methods, and events as the `Instance`, 
	but will return wrapped arguments when accessed.

	@param instance Instance -- The `Instance` to wrap.
	@return any -- The wrapped `Instance`.
]=]
function InstanceSandboxer.wrapInstance(instance: Instance): any?
	if not instance or not InstanceList.instanceAllowed(instance) then
		return nil
	end

	if WRAPPED[instance] then
		return WRAPPED[instance]
	end

	local proxy = newproxy(true)
	local mt = getmetatable(proxy)

	local function check(a: any)
		if InstanceSandboxer.unwrap(a) ~= InstanceSandboxer.unwrap(proxy) or not rawequal(a, proxy) then
			error("unreachable", 0)
		end
	end

	mt.__index = function(self: any, key: any): any
		check(self)
		key = InstanceSandboxer.deepUnwrap(key)
		local success, value = pcall(function()
			return (instance :: any)[key]
		end)

		if not success then
			error(`{key} is not a valid member of {instance.ClassName} "{instance.Name}"`, 0)
		end

		return InstanceSandboxer.deepWrap(value, instance, key)
	end

	mt.__newindex = function(self: any, key: any, value: any)
		check(self)
		key = InstanceSandboxer.deepUnwrap(key)
		value = InstanceSandboxer.deepUnwrap(value)
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
		return InstanceSandboxer.unwrap(self) == InstanceSandboxer.unwrap(rhs) and rawequal(self, rhs)
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
	for k, v in DEFAULT_METATABLE do
		mt[k] = v
	end

	WRAPPED[instance] = proxy
	UNWRAP[proxy] = instance

	return proxy
end

--[=[
	@within InstanceSandboxer

	Deeply wraps `v` if it is a table, wrapping `Instance`s and `RBXScriptSignal`s as needed.
	If `v` is an `Instance` or `RBXScriptSignal`, it will be wrapped and returned.

	@param v any -- The value to deeply wrap.
	@param instance Instance? -- The `Instance` if wrapping one of its properties, methods, or events.
	@param key string? -- The key of the property, method, or event being wrapped, if applicable.
]=]
function InstanceSandboxer.deepWrap(v: any, instance: Instance?, key: string?, pvisited: { [any]: any }?): any
	local visited: { [any]: any } = pvisited or {}

	if visited[v] ~= nil then
		return visited[v]
	end

	local ty = typeof(v)
	if ty == "Instance" then
		local wrapped = InstanceSandboxer.wrapInstance(v)
		visited[v] = wrapped
		return wrapped
	elseif ty == "RBXScriptSignal" then
		local wrapped = InstanceSandboxer.wrapEvent(v, key or "")
		visited[v] = wrapped
		return wrapped
	elseif ty == "table" then
		local new = {}
		visited[v] = new
		for k, val in v do
			local wrappedKey = InstanceSandboxer.deepWrap(k, nil, k, visited)
			local wrappedVal = InstanceSandboxer.deepWrap(val, nil, k, visited)
			new[wrappedKey] = wrappedVal
		end
		return new
	elseif ty == "function" then
		local newFn = InstanceSandboxer.wrapFn(v)
		visited[v] = newFn
		return newFn
	else
		return v
	end
end

--[=[
	@within InstanceSandboxer

	Deeply unwraps `v` if it is a table, unwrapping `Instance`s and `RBXScriptSignal`s as needed.
	If `v` is a wrapped `Instance` or `RBXScriptSignal`, it will be unwrapped and returned.

	@param v any -- The value to deeply unwrap.
]=]
function InstanceSandboxer.deepUnwrap(v: any, pvisited: { [any]: any }?): any
	local visited: { [any]: any } = pvisited or {}

	if visited[v] ~= nil then
		return visited[v]
	end

	local raw = InstanceSandboxer.unwrap(v)
	if raw then
		visited[v] = raw
		return raw
	end

	local ty = typeof(v)
	if ty == "table" then
		local new = {}
		visited[v] = new
		for k, val in v do
			local unwrappedKey = InstanceSandboxer.deepUnwrap(k, visited)
			local unwrappedVal = InstanceSandboxer.deepUnwrap(val, visited)
			new[unwrappedKey] = unwrappedVal
		end
		return new
	else
		return v
	end
end

local SIGNAL_WRAPPER = {
	Connect = function(...)
		local self: any, cb: (...any) -> () = InstanceSandboxer.requireArguments(1, "Connect", {"RBXScriptSignal"}, ...)
		local signal = InstanceSandboxer.unwrap(self) :: RBXScriptSignal
		InstanceSandboxer.requireType(signal, "RBXScriptSignal", `invalid argument #1 to 'Connect' (RBXScriptSignal expected, got {InstanceSandboxer.typeof(self)}`)
		InstanceSandboxer.requireType(cb, "function", "Attempt to connect failed: Passed value is not a function")
		return signal:Connect(function(...)
			cb(InstanceSandboxer.wrapArgs(...))
		end)
	end,
	Once = function(...)
		local self: any, cb: (...any) -> () = InstanceSandboxer.requireArguments(1, "Once", {"RBXScriptSignal"}, ...)
		local signal = InstanceSandboxer.unwrap(self) :: RBXScriptSignal
		InstanceSandboxer.requireType(signal, "RBXScriptSignal", `invalid argument #1 to 'Once' (RBXScriptSignal expected, got {InstanceSandboxer.typeof(self)}`)
		InstanceSandboxer.requireType(cb, "function", "Attempt to connect failed: Passed value is not a function")
		return signal:Once(function(...)
			cb(InstanceSandboxer.wrapArgs(...))
		end)
	end,
	Wait = function(...)
		local self: any = InstanceSandboxer.requireArguments(1, "Wait", {"RBXScriptSignal"}, ...)
		local signal = InstanceSandboxer.unwrap(self) :: RBXScriptSignal
		InstanceSandboxer.requireType(signal, "RBXScriptSignal", `invalid argument #1 to 'Wait' (RBXScriptSignal expected, got {InstanceSandboxer.typeof(self)}`)
		return InstanceSandboxer.wrapArgs(signal:Wait())
	end,
	ConnectParallel = function(...)
		local self: any, cb: (...any) -> () = InstanceSandboxer.requireArguments(1, "ConnectParallel", {"RBXScriptSignal"}, ...)
		local signal = InstanceSandboxer.unwrap(self) :: RBXScriptSignal
		InstanceSandboxer.requireType(signal, "RBXScriptSignal", `invalid argument #1 to 'ConnectParallel' (RBXScriptSignal expected, got {InstanceSandboxer.typeof(self)}`)
		InstanceSandboxer.requireType(cb, "function", "Attempt to connect failed: Passed value is not a function")
		return signal:ConnectParallel(function(...)
			cb(InstanceSandboxer.wrapArgs(...))
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
--[=[
	@within InstanceSandboxer

	Wraps an `RBXScriptSignal` in a proxy that allows it to be safely used in 
	the sandbox. The proxy will have the same methods as an `RBXScriptSignal`, 
	but will return wrapped arguments when the signal is fired.

	@param signal RBXScriptSignal -- The `RBXScriptSignal` to wrap.
	@param name string -- The name of the signal, used for debugging purposes and printing out to console.
	@return any -- The wrapped `RBXScriptSignal`.
]=]
function InstanceSandboxer.wrapEvent(signal: RBXScriptSignal, name: string): any
	if WRAPPED_SIGNAL[signal] then
		return WRAPPED_SIGNAL[signal]
	end
	local proxy = newproxy(true)
	local metatable = getmetatable(proxy)

	metatable.__index = SIGNAL_INDEX_METAMETHOD
	metatable.__newindex = NEWINDEX_FAIL

	local STRING = `Signal {name}`
	metatable.__tostring = function()
		return STRING
	end

	for k, v in DEFAULT_METATABLE do
		metatable[k] = v
	end

	WRAPPED_SIGNAL[signal] = proxy
	UNWRAP_SIGNAL[proxy] = signal

	return proxy
end

--[=[
	@within InstanceSandboxer

	Deeply wraps all arguments passed to the function, making
	them ready to be returned to the sandboxed environment.
]=]
function InstanceSandboxer.wrapArgs(...: any): ...any
	local args = {...}
	local visited = {}
	for i = 1, #args do
		args[i] = InstanceSandboxer.deepWrap(args[i], nil, nil, visited)
	end
	return unpack(args)
end

--[=[
	@within InstanceSandboxer

	Deeply unwraps all arguments passed to the function (usually
	from inside the sandbox), making them ready to be used in a
	method call on an `Instance`.
]=]
function InstanceSandboxer.unwrapArgs(...: any): ...any
	if select(1, ...) == nil then
		return nil
	end
	local args = {...}
	local visited = {}
	for i = 1, #args do
		args[i] = InstanceSandboxer.deepUnwrap(args[i], visited)
	end
	return unpack(args)
end

return InstanceSandboxer