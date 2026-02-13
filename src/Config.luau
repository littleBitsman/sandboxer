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

--[=[
    @class Config
    
    A module for configuring various aspects of the sandbox.
]=]
local Config = {}

--[=[
    @within Config
    @prop TrackInstances boolean
    @readonly
    
    Whether the sandbox should track `Instance`s.
    
    If this is enabled, the sandbox will keep track of all `Instance`s
    that are created in the sandbox. It will also track all `Instance`s 
    that are accessed in the sandbox.
    
    This will allow for forcible cleanup of `Instance`s that are created 
    in the sandbox, but it may cause performance issues if there are a lot 
    of `Instance`s being created.
]=]
Config.TrackInstances = false

--[=[
    @within Config
    @prop TrackRBXScriptConnections boolean
    @readonly
    
    Whether the sandbox should track `RBXScriptConnection`s.
    
    If this is enabled, the sandbox will keep track of all 
    `RBXScriptConnection`s that are created in the sandbox.
    This will allow for forcible cleanup of `RBXScriptConnection`s 
    that are created in the sandbox, but it may cause performance 
    issues if there are a lot of `RBXScriptConnection`s being created.
]=]
Config.TrackRBXScriptConnections = false

return table.freeze(Config)