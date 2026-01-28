/**
 * Luau Sandboxer Playground
 * Web-based playground for testing sandbox configurations
 */

let luaEngine = null;
let outputElement = null;
let configEditor = null;
let sandboxedEditor = null;

// Initialize the playground
async function initPlayground() {
    outputElement = document.getElementById('output');
    configEditor = document.getElementById('config-editor');
    sandboxedEditor = document.getElementById('sandboxed-editor');

    // Set up event listeners
    document.getElementById('run-btn').addEventListener('click', runPlayground);
    document.getElementById('clear-btn').addEventListener('click', clearOutput);

    // Initialize Lua engine
    try {
        const { LuaFactory } = window.wasmoon;
        const factory = new LuaFactory();
        luaEngine = await factory.createEngine();
        
        addOutput('✓ Playground initialized and ready!', 'success');
    } catch (error) {
        addOutput('✗ Failed to initialize Lua engine: ' + error.message, 'error');
        console.error('Initialization error:', error);
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

// Create custom print function
function createPrintFunction() {
    return (...args) => {
        const message = args.map(arg => {
            if (typeof arg === 'object' && arg !== null) {
                return JSON.stringify(arg);
            }
            return String(arg);
        }).join('\t');
        addOutput(message, 'normal');
    };
}

// Create custom warn function
function createWarnFunction() {
    return (...args) => {
        const message = args.map(arg => String(arg)).join('\t');
        addOutput(message, 'warning');
    };
}

// Create dummy Roblox Instance
function createDummyInstance(className, name) {
    return {
        ClassName: className,
        Name: name || className,
        Parent: null,
        
        IsA: function(checkClass) {
            return this.ClassName === checkClass;
        },
        
        GetFullName: function() {
            let path = [this.Name];
            let current = this.Parent;
            while (current) {
                path.unshift(current.Name);
                current = current.Parent;
            }
            return path.join('.');
        },
        
        FindFirstChild: function(childName, recursive) {
            return null; // No children in dummy implementation
        },
        
        GetChildren: function() {
            return [];
        },
        
        toString: function() {
            return this.Name;
        }
    };
}

// Create dummy Vector3
function createVector3(x, y, z) {
    return {
        X: x || 0,
        Y: y || 0,
        Z: z || 0,
        x: x || 0,
        y: y || 0,
        z: z || 0,
        
        __add: function(other) {
            return createVector3(this.X + other.X, this.Y + other.Y, this.Z + other.Z);
        },
        
        __sub: function(other) {
            return createVector3(this.X - other.X, this.Y - other.Y, this.Z - other.Z);
        },
        
        __mul: function(scalar) {
            return createVector3(this.X * scalar, this.Y * scalar, this.Z * scalar);
        },
        
        toString: function() {
            return `${this.X}, ${this.Y}, ${this.Z}`;
        }
    };
}

// Create dummy Color3
function createColor3(r, g, b) {
    return {
        R: r || 0,
        G: g || 0,
        B: b || 0,
        r: r || 0,
        g: g || 0,
        b: b || 0,
        
        toString: function() {
            return `${this.R}, ${this.G}, ${this.B}`;
        }
    };
}

// Set up Roblox globals in Lua environment
async function setupRobloxGlobals() {
    try {
        // Set up game
        const game = createDummyInstance('DataModel', 'game');
        luaEngine.global.set('game', game);
        luaEngine.global.set('Game', game);
        
        // Set up workspace
        const workspace = createDummyInstance('Workspace', 'Workspace');
        luaEngine.global.set('workspace', workspace);
        luaEngine.global.set('Workspace', workspace);
        
        // Set up script
        const script = createDummyInstance('Script', 'Script');
        luaEngine.global.set('script', script);
        
        // Set up Instance library
        const Instance = {
            new: function(className, parent) {
                const inst = createDummyInstance(className);
                if (parent) {
                    inst.Parent = parent;
                }
                return inst;
            }
        };
        luaEngine.global.set('Instance', Instance);
        
        // Set up Vector3
        const Vector3 = {
            new: function(x, y, z) {
                return createVector3(x, y, z);
            }
        };
        luaEngine.global.set('Vector3', Vector3);
        
        // Set up Color3
        const Color3 = {
            new: function(r, g, b) {
                return createColor3(r, g, b);
            },
            fromRGB: function(r, g, b) {
                return createColor3(r / 255, g / 255, b / 255);
            }
        };
        luaEngine.global.set('Color3', Color3);
        
        // Set up CFrame
        const CFrame = {
            new: function(x, y, z) {
                return {
                    X: x || 0,
                    Y: y || 0,
                    Z: z || 0,
                    Position: createVector3(x, y, z),
                    toString: function() {
                        return `${this.X}, ${this.Y}, ${this.Z}`;
                    }
                };
            }
        };
        luaEngine.global.set('CFrame', CFrame);
        
        // Set up UDim2
        const UDim2 = {
            new: function(xScale, xOffset, yScale, yOffset) {
                return {
                    X: { Scale: xScale || 0, Offset: xOffset || 0 },
                    Y: { Scale: yScale || 0, Offset: yOffset || 0 },
                    toString: function() {
                        return `{${this.X.Scale}, ${this.X.Offset}}, {${this.Y.Scale}, ${this.Y.Offset}}`;
                    }
                };
            }
        };
        luaEngine.global.set('UDim2', UDim2);
        
        // Set up basic Enum
        const Enum = {
            Material: {
                Plastic: 256,
                Wood: 512,
                Concrete: 816,
                Metal: 1088
            },
            PartType: {
                Ball: 0,
                Block: 1,
                Cylinder: 2
            }
        };
        luaEngine.global.set('Enum', Enum);
        
    } catch (error) {
        addOutput('Error setting up Roblox globals: ' + error.message, 'error');
        console.error('Setup error:', error);
    }
}

// Set up sandbox environment
async function setupSandboxGlobals() {
    try {
        // Override print
        luaEngine.global.set('print', createPrintFunction());
        luaEngine.global.set('warn', createWarnFunction());
        
        // Create sandboxed _G and shared
        const sharedTable = {};
        luaEngine.global.set('_G', sharedTable);
        luaEngine.global.set('shared', sharedTable);
        
        // Remove dangerous functions
        luaEngine.global.set('loadstring', null);
        luaEngine.global.set('dofile', null);
        luaEngine.global.set('loadfile', null);
        
    } catch (error) {
        addOutput('Error setting up sandbox: ' + error.message, 'error');
        console.error('Setup error:', error);
    }
}

// Run the playground
async function runPlayground() {
    if (!luaEngine) {
        addOutput('✗ Lua engine not initialized', 'error');
        return;
    }

    clearOutput();
    addOutput('=== Luau Sandboxer Playground ===', 'info');
    addOutput('', 'normal');
    
    const configScript = configEditor.value;
    const sandboxedScript = sandboxedEditor.value;
    
    try {
        // Step 1: Execute configuration script
        addOutput('Loading configuration script...', 'info');
        await luaEngine.doString(configScript);
        
        // Step 2: Set up sandbox environment
        addOutput('Setting up sandbox environment...', 'info');
        await setupSandboxGlobals();
        
        // Step 3: Check if Roblox globals should be added
        const useRobloxGlobals = luaEngine.global.get('USE_ROBLOX_GLOBALS');
        if (useRobloxGlobals) {
            addOutput('Adding dummy Roblox globals...', 'info');
            await setupRobloxGlobals();
        }
        
        // Step 4: Apply custom sandbox configuration
        const sandboxConfig = luaEngine.global.get('SANDBOX_CONFIG');
        if (sandboxConfig && typeof sandboxConfig === 'object') {
            for (const [key, value] of Object.entries(sandboxConfig)) {
                luaEngine.global.set(key, value);
            }
        }
        
        addOutput('Running sandboxed script...', 'info');
        addOutput('', 'normal');
        addOutput('--- Output ---', 'info');
        
        // Step 5: Execute sandboxed script
        await luaEngine.doString(sandboxedScript);
        
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

// Initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initPlayground);
} else {
    initPlayground();
}
