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

--[=[
	@class Sandboxer
	
	The main Sandboxer class.
]=]
local Sandboxer = {}
local __METATABLE = "No."
local InstanceSandboxer = require("@self/InstanceSandboxer")

-- Thank you roblox, very cool! (deprecation warnings - WHO CARES)
local getfenv, setfenv = getfenv, setfenv
local version, elapsedTime do
	-- little hack to make these not be annoying
	local fenv = getfenv(0)

	version = {fenv.Version, fenv.Version}
	elapsedTime = {fenv.elapsedTime, fenv.ElapsedTime}
end

local GAME_SANDBOXED = InstanceSandboxer.wrapInstance(game)
local WORKSPACE_SANDBOXED = InstanceSandboxer.wrapInstance(workspace)

local function fprint(...: any)
	print("[FEUCM SECURITY]", ...)
end
local function fwarn(...: any)
	warn("[FEUCM SECURITY]", ...)
end
local function ferror(msg: string, level: number?)
	error("[FEUCM SECURITY]" .. msg, level or 0)
end
local function fassert(expr: any, msg: string?)
	assert(expr, "[FEUCM SECURITY]" .. (msg or "assertion failed!"))
end

function xpcallIsBad(...: any)
	return error("xpcall is disabled, use pcall instead", 0)
end

local STRING_RESOLVER_PATTERN = "([%a.@]+)/?"
--[=[
	@within Sandboxer
	@private
]=]
function ResolveStringPath(mod: Instance, str: string): Instance?
	local i = 0
	local currentInstance: Instance?
	for resolver, _ in str:gmatch(STRING_RESOLVER_PATTERN) do
		i += 1
		if i == 1 then
			if resolver == "." then
				currentInstance = mod.Parent
			elseif resolver == ".." then
				if not mod.Parent then return end
				currentInstance = mod.Parent.Parent
			elseif resolver == "@self" then
				currentInstance = mod
			else
				return
			end
		elseif currentInstance then
			if resolver == ".." then
				currentInstance = currentInstance.Parent
			else
				currentInstance = currentInstance:FindFirstChild(resolver)
			end
		end
		
		if not currentInstance then return end
	end
	
	return currentInstance
end

local _require = require
function SafeRequire(module: (Instance | string | number)?, caller: Instance): any
	if typeof(module) == "string" then
		local new = ResolveStringPath(caller, module)
		if not new or not InstanceSandboxer.instanceAllowed(new) then
			new = nil
		end
		module = new
	end
	if typeof(module) ~= "Instance" then
		-- Steal it from roblox hehe
		error("Attempted to call require with invalid argument(s).", 0)
	end
	return _require(module)
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

function hahano()
	local Env, Level = GetHighestEnv()
	local CallingScriptWrapped: any = Env.script
	local CallingScript: BaseScript

	if InstanceSandboxer.isWrapped(CallingScriptWrapped) then
		CallingScript = InstanceSandboxer.unwrap(CallingScriptWrapped) :: any
	elseif typeof(CallingScriptWrapped) == "Instance" then
		CallingScript = CallingScriptWrapped :: any
	else
		fwarn("SANDBOX BREACH DETECTED FROM UNKNOWN SCRIPT !!")
		error("No.", 0)
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
	
	error("No.", 0)
end

-- Side note - type() will report wrapped Instances/RBXScriptSignals 
-- as userdata anyways so we don't have to wrap that. 
local _typeof = require("@self/typeof")

function _rawget<K, V>(...): V?
	local t: { [K]: V }, k: K = InstanceSandboxer.requireArguments(2, ...)
	if InstanceSandboxer.isWrapped(t) then
		error("invalid argument #1 to 'rawget' (table expected, got Instance)", 0)
	elseif InstanceSandboxer.isWrappedSignal(t) then
		error("invalid argument #1 to 'rawget' (table expected, got RBXScriptSignal)", 0)
	else
		return rawget(t, k)
	end
end

function _rawset<K, V>(...)
	local t: { [K]: V }, k: K, v: V = InstanceSandboxer.requireArguments(3, ...)
	if InstanceSandboxer.isWrapped(t) then
		error("invalid argument #1 to 'rawset' (table expected, got Instance)", 0)
	elseif InstanceSandboxer.isWrappedSignal(t) then
		error("invalid argument #1 to 'rawset' (table expected, got RBXScriptSignal)", 0)
	else
		rawset(t, k, v)
	end
end

function _rawequal(...): boolean
	local a, b = InstanceSandboxer.requireArguments(2, ...)
	if InstanceSandboxer.isWrapped(a) or InstanceSandboxer.isWrapped(b) 
		or InstanceSandboxer.isWrappedSignal(a) or InstanceSandboxer.isWrappedSignal(b)
	then
		return a == b 
	else
		return rawequal(a, b)
	end
end

function Sandboxer:Init()	
	local CallingFenv, LEVEL = GetHighestEnv()
	if CallingFenv.getfenv == hahano then return end
	local CallingScript = CallingFenv.script :: BaseScript
	local WrappedScript = InstanceSandboxer.wrapInstance(CallingScript)
	
	local function LocalRequire(a: any)
		return SafeRequire(a, CallingScript)
	end
	
	-- Big boi
	local fenv = {
		-- Straightup gone
		_G = nil,
		shared = nil,
		plugin = nil, -- This wouldn't exist anyways...right
		
		game = GAME_SANDBOXED,
		Game = GAME_SANDBOXED,
		workspace = WORKSPACE_SANDBOXED,
		Workspace = WORKSPACE_SANDBOXED,
		script = WrappedScript,
		
		-- Dangerous stuff
		getfenv = hahano,
		setfenv = hahano,
		loadstring = hahano,
		newproxy = hahano,
		
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
		select = select,
		setmetatable = setmetatable,
		tonumber = tonumber,
		tostring = tostring,
		type = type,
		unpack = unpack,
		-- (Changed)
		require = LocalRequire,
		typeof = _typeof,
		
		-- Raw table methods
		rawget = _rawget,
		rawset = _rawset,
		rawequal = _rawequal,
		rawlen = rawlen, -- This doesn't leak anything if it's a wrapped value so its OK!
		
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
		spawn = task.spawn,
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
		Instance = InstanceSandboxer.Instance,
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
		Secret = Secret, -- This is literally just { } what is the point
		SharedTable = nil, -- TODO wat is this
		TweenInfo = TweenInfo,
		UDim = UDim,
		UDim2 = UDim2,
		Vector2 = Vector2,
		Vector2int16 = Vector2int16,
		Vector3 = Vector3,
		Vector3int16 = Vector3int16
	}
	
	-- The end yay
	setfenv(LEVEL, fenv)
end

return setmetatable(Sandboxer, {
	__index = hahano,
	__newindex = hahano,
	__metatable = __METATABLE
})