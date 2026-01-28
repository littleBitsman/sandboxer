# Luau Sandboxer Playground

This playground allows you to test the sandboxer by providing two separate scripts:

1. **Configuration Script** (`scripts/config.luau`): Configures the sandbox environment
2. **Sandboxed Script** (`scripts/sandboxed.luau`): The script that runs inside the sandbox

## Features

- **Luau Semantics**: Uses the Luau language with its full syntax and features
- **Configurable Sandbox**: Customize the sandbox environment through the configuration script
- **Dummy Roblox Globals**: Optional dummy implementations of common Roblox globals (game, workspace, Instance, Vector3, Color3, CFrame, etc.)
- **Safe Execution**: Scripts run in a controlled environment with limited access to dangerous functions
- **Web-Based**: Interactive web playground that can be embedded in documentation or websites
- **Command-Line**: Rust-based CLI version for local testing

## Web Playground (Recommended)

The web-based playground runs directly in your browser with no installation required.

### Running Locally

```bash
# Serve the web directory with any HTTP server
cd examples/playground/web

# Using Python
python3 -m http.server 8000

# Using Node.js http-server
npx http-server -p 8000

# Then open http://localhost:8000 in your browser
```

### Embedding in Websites

The playground can be embedded in any webpage using an iframe:

```html
<iframe 
    src="https://yourdomain.com/playground/embed.html" 
    width="100%" 
    height="800px" 
    frameborder="0"
    title="Luau Sandboxer Playground">
</iframe>
```

**Files:**
- `index.html` - Full standalone playground page
- `embed.html` - Embeddable version (no header/footer)
- `styles.css` - Styling for both versions
- `playground.js` - Core playground logic

### Technology Stack

- **wasmoon** - Lua 5.4 compiled to WebAssembly with Luau support
- **Vanilla JavaScript** - No frameworks, lightweight and fast
- **Responsive CSS** - Works on desktop, tablet, and mobile

## CLI Playground

## CLI Playground

The Rust-based CLI version for local development and testing.

### Prerequisites

- Rust (latest stable version)
- Cargo

### Running the Playground

```bash
# From the repository root
cd examples/playground
cargo run
```

### Customizing Scripts

#### Configuration Script (`scripts/config.luau`)

This script runs first and sets up the sandbox environment. You can:

- Enable/disable dummy Roblox globals by setting `USE_ROBLOX_GLOBALS`
- Add custom functions and values via `SANDBOX_CONFIG` table
- Configure any sandbox behavior

Example:
```lua
-- Enable Roblox globals
USE_ROBLOX_GLOBALS = true

-- Add custom configuration
SANDBOX_CONFIG = {
    customFunction = function(msg)
        print("[Custom]", msg)
    end,
    customValue = 42,
}
```

#### Sandboxed Script (`scripts/sandboxed.luau`)

This is the script that runs inside the sandbox. It has access to:

- Standard Luau libraries (math, string, table, etc.)
- Standard Luau functions (print, warn, error, pcall, etc.)
- Custom globals defined in `SANDBOX_CONFIG`
- Dummy Roblox globals (if `USE_ROBLOX_GLOBALS` is true)
- Sandboxed `_G` and `shared` tables

The script does NOT have access to:
- `getfenv` / `setfenv`
- `loadstring`
- `debug` library
- Real Roblox game engine functionality

Example:
```lua
-- Basic Luau
local x = 5
print("x =", x)

-- Standard libraries
print("sqrt(16) =", math.sqrt(16))

-- Custom globals (if defined in config)
if customFunction then
    customFunction("Hello!")
end

-- Roblox globals (if enabled)
if Instance then
    local part = Instance.new("Part")
    print("Created:", part)
end
```

## Dummy Roblox Globals

When `USE_ROBLOX_GLOBALS` is enabled, the following dummy implementations are available:

### Objects
- `game` - Dummy DataModel instance
- `workspace` - Dummy Workspace instance  
- `script` - Dummy Script instance

### Data Types
- `Instance` - Create dummy instances with `Instance.new(className)`
- `Vector3` - 3D vector with basic math operations
- `CFrame` - Coordinate frame (simplified)
- `Color3` - RGB color with `Color3.new()` and `Color3.fromRGB()`
- `UDim2` - 2D dimension (simplified)
- `Enum` - Basic enum tables

### Limitations

These are **dummy implementations** that:
- Return basic userdata with minimal functionality
- Have no effect on any game engine (since there isn't one)
- Work similarly to Roblox objects but with simplified behavior
- Are intended for testing sandbox behavior, not for production use

## Examples

### Example 1: Basic Sandbox Test

**config.luau:**
```lua
USE_ROBLOX_GLOBALS = false

SANDBOX_CONFIG = {
    MAX_ITERATIONS = 1000,
}
```

**sandboxed.luau:**
```lua
for i = 1, MAX_ITERATIONS do
    if i % 100 == 0 then
        print("Iteration", i)
    end
end
```

### Example 2: Testing Roblox Globals

**config.luau:**
```lua
USE_ROBLOX_GLOBALS = true

SANDBOX_CONFIG = {}
```

**sandboxed.luau:**
```lua
local part = Instance.new("Part")
part.Name = "TestPart"
print("Created part:", part)

local v = Vector3.new(1, 2, 3)
print("Vector:", v)
```

### Example 3: Custom Sandbox Environment

**config.luau:**
```lua
USE_ROBLOX_GLOBALS = true

SANDBOX_CONFIG = {
    safeRequire = function(moduleName)
        print("Attempting to require:", moduleName)
        return nil
    end,
    
    limitedPrint = function(...)
        print("[LIMITED]", ...)
    end,
}
```

**sandboxed.luau:**
```lua
limitedPrint("This uses custom print")

local module = safeRequire("MyModule")
```

## Architecture

The playground is built with:
- **Rust** - Host application
- **mlua** - Lua/Luau bindings for Rust with Luau support
- **Dummy Userdata** - Rust implementations of Roblox types using mlua's UserData trait

## Development

### Building

```bash
cargo build
```

### Running

```bash
cargo run
```

### Adding New Dummy Globals

To add new dummy Roblox globals:

1. Implement the type as a Rust struct in `src/roblox_globals.rs`
2. Implement the `UserData` trait with appropriate methods
3. Add setup function to expose it in `setup_roblox_globals()`

Example:
```rust
#[derive(Clone)]
struct DummyNewType {
    value: String,
}

impl UserData for DummyNewType {
    fn add_methods<'lua, M: UserDataMethods<'lua, Self>>(methods: &mut M) {
        // Add methods here
    }
}
```

## License

This example is part of the Sandboxer project and is licensed under the GNU Affero General Public License v3.0 or later.

## Contributing

Feel free to extend this playground with additional features, dummy implementations, or example scripts!
