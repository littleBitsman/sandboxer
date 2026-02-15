--[[
    Sandboxed Script
    
    This script runs inside the sandbox with limited access to globals.
    It demonstrates various sandbox features and limitations.
]]

print("=== Testing Sandbox Features ===")
print()

-- Test basic Luau functionality
print("1. Basic Luau:")
local x = 5
local y = 10
print("  x + y =", x + y)
print()

-- Test standard library access
print("2. Standard Libraries:")
print("  math.sqrt(16) =", math.sqrt(16))
print("  string.upper('hello') =", string.upper("hello"))
print()

-- Test custom globals from config
print("3. Custom Configuration:")
if customFunction then
    customFunction("Hello from sandboxed script!")
end
if customValue then
    print("  Custom value:", customValue)
end
print()

-- Test Roblox globals if enabled
print("4. Roblox Globals (if enabled):")
if game then
    print("  game exists:", game)
    print("  game.ClassName:", game.ClassName)
end

if workspace then
    print("  workspace exists:", workspace)
end

if Instance then
    print("  Creating instance...")
    local part = Instance.new("Part")
    print("  Created:", part)
    print("  Part.Name:", part.Name)
    print("  Part.ClassName:", part.ClassName)
end

if Vector3 then
    local v1 = Vector3.new(1, 2, 3)
    local v2 = Vector3.new(4, 5, 6)
    print("  Vector3 math:", tostring(v1 + v2))
end

if Color3 then
    local color = Color3.fromRGB(255, 128, 0)
    print("  Color3:", tostring(color))
end
print()

-- Test shared/global table
print("5. Shared State:")
_G.sharedData = "This is shared"
print("  _G.sharedData:", _G.sharedData)
print("  shared.sharedData:", shared.sharedData)
print()

-- Test restrictions (these should not be available)
print("6. Testing Restrictions:")
print("  getfenv:", getfenv)
print("  setfenv:", setfenv)
print("  loadstring:", loadstring)
print("  debug:", debug)
print()

print("=== Sandbox Test Complete ===")
