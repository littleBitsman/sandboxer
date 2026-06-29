--[[
    Sandbox Configuration Script
    
    This script configures the sandbox environment before the sandboxed script runs.
    You can set custom globals, enable Roblox globals, or configure other sandbox settings.
]]

-- Set to true to enable dummy Roblox globals (game, workspace, Instance, Vector3, etc.)
USE_ROBLOX_GLOBALS = true

-- Define custom sandbox configuration
-- These will be available in the sandboxed script's environment
SANDBOX_CONFIG = {
    -- Add custom functions
    customFunction = function(msg)
        print("[Custom]", msg)
    end,
    
    -- Add custom values
    customValue = 42,
    
    -- You can add more custom globals here
}

print("Configuration loaded: Roblox globals =", USE_ROBLOX_GLOBALS)
