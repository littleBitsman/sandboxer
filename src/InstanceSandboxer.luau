--!strict
--!optimize 2
--[[
Sandboxer - a Roblox script sandboxer.
Copyright (C) 2026 littleBitsman

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

local InstanceList = require("./InstanceList")
local WRAPPED, UNWRAP = InstanceList.WRAPPED, InstanceList.UNWRAP
local WRAPPED_SIGNALS, UNWRAP_SIGNALS = InstanceList.WRAPPED_SIGNALS, InstanceList.UNWRAP_SIGNALS

-- Thank you Luau, very cool! (WHY DOES TYPE CHECKER MAKE ME DO THIS BROOOOOOOOOOOOO)
InstanceSandboxer.deepUnwrap = nil :: any
InstanceSandboxer.deepWrap = nil :: any
InstanceSandboxer.hookMetamethod = nil :: any
InstanceSandboxer.isWrapped = InstanceList.isWrapped
InstanceSandboxer.isWrappedSignal = InstanceList.isWrappedSignal
InstanceSandboxer.typeof = nil :: any
InstanceSandboxer.reverseWrapFn = nil :: any
InstanceSandboxer.unwrap = InstanceList.unwrap
InstanceSandboxer.unwrapArgs = nil :: any
InstanceSandboxer.wrapArgs = nil :: any
InstanceSandboxer.wrapEvent = nil :: any
InstanceSandboxer.wrapFn = nil :: any
InstanceSandboxer.wrapInstance = nil :: any

type Metamethod = ("__index" | "__newindex" | "__tostring" 
| "__eq" | "__call" | "__concat" | "__add" | "__sub" | "__mul" 
| "__div" | "__idiv" | "__mod" | "__unm" | "__pow" | "__lt" 
| "__le" | "__len" | "__iter")
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
function InstanceSandboxer.deepWrap(v: any, instance: Instance?, key: string?, pvisited: { [any]: any }?, freeze: boolean?): any
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
		local nil_ = newproxy()
		for k, val in v do
			local wrappedKey = InstanceSandboxer.deepWrap(k, nil, k, visited)
			local wrappedVal = InstanceSandboxer.deepWrap(val, nil, k, visited)
			new[wrappedKey] = wrappedVal
			if typeof(k) == "number" and wrappedVal == nil then
				new[wrappedKey] = nil_
			end
		end
		
		-- This was unfortunately the best way I could think of doing this :(
		while table.find(new, nil_) do
			table.remove(new, table.find(new, nil_))
		end
		
		if freeze then
			table.freeze(new)
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
	local args = table.pack(...)
	if #args ~= args.n then
		args[args.n + 1] = 0 -- little trick to include nils that were passed
	end
	local visited = {}
	for i = 1, args.n do
		args[i] = InstanceSandboxer.deepUnwrap(args[i], visited)
	end
	return unpack(args, 1, args.n)
end

--[=[
	@within InstanceSandboxer

	Deeply wraps all arguments passed to the function, making
	them ready to be returned to the sandboxed environment.
]=]
function InstanceSandboxer.wrapArgs(...: any): ...any
	local args = table.pack(...)
	if #args ~= args.n then
		args[args.n + 1] = 0 -- little trick to include nils that were passed
	end
	local visited = {}
	for i = 1, args.n do
		args[i] = InstanceSandboxer.deepWrap(args[i], nil, nil, visited)
	end
	return unpack(args, 1, args.n)
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

	METHOD_CACHE[fn] = function(...)
		return InstanceSandboxer.wrapArgs(fn(InstanceSandboxer.unwrapArgs(...)))
	end

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
	return function(...)
		return InstanceSandboxer.unwrapArgs(fn(InstanceSandboxer.wrapArgs(...)))
	end
end

-- Avoids creating closures
local function get(t: any, k: string)
	return t[k]
end
local function set(t: any, k: string, v: any)
	t[k] = v
end

--[=[
	@within InstanceSandboxer
	@type MetamethodHook (inst: any, fn: (Instance, ...any) -> ...any, ...any) -> ...any

	Type for metamethod hook functions.
	First argument is the original metamethod function that can be called. **This function expects an unwrapped `Instance` as its first argument.**
	Second argument is the wrapped `Instance`.
	Remaining arguments are the arguments passed to the metamethod at invocation.
]=]
export type MetamethodHook = (fn: (Instance, ...any) -> ...any, inst: any, ...any) -> ...any
local INST_METAMETHOD_HOOKS: { [Instance]: { [string]: MetamethodHook } } = setmetatable({}, { 
	__index = function(self, k)
		self[k] = {}
		return self[k] -- will not stack overflow since __index is only called when the key does not exist
	end,
	__mode = "k" 
}) :: any
local DEFAULT_METATABLE = {} do
	local function check(a: any, requireInstance: boolean?): any
		if rawequal(WRAPPED[UNWRAP[a]], a) then
			return UNWRAP[a]
		elseif not requireInstance and rawequal(WRAPPED_SIGNALS[UNWRAP_SIGNALS[a]], a) then
			return UNWRAP_SIGNALS[a]
		else
			error("unreachable", 0)
		end
	end

	local function internalIndex(inst: Instance, key: any): any
		key = InstanceSandboxer.deepUnwrap(key)
		local success, value = pcall(get, inst, key)

		if not success then
			-- value contains the error message
			error(tostring(value), 2)
			--error(`{key} is not a valid member of {inst.ClassName} "{inst.Name}"`, 2)
		end
		-- Functionality replaced by metamethod hooks
		--[[
		if typeof(value) == "function" then
			local hooked = HOOK_CACHE[inst][key]
			if hooked then 
				return hooked
			end
		end
		]]

		return InstanceSandboxer.deepWrap(value, inst, key)
	end
	DEFAULT_METATABLE.__index = function(self: any, key: any): any
		local inst: Instance = check(self, true)

		local metamethodHook = INST_METAMETHOD_HOOKS[inst].__index
		if metamethodHook then
			return metamethodHook(internalIndex, self, key)
		end
		return internalIndex(inst, key)
	end

	local function internalNewindex(inst: Instance, key: any, value: any)
		key = InstanceSandboxer.deepUnwrap(key)
		value = InstanceSandboxer.deepUnwrap(value)
		local success, rawerr: string? = pcall(set, inst, key, value)
		if not success then
			local err = tostring(rawerr) or ""
			error(err, 2)
			--[[
			if err:find("not a valid member") then
				error(`{key} is not a valid member of {inst.ClassName} "{inst.Name}"`, 2)
			elseif err:find("Unable to assign property") then
				error(err, 2) -- lazy lol
			else -- No other errors while setting properties can occur
				error("unreachable", 2) 
			end
			]]
		end
	end
	DEFAULT_METATABLE.__newindex = function(self: any, key: any, value: any)
		local inst: Instance = check(self, true)

		local metamethodHook = INST_METAMETHOD_HOOKS[inst].__newindex
		if metamethodHook then
			return metamethodHook(internalNewindex, self, key, value)
		end
		return internalNewindex(inst, key, value)
	end

	DEFAULT_METATABLE.__tostring = function(self: any)
		local internalSelf = check(self)
		if typeof(internalSelf) == "Instance" then
			local metamethodHook = INST_METAMETHOD_HOOKS[internalSelf].__tostring
			if metamethodHook then
				return metamethodHook(tostring, self)
			end
		end
		return tostring(internalSelf)
	end

	local function internalEquals(internalSelf: any, rhs: any): boolean
		local self = WRAPPED[internalSelf] or WRAPPED_SIGNALS[internalSelf]
		return internalSelf == InstanceSandboxer.unwrap(rhs) and rawequal(self, rhs)
	end
	DEFAULT_METATABLE.__eq = function(self: any, rhs: any)
		local internalSelf = check(self)
		if typeof(internalSelf) == "Instance" then
			local metamethodHook = INST_METAMETHOD_HOOKS[internalSelf].__eq
			if metamethodHook then
				return metamethodHook(internalEquals, self, rhs)
			end
		end
		return internalEquals(internalSelf, rhs)
	end

	local function internalCall(internalSelf: any, ...: any): never
		error(`attempt to call a {InstanceSandboxer.typeof(internalSelf)} value`, 2)
	end
	DEFAULT_METATABLE.__call = function(self, ...)
		local internalSelf = check(self)
		if typeof(internalSelf) == "Instance" then
			local metamethodHook = INST_METAMETHOD_HOOKS[internalSelf].__call
			if metamethodHook then
				return metamethodHook(internalCall, self, ...)
			end
		end
		return internalCall(internalSelf, ...)
	end

	local function internalConcat(internalSelf: any, v: any): never
		error(`attempt to concatenate {InstanceSandboxer.typeof(internalSelf)} with {InstanceSandboxer.typeof(v)}`, 2)
	end
	DEFAULT_METATABLE.__concat = function(self, v)
		local internalSelf = check(self)
		if typeof(internalSelf) == "Instance" then
			local metamethodHook = INST_METAMETHOD_HOOKS[internalSelf].__concat
			if metamethodHook then
				return metamethodHook(internalConcat, self, v)
			end
		end
		return internalConcat(internalSelf, v)
	end

	for _, math in MATH do
		local mtName = `__{math}`
		local function internalMath(internalSelf: any, rhs: any): never
			error(`attempt to perform arithmetic ({math}) on {InstanceSandboxer.typeof(internalSelf)}` 
				.. (InstanceSandboxer.typeof(rhs) ~= "Instance" and ` and {InstanceSandboxer.typeof(rhs)}` or ""), 
				2
			)
		end
		DEFAULT_METATABLE[mtName] = function(self, rhs)
			local internalSelf = check(self)
			if typeof(internalSelf) == "Instance" then
				local metamethodHook = INST_METAMETHOD_HOOKS[internalSelf][mtName]
				if metamethodHook then
					return metamethodHook(internalMath, self, rhs)
				end
			end
			return internalMath(internalSelf, rhs)
		end
	end

	local function internalLt(lhs: any, rhs: any): never
		error(
			`attempt to compare {InstanceSandboxer.typeof(lhs)} < {InstanceSandboxer.typeof(rhs)}`,
			2
		)
	end
	DEFAULT_METATABLE.__lt = function(lhs, rhs)
		local internalLhs = check(lhs)
		if typeof(internalLhs) == "Instance" then
			local metamethodHook = INST_METAMETHOD_HOOKS[internalLhs].__lt
			if metamethodHook then
				return metamethodHook(internalLt, lhs, rhs)
			end
		end
		return internalLt(lhs, rhs)
	end

	local function internalLe(lhs: any, rhs: any): never
		error(
			`attempt to compare {InstanceSandboxer.typeof(lhs)} <= {InstanceSandboxer.typeof(rhs)}`,
			2
		)
	end
	DEFAULT_METATABLE.__le = function(lhs, rhs)
		local internalLhs = check(lhs)
		if typeof(internalLhs) == "Instance" then
			local metamethodHook = INST_METAMETHOD_HOOKS[internalLhs].__le
			if metamethodHook then
				return metamethodHook(internalLe, lhs, rhs)
			end
		end
		return internalLe(lhs, rhs)
	end

	local function internalLen(self: any): never
		error(`attempt to get length of a {InstanceSandboxer.typeof(self)} value`, 2)
	end
	DEFAULT_METATABLE.__len = function(self)
		local internalSelf = check(self)
		if typeof(internalSelf) == "Instance" then
			local metamethodHook = INST_METAMETHOD_HOOKS[internalSelf].__len
			if metamethodHook then
				return metamethodHook(internalLen, self)
			end
		end
		return internalLen(internalSelf)
	end
	
	local function internalIter(self: any): never
		error(`attempt to iterate over a {InstanceSandboxer.typeof(self)} value`, 2)
	end
	DEFAULT_METATABLE.__iter = function(self)
		local internalSelf = check(self)
		if typeof(internalSelf) == "Instance" then
			local metamethodHook = INST_METAMETHOD_HOOKS[internalSelf].__iter
			if metamethodHook then
				return metamethodHook(internalIter, self)
			end
		end
		return internalIter(internalSelf)
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
	if WRAPPED_SIGNALS[signal] then
		return WRAPPED_SIGNALS[signal]
	end
	local proxy = newproxy(true)
	local metatable = getmetatable(proxy)

	-- Borrow the same metatable, but we're going to overwrite 
	-- __index and __newindex
	for k, v in DEFAULT_METATABLE do
		metatable[k] = v
	end

	metatable.__index = SIGNAL_INDEX_METAMETHOD
	metatable.__newindex = INDEX_FAIL

	--[[
	local STRING = string.match(`Signal {name}`, TRIM_WHITESPACE_PAT)
	metatable.__tostring = function()
		return STRING
	end
	]]

	WRAPPED_SIGNALS[signal] = proxy
	UNWRAP_SIGNALS[proxy] = signal

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

-- Make all native libraries have pass-throughs for functions.
-- They're all C functions, so GC isn't a problem
-- Skips Enum (not iterable), SharedTable (security) and Secret (Secret = nil)
do
	local libs: {any} = {
		bit32,
		buffer,
		coroutine,
		math,
		os,
		string,
		table,
		task,
		utf8,
		vector,
		Axes,
		BrickColor,
		CatalogSearchParams,
		Color3,
		ColorSequence,
		ColorSequenceKeypoint,
		Content,
		DateTime,
		DockWidgetPluginGuiInfo,
		Faces,
		FloatCurveKey,
		Font,
		NumberSequence,
		NumberSequenceKeypoint,
		OverlapParams,
		Path2DControlPoint,
		PathWaypoint,
		PhysicalProperties,
		Random,
		Ray,
		RaycastParams,
		Rect,
		Region3,
		Region3int16,
		RotationCurveKey,
		TweenInfo,
		UDim,
		UDim2,
		Vector2,
		Vector2int16,
		Vector3,
		Vector3int16
	}

	for _, lib in libs do
		for k, v in lib do
			METHOD_CACHE[v] = v
		end
	end
end

METHOD_CACHE[typeof] = InstanceSandboxer.typeof
METHOD_CACHE[InstanceSandboxer.typeof] = InstanceSandboxer.typeof

local function convertToMetamethodName(name: string): string
	if typeof(name) ~= "string" then
		return tostring(name)
	end
	if string.sub(name, 1, 2) == "__" then
		return name
	else
		return `__{name}`
	end
end

--[=[
	@within InstanceSandboxer

	Hooks a specific metamethod on a wrapped `Instance`. Allows for hooking functions
	on Instances, modifying behaviors, or changing properties within sandboxed code.

	### Safety Guarantees
	- `self` received by the hook is always the wrapped proxy; it is never auto-unwrapped.
	- Every additional argument reaches the hook untouched; no wrapping, unwrapping, or copying occurs.
	- Return values flow straight back to the sandbox exactly as yielded by the hook; no automatic wrapping occurs.
	- The hook therefore must explicitly call `InstanceSandboxer.unwrap`, `deepUnwrap`, `wrapInstance`,
	  `deepWrap`, or `wrapArgs` whenever data crosses the sandbox boundary. *It is the caller's responsibility to
	  ensure that this occurs correctly.*

	### Behavior
	- The hook completely replaces the default handling of the selected metamethod for `inst`.
	  - The option to revert to conditionally default behavior is available by calling the first argument,
	    which is the original metamethod function. This function expects an unwrapped `Instance` as its first argument,
		followed by any additional arguments passed to the metamethod. *It is highly recommended to passthrough arguments
		untouched to avoid unexpected behavior.*
	- If the hook does not call the original metamethod function, the default behavior is skipped.
	- Hooks do not chain; setting a hook for a metamethod that already has one overwrites the previous hook.
	- Hooks are per-instance, not inherited.

	@param inst -- **Unwrapped** Instance to hook.
	@param name -- Metamethod name (with or without `__` prefix) to hook.
	@param hook -- Callback invoked when the metamethod fires.
]=]
function InstanceSandboxer.hookMetamethod(inst: Instance, name: Metamethod, hook: MetamethodHook?)
	-- don't check this with InstanceSandboxer.typeof b/c
	-- it could let through wrapped instances and this should
	-- only be called with regular ones from regular scripts
	local mtName = convertToMetamethodName(name)
	assert(typeof(inst) == "Instance", "argument #1 to InstanceSandboxer.hookMetamethod must be an Instance")
	assert(DEFAULT_METATABLE[mtName],  `argument #2 to InstanceSandboxer.hookMetamethod must be a valid metamethod name, got '{tostring(name)}'. check the Roblox documentation for valid metamethod names`)
	assert(typeof(hook) == "function" or hook == nil, "argument #3 to InstanceSandboxer.hookMetamethod must be a function or nil")

	INST_METAMETHOD_HOOKS[inst][mtName] = hook :: any
end

InstanceSandboxer.METHOD_CACHE = METHOD_CACHE

return InstanceSandboxer