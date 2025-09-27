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

-- Before you ask why this script is HORRIBLY unorganized:
-- Blame --!strict mode. (Key 'whateverfunction' not found 
-- in table InstanceSandboxer) is my WORST ENEMY.

--[=[
	@class InstanceSandboxer

	A class for wrapping and unwrapping `Instance`s and `RBXScriptSignal`s.
]=]
local InstanceSandboxer = {}

local TRIM_WHITESPACE_PAT = "^%s*(.-)%s*$"

local InstanceList = require("./InstanceList")
local WRAPPED, UNWRAP = InstanceList.WRAPPED, InstanceList.UNWRAP
local WRAPPED_SIGNAL, UNWRAP_SIGNAL = InstanceList.WRAPPED_SIGNALS, InstanceList.UNWRAP_SIGNALS

-- Thank you Luau, very cool! (WHY DOES TYPE CHECKER MAKE ME DO THIS BROOOOOOOOOOOOO)
InstanceSandboxer.deepUnwrap = nil :: any
InstanceSandboxer.deepWrap = nil :: any
InstanceSandboxer.isWrapped = nil :: any
InstanceSandboxer.isWrappedSignal = nil :: any
InstanceSandboxer.typeof = nil :: any
InstanceSandboxer.reverseWrapFn = nil :: any
InstanceSandboxer.unwrap = nil :: any
InstanceSandboxer.unwrapArgs = nil :: any
InstanceSandboxer.wrapArgs = nil :: any
InstanceSandboxer.wrapEvent = nil :: any
InstanceSandboxer.wrapFn = nil :: any
InstanceSandboxer.wrapInstance = nil :: any

local MATH = {"add", "sub", "mul", "div", "idiv", "mod", "unm", "pow"}
local LOCKED = "The metatable is locked"
local INDEX_FAIL = function(self, k: string): never
	error(`{k} is not a valid member of {InstanceSandboxer.typeof(self)}`, 3)
end

--[=[
	@within InstanceSandboxer
	@type AnyFn (...any) -> ...any

	Function type that all functions can be reduced to.
]=]
export type AnyFn = (...any) -> ...any
local METHOD_CACHE: { [AnyFn]: AnyFn } = setmetatable({}, { __mode = "k" }) :: any

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
	elseif typeof(v) == "function" then
		return InstanceSandboxer.reverseWrapFn(v)
	else
		return v
	end
end

InstanceSandboxer.isWrapped = InstanceList.isWrapped
InstanceSandboxer.isWrappedSignal = InstanceList.isWrappedSignal
InstanceSandboxer.unwrap = InstanceList.unwrap
--[=[
	@within InstanceSandboxer

	Deeply unwraps all arguments passed to the function (usually
	from inside the sandbox), making them ready to be used in a
	method call on an `Instance`.
]=]
function InstanceSandboxer.unwrapArgs(...: any): ...any
	local args = {...}
	local n = select("#", ...)
	if #args ~= n then
		args[n + 1] = 0 -- little trick to include nils that were passed
	end
	local visited = {}
	for i = 1, #args do
		args[i] = InstanceSandboxer.deepUnwrap(args[i], visited)
	end
	return unpack(args, 1, n)
end

--[=[
	@within InstanceSandboxer

	Deeply wraps all arguments passed to the function, making
	them ready to be returned to the sandboxed environment.
]=]
function InstanceSandboxer.wrapArgs(...: any): ...any
	local args = {...}
	local n = select("#", ...)
	if #args ~= n then
		args[n + 1] = 0 -- little trick to include nils that were passed
	end
	local visited = {}
	for i = 1, #args do
		args[i] = InstanceSandboxer.deepWrap(args[i], nil, nil, visited)
	end
	return unpack(args, 1, n)
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

	local function wrapped(...)
		return InstanceSandboxer.wrapArgs(fn(InstanceSandboxer.unwrapArgs(...)))
	end
	METHOD_CACHE[fn] = wrapped

	return METHOD_CACHE[fn]
end
InstanceSandboxer.typeof = InstanceSandboxer.wrapFn(typeof)

--[=[
	@within InstanceSandboxer

	Wraps a function in a proxy that allows it to be safely used outside the sandbox.
	This is mainly used for callbacks being added to stuff like BindableFunctions.

	@param fn AnyFn -- The function to wrap.
	@return AnyFn -- The wrapped function.
]=]
function InstanceSandboxer.reverseWrapFn(fn: AnyFn): AnyFn
	local function wrapped(...)
		return InstanceSandboxer.unwrapArgs(fn(InstanceSandboxer.wrapArgs(...)))
	end
	return wrapped
end

local HOOK_CACHE: { [Instance]: { [string]: AnyFn } } = setmetatable({}, { 
	__index = function(self, k)
		self[k] = {}
		return self[k] -- will not stack overflow since __index is only called when the key does not exist
	end,
	__mode = "k" 
}) :: any
local DEFAULT_METATABLE: { [string]: any } = {} do
	local function check(a: any): Instance
		if rawequal(WRAPPED[UNWRAP[a]], a) then
			return UNWRAP[a]
		else
			error("unreachable", 3)
		end
	end
	DEFAULT_METATABLE.__index = function(self: any, key: any): any
		local inst = check(self)
		key = InstanceSandboxer.deepUnwrap(key)
		local success, value = pcall(function()
			return (inst :: any)[key]
		end)

		if not success then
			error(`{key} is not a valid member of {inst.ClassName} "{inst.Name}"`, 2)
		end
		if typeof(value) == "function" then
			local hooked = HOOK_CACHE[inst][key]
			if hooked then 
				return hooked
			end
		end

		return InstanceSandboxer.deepWrap(value, inst, key)
	end
	DEFAULT_METATABLE.__newindex = function(self: any, key: any, value: any)
		local inst = check(self)
		key = InstanceSandboxer.deepUnwrap(key)
		value = InstanceSandboxer.deepUnwrap(value)
		local success, rawerr: string? = pcall(function()
			(inst :: any)[key] = value
		end)
		if not success then
			local err = rawerr or "" 
			if err:find("not a valid member") then
				error(`{key} is not a valid member of {inst.ClassName} "{inst.Name}"`, 2)
			elseif err:find("Unable to assign property") then
				error(err, 2) -- lazy lol
			else -- No other errors while setting properties can occur
				error("unreachable", 2) 
			end
		end
	end

	DEFAULT_METATABLE.__tostring = function(self: any)
		return tostring(check(self))
	end
	DEFAULT_METATABLE.__eq = function(self: any, rhs: any)
		return check(self) == InstanceSandboxer.unwrap(rhs) and rawequal(self, rhs)
	end
	DEFAULT_METATABLE.__call = function(self, ...)
		error(`attempt to call a {InstanceSandboxer.typeof(check(self))} value`, 2)
	end
	DEFAULT_METATABLE.__concat = function(self, v)
		error(`attempt to concatenate {InstanceSandboxer.typeof(check(self))} with {InstanceSandboxer.typeof(v)}`, 2)
	end

	for _, math in MATH do
		DEFAULT_METATABLE[`__{math}`] = function(self, rhs)
			error(`attempt to perform arithmetic ({math}) on {InstanceSandboxer.typeof(check(self))}` 
				.. (InstanceSandboxer.typeof(rhs) ~= "Instance" and ` and {InstanceSandboxer.typeof(rhs)}` or ""), 
				2
			)
		end
	end

	DEFAULT_METATABLE.__lt = function(lhs, rhs)
		local lhsTy = InstanceSandboxer.typeof(check(lhs))
		local rhsTy = InstanceSandboxer.typeof(rhs) -- We cannot check rhs, it might not be wrapped
		error(`attempt to compare {lhsTy} < {rhsTy}`, 2)
	end
	DEFAULT_METATABLE.__le = function(lhs, rhs)
		local lhsTy = InstanceSandboxer.typeof(check(lhs))
		local rhsTy = InstanceSandboxer.typeof(rhs)
		error(`attempt to compare {lhsTy} <= {rhsTy}`, 2)
	end
	DEFAULT_METATABLE.__len = function(self)
		error(`attempt to get length of a {InstanceSandboxer.typeof(check(self))} value`, 2)
	end
	DEFAULT_METATABLE.__iter = function(self)
		error(`attempt to iterate over a {InstanceSandboxer.typeof(check(self))} value`, 2)
	end

	DEFAULT_METATABLE.__metatable = LOCKED
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
-- Support legacy names
SIGNAL_WRAPPER.connect, SIGNAL_WRAPPER.once, SIGNAL_WRAPPER.wait, SIGNAL_WRAPPER.connectParallel = 
	SIGNAL_WRAPPER.Connect, SIGNAL_WRAPPER.Once, SIGNAL_WRAPPER.Wait, SIGNAL_WRAPPER.ConnectParallel
local SIGNAL_INDEX_METAMETHOD = function(self: any, k: any)
	local fn = SIGNAL_WRAPPER[k]
	if fn then
		return fn
	else
		return INDEX_FAIL(self, k)
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

	-- Borrow the same metatable, but we're going to overwrite 
	-- __index, __newindex, and __tostring
	for k, v in DEFAULT_METATABLE do
		metatable[k] = v
	end

	metatable.__index = SIGNAL_INDEX_METAMETHOD
	metatable.__newindex = INDEX_FAIL

	local STRING = string.match(`Signal {name}`, TRIM_WHITESPACE_PAT)
	metatable.__tostring = function()
		return STRING
	end

	WRAPPED_SIGNAL[signal] = proxy
	UNWRAP_SIGNAL[proxy] = signal

	return proxy
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

	-- sets all metamethods to *the same function* that unwraps 
	-- self (proxy) to handle themselves correctly
	for k, v in DEFAULT_METATABLE do
		mt[k] = v
	end

	WRAPPED[instance] = proxy
	UNWRAP[proxy] = instance

	return proxy
end

function InstanceSandboxer.requireArguments(count: number, fn: string, types: {string}, ...): ...any
	local n = select("#", ...)
	if n < count then
		error(`missing argument #{n + 1}` 
			.. ((types and types[n + 1]) and ` to '{fn}' ({types[n + 1]} expected)` or ""), 
			3
		)
	end
	return ...
end

function InstanceSandboxer.requireType(item: any, ty: string, err: string?)
	if typeof(item) ~= ty then
		error(err or `Expected {ty}, got {InstanceSandboxer.typeof(item)}`, 3)
	end
end

-- This is a neat little trick to have the wrapFn function
-- just return these instead of manually wrapping them, and
-- having wrapFn wrap them in a closure again.
-- Also Instance.new & Instance.fromExisting will never 
-- be GC'd since they're C functions, so this is safe.
METHOD_CACHE[Instance.new] = function(...: string | Instance): any
	local class, parent = InstanceSandboxer.requireArguments(1, "new", {"string"}, ...)
	InstanceSandboxer.requireType(class, "string", `invalid argument #1 to 'new' (string expected, got {InstanceSandboxer.typeof(class)}`)
	if table.find(InstanceList.DisallowedClasses, class) then
		return nil
	end
	local p: Instance? = nil
	if parent then
		p = InstanceSandboxer.unwrap(parent) :: Instance
		InstanceSandboxer.requireType(p, "Instance", `invalid argument #2 to 'new' (Instance expected, got {InstanceSandboxer.typeof(parent)}`)
	end

	return InstanceSandboxer.wrapInstance(Instance.new(class, p))
end
METHOD_CACHE[Instance.fromExisting] = function(...: Instance)
	local wrappedInstance = InstanceSandboxer.requireArguments(1, "fromExisting", {"Instance"}, ...)	
	local inst = InstanceSandboxer.unwrap(wrappedInstance) :: Instance
	InstanceSandboxer.requireType(inst, "Instance", `invalid argument #1 to 'fromExisting' (Instance expected, got {InstanceSandboxer.typeof(wrappedInstance)}`)
	if table.find(InstanceList.DisallowedClasses, inst.ClassName) then
		return nil
	end
	return InstanceSandboxer.wrapInstance(Instance.fromExisting(inst))
end

METHOD_CACHE[typeof] = InstanceSandboxer.typeof

-- Avoids creating closures
local function get(t: any, k: string)
	return t[k]
end

--[=[
	@within InstanceSandboxer

	Hooks a function on the given instance. 
	The hook will only work within the sandbox.

	**If used incorrectly, this can be unsafe. Read below, and use with caution.**

	# Info
	This API is intended to be called from *outside* the sandbox (trusted code).
	It lets you interpose logic before / after an instance method call that
	originates from sandboxed code.

	The provided `hook` is invoked with the following parameters:
	```lua
	hook(origFn, ...)
	```
	- `origFn` (function): The original unwrapped Roblox function belonging to `inst`.
	  It must be called with the raw instance as its first parameter if you invoke it manually:
	  `origFn(inst, ...)`.
	- `...`: The raw arguments exactly as they were supplied by the sandboxed caller *after* Luau's
	  implicit `:` desugaring (i.e. the first vararg is the wrapped proxy for `inst`). *Remember that
	  sandboxed code can still do something like `Instance1.Destroy(Instance2)`.*

	Important: The hook receives the *wrapped* proxy as its first variadic argument, not the raw `Instance`.
	Because `origFn` expects the actual `Instance` as the first parameter, do **not** forward the wrapped
	proxy directly. Instead, use the captured `inst` you supplied to `hookFunction`:
	```lua
	InstanceSandboxer.hookFunction(part, "Destroy", function(orig, selfProxy)
		print("Intercepted Destroy for", part:GetFullName())
		-- custom logic
		orig(part) -- call underlying method safely
	end)
	```

	# Return Values
	Whatever the hook returns is forwarded (after normal sandbox wrapping) to the sandboxed caller.
	If you want to preserve original behavior, return the results of `origFn`:
	```lua
	return origFn(inst, ...)
	```

	# Removing a Hook
	Pass `nil` as the `hook` argument to remove a previously installed hook:
	```lua
	InstanceSandboxer.hookFunction(part, "Destroy", nil)
	```

	# Errors
	If the named member does not exist or is not a function, this call errors.
	Hooks replace one another: only one hook per (`Instance`, `methodName`) pair is stored.

	# Limitations / Security Notes
	- Hooks are not visible to sandboxed code except through changed behavior. However,
	  if sandboxed code checks another Instance of the same class' methods, it may observe
	  that the functions are not equal and thus one has been hooked.
	- Hooks execute with full trust; ensure any values you return are properly wrapped
	  if you manually bypass `origFn`.
	- Because arguments arrive in wrapped form (first arg is a proxy), prefer using
	  the outer `inst` variable when invoking `origFn`.
	- Re-entrant calls to the same method on the proxy from inside a hook will also 
	  trigger the hook. Make sure to use the `origFn` provided.

	@param inst -- The instance to hook the function on.
	@param name -- The name of the function to hook.
	@param hook -- The hook function, or `nil` to remove the previous hook.
]=]
function InstanceSandboxer.hookFunction<A..., R...>(inst: Instance, name: string, hook: ((origFn: (A...) -> (R...), A...) -> R...?)?)
	local isValid, fn = pcall(get, inst, name)
	if isValid and typeof(fn) == "function" then
		if hook then
			HOOK_CACHE[inst][name] = function(...)
				return hook(fn, ...)
			end
		else
			HOOK_CACHE[inst][name] = nil
		end
	else
		error(`cannot hook {name} on {inst:GetFullName()} because it is invalid or is not a function`, 2)
	end
end

return InstanceSandboxer