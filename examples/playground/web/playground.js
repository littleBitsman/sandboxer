/**
 * Luau Sandboxer Playground
 * Web-based playground for testing sandbox configurations
 * Uses Fengari (Lua 5.3 in JavaScript)
 */

let outputElement = null;
let configEditor = null;
let sandboxedEditor = null;

// Initialize the playground
function initPlayground() {
    outputElement = document.getElementById('output');
    configEditor = document.getElementById('config-editor');
    sandboxedEditor = document.getElementById('sandboxed-editor');

    // Set up event listeners
    document.getElementById('run-btn').addEventListener('click', runPlayground);
    document.getElementById('clear-btn').addEventListener('click', clearOutput);

    // Check if Fengari is loaded
    if (typeof fengari !== 'undefined') {
        addOutput('✓ Playground initialized and ready!', 'success');
        addOutput('Note: Using Fengari (Lua 5.3). Full Luau syntax may not be supported.', 'info');
    } else {
        addOutput('✗ Fengari not loaded. Please check your internet connection.', 'error');
    }
}

// Add output line to display
function addOutput(text, type = 'normal') {
    const line = document.createElement('div');
    line.className = `output-line ${type}`;
    line.textContent = text;
    outputElement.appendChild(line);
    outputElement.scrollTop = outputElement.scrollHeight;
}

// Clear output display
function clearOutput() {
    outputElement.innerHTML = '';
}

// Run the playground
function runPlayground() {
    if (typeof fengari === 'undefined') {
        addOutput('✗ Fengari not loaded', 'error');
        return;
    }

    clearOutput();
    addOutput('=== Luau Sandboxer Playground ===', 'info');
    addOutput('', 'normal');
    
    const configScript = configEditor.value;
    const sandboxedScript = sandboxedEditor.value;
    
    try {
        const L = fengari.lauxlib.luaL_newstate();
        fengari.lualib.luaL_openlibs(L);

        // Override print function to capture output
        const printFn = function(L) {
            const nargs = fengari.lua.lua_gettop(L);
            const args = [];
            for (let i = 1; i <= nargs; i++) {
                const val = fengari.lua.lua_tostring(L, i);
                args.push(fengari.interop.to_jsstring(val));
            }
            addOutput(args.join('\t'), 'normal');
            return 0;
        };
        
        fengari.lua.lua_pushcfunction(L, printFn);
        fengari.lua.lua_setglobal(L, fengari.to_luastring("print"));

        // Step 1: Execute configuration script
        addOutput('Loading configuration script...', 'info');
        const configResult = fengari.lauxlib.luaL_loadstring(L, fengari.to_luastring(configScript));
        if (configResult !== fengari.lua.LUA_OK) {
            const error = fengari.lua.lua_tostring(L, -1);
            throw new Error('Config parse error: ' + fengari.interop.to_jsstring(error));
        }
        
        const configExecResult = fengari.lua.lua_pcall(L, 0, 0, 0);
        if (configExecResult !== fengari.lua.LUA_OK) {
            const error = fengari.lua.lua_tostring(L, -1);
            throw new Error('Config execution error: ' + fengari.interop.to_jsstring(error));
        }

        addOutput('Setting up sandbox environment...', 'info');

        // Step 2: Get USE_ROBLOX_GLOBALS
        fengari.lua.lua_getglobal(L, fengari.to_luastring("USE_ROBLOX_GLOBALS"));
        const useRobloxGlobals = fengari.lua.lua_toboolean(L, -1);
        fengari.lua.lua_pop(L, 1);

        // Step 3: Add Roblox globals if requested
        if (useRobloxGlobals) {
            addOutput('Adding dummy Roblox globals...', 'info');
            setupRobloxGlobals(L);
        }

        // Step 4: Apply custom SANDBOX_CONFIG
        fengari.lua.lua_getglobal(L, fengari.to_luastring("SANDBOX_CONFIG"));
        if (fengari.lua.lua_istable(L, -1)) {
            fengari.lua.lua_pushnil(L);
            while (fengari.lua.lua_next(L, -2) !== 0) {
                const key = fengari.lua.lua_tostring(L, -2);
                // Copy value to global
                fengari.lua.lua_pushvalue(L, -1);
                fengari.lua.lua_setglobal(L, key);
                fengari.lua.lua_pop(L, 1);
            }
        }
        fengari.lua.lua_pop(L, 1);

        // Create sandboxed _G and shared
        fengari.lua.lua_newtable(L);
        fengari.lua.lua_pushvalue(L, -1);
        fengari.lua.lua_setglobal(L, fengari.to_luastring("_G"));
        fengari.lua.lua_setglobal(L, fengari.to_luastring("shared"));

        addOutput('Running sandboxed script...', 'info');
        addOutput('', 'normal');
        addOutput('--- Output ---', 'info');

        // Step 5: Execute sandboxed script
        const sandboxResult = fengari.lauxlib.luaL_loadstring(L, fengari.to_luastring(sandboxedScript));
        if (sandboxResult !== fengari.lua.LUA_OK) {
            const error = fengari.lua.lua_tostring(L, -1);
            throw new Error('Script parse error: ' + fengari.interop.to_jsstring(error));
        }

        const sandboxExecResult = fengari.lua.lua_pcall(L, 0, 0, 0);
        if (sandboxExecResult !== fengari.lua.LUA_OK) {
            const error = fengari.lua.lua_tostring(L, -1);
            throw new Error('Script execution error: ' + fengari.interop.to_jsstring(error));
        }

        addOutput('--- End Output ---', 'info');
        addOutput('', 'normal');
        addOutput('✓ Script executed successfully', 'success');

    } catch (error) {
        addOutput('--- End Output ---', 'info');
        addOutput('', 'normal');
        addOutput('✗ Script execution failed:', 'error');
        addOutput(error.message || String(error), 'error');
        console.error('Execution error:', error);
    }
}

// Set up dummy Roblox globals
function setupRobloxGlobals(L) {
    // Create dummy Instance metatable
    const instanceMeta = `
        local Instance = {}
        Instance.__index = Instance
        
        function Instance.new(className, parent)
            local inst = setmetatable({
                ClassName = className,
                Name = className,
                Parent = parent
            }, Instance)
            return inst
        end
        
        function Instance:IsA(className)
            return self.ClassName == className
        end
        
        function Instance:GetFullName()
            local path = {self.Name}
            local current = self.Parent
            while current do
                table.insert(path, 1, current.Name)
                current = current.Parent
            end
            return table.concat(path, ".")
        end
        
        function Instance:FindFirstChild(name, recursive)
            return nil
        end
        
        function Instance:GetChildren()
            return {}
        end
        
        function Instance:__tostring()
            return self.Name
        end
        
        return Instance
    `;
    
    fengari.lauxlib.luaL_loadstring(L, fengari.to_luastring(instanceMeta));
    fengari.lua.lua_pcall(L, 0, 1, 0);
    fengari.lua.lua_setglobal(L, fengari.to_luastring("Instance"));

    // Create game
    const gameCode = `
        local game = Instance.new("DataModel")
        game.Name = "game"
        return game
    `;
    fengari.lauxlib.luaL_loadstring(L, fengari.to_luastring(gameCode));
    fengari.lua.lua_pcall(L, 0, 1, 0);
    fengari.lua.lua_setglobal(L, fengari.to_luastring("game"));
    fengari.lua.lua_pushvalue(L, -1);
    fengari.lua.lua_setglobal(L, fengari.to_luastring("Game"));

    // Create workspace
    const workspaceCode = `
        local workspace = Instance.new("Workspace")
        workspace.Name = "Workspace"
        return workspace
    `;
    fengari.lauxlib.luaL_loadstring(L, fengari.to_luastring(workspaceCode));
    fengari.lua.lua_pcall(L, 0, 1, 0);
    fengari.lua.lua_setglobal(L, fengari.to_luastring("workspace"));
    fengari.lua.lua_pushvalue(L, -1);
    fengari.lua.lua_setglobal(L, fengari.to_luastring("Workspace"));

    // Create script
    const scriptCode = `
        local script = Instance.new("Script")
        script.Name = "Script"
        return script
    `;
    fengari.lauxlib.luaL_loadstring(L, fengari.to_luastring(scriptCode));
    fengari.lua.lua_pcall(L, 0, 1, 0);
    fengari.lua.lua_setglobal(L, fengari.to_luastring("script"));

    // Create Vector3
    const vector3Meta = `
        local Vector3 = {}
        Vector3.__index = Vector3
        
        function Vector3.new(x, y, z)
            return setmetatable({
                X = x or 0,
                Y = y or 0,
                Z = z or 0,
                x = x or 0,
                y = y or 0,
                z = z or 0
            }, Vector3)
        end
        
        function Vector3:__add(other)
            return Vector3.new(self.X + other.X, self.Y + other.Y, self.Z + other.Z)
        end
        
        function Vector3:__sub(other)
            return Vector3.new(self.X - other.X, self.Y - other.Y, self.Z - other.Z)
        end
        
        function Vector3:__mul(scalar)
            return Vector3.new(self.X * scalar, self.Y * scalar, self.Z * scalar)
        end
        
        function Vector3:__tostring()
            return self.X .. ", " .. self.Y .. ", " .. self.Z
        end
        
        return Vector3
    `;
    fengari.lauxlib.luaL_loadstring(L, fengari.to_luastring(vector3Meta));
    fengari.lua.lua_pcall(L, 0, 1, 0);
    fengari.lua.lua_setglobal(L, fengari.to_luastring("Vector3"));

    // Create Color3
    const color3Meta = `
        local Color3 = {}
        Color3.__index = Color3
        
        function Color3.new(r, g, b)
            return setmetatable({
                R = r or 0,
                G = g or 0,
                B = b or 0,
                r = r or 0,
                g = g or 0,
                b = b or 0
            }, Color3)
        end
        
        function Color3.fromRGB(r, g, b)
            return Color3.new(r / 255, g / 255, b / 255)
        end
        
        function Color3:__tostring()
            return self.R .. ", " .. self.G .. ", " .. self.B
        end
        
        return Color3
    `;
    fengari.lauxlib.luaL_loadstring(L, fengari.to_luastring(color3Meta));
    fengari.lua.lua_pcall(L, 0, 1, 0);
    fengari.lua.lua_setglobal(L, fengari.to_luastring("Color3"));

    // Create CFrame
    const cframeMeta = `
        local CFrame = {}
        CFrame.__index = CFrame
        
        function CFrame.new(x, y, z)
            local pos = Vector3.new(x, y, z)
            return setmetatable({
                X = x or 0,
                Y = y or 0,
                Z = z or 0,
                Position = pos
            }, CFrame)
        end
        
        function CFrame:__tostring()
            return self.X .. ", " .. self.Y .. ", " .. self.Z
        end
        
        return CFrame
    `;
    fengari.lauxlib.luaL_loadstring(L, fengari.to_luastring(cframeMeta));
    fengari.lua.lua_pcall(L, 0, 1, 0);
    fengari.lua.lua_setglobal(L, fengari.to_luastring("CFrame"));

    // Create UDim2
    const udim2Meta = `
        local UDim2 = {}
        UDim2.__index = UDim2
        
        function UDim2.new(xScale, xOffset, yScale, yOffset)
            return setmetatable({
                X = {Scale = xScale or 0, Offset = xOffset or 0},
                Y = {Scale = yScale or 0, Offset = yOffset or 0}
            }, UDim2)
        end
        
        function UDim2:__tostring()
            return "{" .. self.X.Scale .. ", " .. self.X.Offset .. "}, {" .. self.Y.Scale .. ", " .. self.Y.Offset .. "}"
        end
        
        return UDim2
    `;
    fengari.lauxlib.luaL_loadstring(L, fengari.to_luastring(udim2Meta));
    fengari.lua.lua_pcall(L, 0, 1, 0);
    fengari.lua.lua_setglobal(L, fengari.to_luastring("UDim2"));

    // Create Enum
    const enumCode = `
        return {
            Material = {
                Plastic = 256,
                Wood = 512,
                Concrete = 816,
                Metal = 1088
            },
            PartType = {
                Ball = 0,
                Block = 1,
                Cylinder = 2
            }
        }
    `;
    fengari.lauxlib.luaL_loadstring(L, fengari.to_luastring(enumCode));
    fengari.lua.lua_pcall(L, 0, 1, 0);
    fengari.lua.lua_setglobal(L, fengari.to_luastring("Enum"));
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initPlayground);
} else {
    initPlayground();
}
