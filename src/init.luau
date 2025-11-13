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
	@class Sandboxer
	
	The main Sandboxer class. This class is intended to be used as follows,
	where the module is placed in ServerScriptService named `Init`:
	```lua
	require(game:GetService("ServerScriptService").Init):Init()
	```
	This would be expected to be the first line of all scripts that are to be sandboxed
	(not including `--!strict`, `--!optimize`, and other directives).

	Having this be the first line guarantees that the script is sandboxed before any other code runs.
	You would have to check if it is the first line of code yourself, using external sources with
	modules such as [rbx-reader](https://npmjs.org/package/rbx-reader).
	
	More customizability is planned for the future, such as:
	- Customizing the environment
	- Customizing allowed Instances
	- Customizing allowed RBXScriptSignals
	- Customizing allowed methods
]=]
local Sandboxer = {}

local __METATABLE = "No."
local InstanceSandboxer = require("@self/InstanceSandboxer")
local InstanceList = require("@self/InstanceList")

-- TODO: any way to get around deoptimization because of this? (and getfenv/setfenv below?)
local LOADSTRING_ENABLED = pcall(loadstring, "return nil")

-- Thank you roblox, very cool! (deprecation warnings - WHO CARES)
local getfenv, setfenv = getfenv, setfenv
local version, elapsedTime do
	-- little hack to make these not be annoying
	local fenv = getfenv(0)

	version = {fenv.version, fenv.Version}
	elapsedTime = {fenv.elapsedTime, fenv.ElapsedTime}
end

local GAME_SANDBOXED = InstanceSandboxer.wrapInstance(game)
local WORKSPACE_SANDBOXED = InstanceSandboxer.wrapInstance(workspace)

function _fprint(...: any)
	print("[SANDBOX SECURITY]", ...)
end
function fwarn(...: any)
	warn("[SANDBOX SECURITY]", ...)
end
function _ferror(msg: string, level: number?)
	error("[SANDBOX SECURITY]" .. msg, level or 0)
end
function _fassert(expr: any, msg: string?)
	assert(expr, "[SANDBOX SECURITY]" .. (msg or "assertion failed!"))
end

function nope(): never
	error("nuh uh", 0)
end

function xpcallIsBad(...: any): never
	error("xpcall is disabled, use pcall instead", 2)
end

local STRING_RESOLVER_PATTERN = "([^/]+)/?"
function ResolveStringPath(mod: Instance, str: string): Instance?
	local iter = str:gmatch(STRING_RESOLVER_PATTERN)
	local currentInstance: Instance? do
		local first = iter()
		if first == "." then
			currentInstance = mod.Parent
		elseif first == ".." then
			if not mod.Parent then return end
			currentInstance = mod.Parent.Parent
		elseif first == "@self" then
			currentInstance = mod
		end
	end

	for resolver in iter do
		if not currentInstance then return end

		if resolver == ".." then
			currentInstance = currentInstance.Parent
		else
			currentInstance = currentInstance:FindFirstChild(resolver)
		end
	end

	return currentInstance
end

local realrequire = require
-- The real caller is level 3 (1 = SafeRequire, 2 = _require, 3 = caller of _require)
function SafeRequire(module: (Instance | string | number)?, caller: Instance): any
	if typeof(module) == "string" then
		if not caller then
			error(`Unable to require module from given path '{module}'`, 3)
		end
		local new = ResolveStringPath(caller, module)
		if not new or not InstanceList.instanceAllowed(new) then
			new = nil
		end
		module = new
	end
	if typeof(module) ~= "Instance" then
		-- Steal it from roblox hehe
		error("Attempted to call require with invalid argument(s).", 3)
	end
	return realrequire(module)
end

-- Returns highest available environment, and its level relative to this function's caller.
function GetHighestEnv(): ({ [string]: any }, number)
	local i = 0
	while true do
		local ok, env = pcall(getfenv, i)
		if not ok or env == nil then
			break
		end
		i += 1
	end
	return getfenv(i - 2), i - 3
end

-- I honestly have no idea why i wrote this lol
function _hahano()
	local Env, Level = GetHighestEnv()
	local CallingScriptWrapped: any = Env.script
	local CallingScript: BaseScript

	if InstanceSandboxer.isWrapped(CallingScriptWrapped) then
		CallingScript = InstanceSandboxer.unwrap(CallingScriptWrapped) :: any
	elseif typeof(CallingScriptWrapped) == "Instance" then
		CallingScript = CallingScriptWrapped :: any
	else
		fwarn("SANDBOX BREACH DETECTED FROM UNKNOWN SCRIPT !!")
		nope()
	end

	-- Log info for auditing
	fwarn("SANDBOX BREACH:", CallingScript:GetFullName())

	-- Clear environment
	setfenv(Level, {})

	-- Try to disable and destroy safely
	pcall(function()
		CallingScript.Enabled = false
		CallingScript:Destroy()
	end)

	nope()
end

local ForbiddenGlobals: { [any]: boolean } = {
	[getfenv] = true,
	[setfenv] = true,
	[loadstring] = true,
	[newproxy] = true,
	[debug] = true,
	[debug.info] = true,
	[debug.traceback] = true
}
local SANDBOX_CONFIG: { [string]: any } = {}

--[=[
	@within Sandboxer

	Edits the default sandbox configuration. This is used to add or remove certain
	globals in the sandbox environment.

	The config is saved and will be used for all future sandboxes **made AFTER this
	function is called**. Calls to this will overwrite previous values, if any.

	Due to dictionary limitations, values cannot be set to `nil`. To remove a global,
	set the value to `false`.

	The following globals are **always** removed from the sandbox:
	- `getfenv`
	- `setfenv`
	- `loadstring`
	- `newproxy`
	- `debug` (library), `debug.info`, & `debug.traceback`

	Attempting to add these functions/libraries will result in them being ignored.
	However, you can set them to other values, such as a custom function.
	This will also allow you to overwrite already sandboxed globals, such as `game`.
	
	The sandboxer will make **no attempt** to secure custom functions, so use them
	at your own risk. The only change that will occur is that if the function returns
	`Instance`s, they will be wrapped, and if wrapped `Instance`s are passed to the
	function, they will be unwrapped.

	Do note that the environment table passed to `setfenv` does NOT have a metatable,
	unlike Roblox's default environment. 

	The function will return `true` if the operation was completely successful
	(i.e., all values were set on the configuration table) and `false` if any 
	of the keys or values were forbidden globals.

	**The table is NOT recursively checked for forbidden globals. If you manage
	to bypass the checks, you are responsible for any consequences.**

	@param config -- A table containing the configuration for the sandbox.

	@return boolean -- Whether the operation was *completely* successful.
]=]
function Sandboxer.EditDefaultSandbox(config: { [string]: any }): boolean
	local success = true
	for key, value in config do
		if not (ForbiddenGlobals[value] or ForbiddenGlobals[key]) then
			SANDBOX_CONFIG[key] = value
		else
			success = false
		end
	end
	return success
end

--[=[
	@within Sandboxer

	Initializes the sandbox environment for the calling script.

	The following globals are **removed**:
	- `SharedTable`
	- `debug` library
	- `getfenv`
	- `setfenv`
	- `loadstring`
	- `newproxy`
	- `xpcall` (*note: use `pcall` instead*)

	All other globals are set to sandboxed versions of the originals.

	A separate table is created for `_G` / `shared`
]=]
function Sandboxer:Init()	
	local CallingFenv, LEVEL = GetHighestEnv()
	if CallingFenv.game == GAME_SANDBOXED then
		return
	end

	local theFunction = debug.info(LEVEL, "f")

	Sandboxer:Sandbox(theFunction)
end

local IS_SANDBOXED_REF = newproxy()

--[=[
	@within Sandboxer

	Sandboxes the given function or the calling script at the specified level.

	| Level | Definition |
	|-------|------------|
	| 1     | function calling `Sandboxer:Sandbox` |
	| 2     | caller of the above function |
	| 3...  | etc. |

	@param fnOrLevel -- The function to sandbox or the level to sandbox at.
	@error "level must be at least 1" -- If fnOrLevel is a number, it must be at least 1.
]=]
function Sandboxer:Sandbox(fnOrLevel: InstanceSandboxer.AnyFn | number)
	local fn
	if typeof(fnOrLevel) == "number" then
		assert(fnOrLevel >= 1, "level must be at least 1")
		fnOrLevel += 1 -- add depth for this function
		fn = debug.info(fnOrLevel, "f")
	else
		InstanceSandboxer.requireType(fnOrLevel, "function", `expected function or level number, got {typeof(fnOrLevel)}`)
		fn = fnOrLevel
	end

	local IsValid, CallingFenv = pcall(getfenv, fn)
	if not IsValid then
		error("invalid level or function", 2)
	end
	if getmetatable(CallingFenv :: any) == IS_SANDBOXED_REF then
		return
	end
	local CallingScript = CallingFenv.script
	local WrappedScript = InstanceSandboxer.wrapInstance(CallingScript)

	local function _require(a: any)
		return SafeRequire(a, CallingScript)
	end

	local self_G = {}

	-- Big boi
	local fenv = {
		_G = self_G,
		shared = self_G,

		game = GAME_SANDBOXED,
		Game = GAME_SANDBOXED,
		workspace = WORKSPACE_SANDBOXED,
		Workspace = WORKSPACE_SANDBOXED,
		script = WrappedScript,

		-- Not-so-dangerous-but-still-dangerous stuff
		xpcall = xpcallIsBad,

		-- Normal stuff
		print = print,
		warn = warn,
		error = error,
		assert = assert,
		gcinfo = gcinfo,
		getmetatable = getmetatable,
		ipairs = ipairs,
		next = next,
		pairs = pairs,
		pcall = pcall,
		rawget = rawget,
		rawset = rawset,
		rawequal = rawequal,
		rawlen = rawlen,
		require = _require,
		select = select,
		setmetatable = setmetatable,
		tonumber = tonumber,
		tostring = tostring,
		type = type,
		typeof = typeof,
		unpack = unpack,

		-- I'm not sure if this is even used but sure ok
		_VERSION = _VERSION,
		settings = settings,
		UserSettings = UserSettings,

		-- These are the same. WHY ARE THEY NAMED DIFFERENTLY?
		version = version[1],
		Version = version[2],
		elapsedTime = elapsedTime[1],
		ElapsedTime = elapsedTime[2],

		-- Task (replace the old bad globals with the cool ones)
		delay = task.delay,
		spawn = task.defer,
		wait = task.wait,
		task = task,

		tick = tick,
		time = time, 

		-- Libraries
		bit32 = bit32,
		buffer = buffer,
		coroutine = coroutine,
		math = math,
		os = os,
		string = string,
		table = table,
		utf8 = utf8,
		vector = vector, -- Isn't this just Vector3 lol

		-- Data Types
		Axes = Axes,
		BrickColor = BrickColor,
		CatalogSearchParams = CatalogSearchParams,
		CFrame = CFrame,
		Color3 = Color3,
		ColorSequence = ColorSequence,
		ColorSequenceKeypoint = ColorSequenceKeypoint,
		Content = Content,
		DateTime = DateTime,
		DockWidgetPluginGuiInfo = DockWidgetPluginGuiInfo,
		Enum = Enum,
		Faces = Faces,
		FloatCurveKey = FloatCurveKey,
		Font = Font,
		Instance = Instance, -- wrapped using a lil trick with METHOD_CACHE
		NumberRange = NumberRange,
		NumberSequence = NumberSequence,
		NumberSequenceKeypoint = NumberSequenceKeypoint,
		OverlapParams = OverlapParams,
		Path2DControlPoint = Path2DControlPoint,
		PathWaypoint = PathWaypoint,
		PhysicalProperties = PhysicalProperties,
		Random = Random,
		Ray = Ray,
		RaycastParams = RaycastParams,
		Rect = Rect,
		Region3 = Region3,
		Region3int16 = Region3int16,
		RotationCurveKey = RotationCurveKey,
		Secret = Secret, -- this is literally nil LOL
		SharedTable = nil, -- TODO wat is this
		TweenInfo = TweenInfo,
		UDim = UDim,
		UDim2 = UDim2,
		Vector2 = Vector2,
		Vector2int16 = Vector2int16,
		Vector3 = Vector3,
		Vector3int16 = Vector3int16
	}

	for key, value in SANDBOX_CONFIG do
		if value == false then
			fenv[key] = nil
		else
			fenv[key] = value
		end
	end

	fenv = setmetatable(InstanceSandboxer.deepWrap(fenv), {
		__metatable = IS_SANDBOXED_REF
	})

	-- The end yay
	setfenv(fn, fenv)
end

--[=[
	@within Sandboxer

	Loads the Luau chunk `src` as a function using `loadstring` and 
	sandboxes it. **`ServerScriptService.LoadStringEnabled` must be `true`
	for this to work as per the `loadstring` rules.**

	@param src -- The specified string to be loaded as Luau code.
	@param chunkname -- An optional chunk name for error messages and debug information.

	@error "loadstring() is not available" -- ServerScriptService.LoadStringEnabled was false.
]=]
function Sandboxer:SandboxString(src: string, chunkname: string): InstanceSandboxer.AnyFn
	if LOADSTRING_ENABLED then
		local success, fn: InstanceSandboxer.AnyFn?, luaError: string? = pcall(loadstring, src, chunkname)

		if not success then
			-- fn is the error
			error(fn, 2)
		elseif not fn then
			-- luaError will exist if fn is nil
			error(luaError, 2)
		end

		Sandboxer:Sandbox(fn)

		return fn
	else
		error("loadstring() is not available", 2)
	end
end

Sandboxer.typeof = InstanceSandboxer.typeof
Sandboxer.InstanceList = InstanceList

-- allow HttpService methods like GenerateGUID and JSON functions, but disallow network with hooks
do
	local HttpService = game:GetService("HttpService")
	InstanceList.Allow[HttpService] = false -- can still be disabled by ExplicitDisallow
	InstanceSandboxer.hookFunction(HttpService, "GetAsync", function(_origFn, ...)
		error("GetAsync is disabled", 2)
	end)
	InstanceSandboxer.hookFunction(HttpService, "PostAsync", function(_origFn, ...)
		error("PostAsync is disabled", 2)
	end)
	InstanceSandboxer.hookFunction(HttpService, "RequestAsync", function(_origFn, ...)
		error("RequestAsync is disabled", 2)
	end)
	InstanceSandboxer.hookFunction(HttpService, "GetSecret", function(_origFn, ...)
		error("GetSecret is disabled", 2)
	end)
end

return setmetatable(Sandboxer, {
	__index = nope,
	__newindex = nope,
	__metatable = __METATABLE
})