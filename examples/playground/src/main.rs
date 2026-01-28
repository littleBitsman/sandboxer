use mlua::{Lua, Result, Table, UserData, UserDataMethods, Value, Function};
use std::fs;

mod roblox_globals;

fn main() -> Result<()> {
    let lua = Lua::new();

    // Read the sandbox configuration script
    let config_script = fs::read_to_string("examples/playground/scripts/config.luau")
        .unwrap_or_else(|_| {
            println!("Warning: config.luau not found, using default configuration");
            String::from("-- Default configuration")
        });

    // Read the sandboxed script
    let sandboxed_script = fs::read_to_string("examples/playground/scripts/sandboxed.luau")
        .unwrap_or_else(|_| {
            println!("Warning: sandboxed.luau not found, using default script");
            String::from("print('Hello from sandboxed script!')")
        });

    println!("=== Luau Sandboxer Playground ===\n");
    println!("Loading configuration script...");
    
    // Set up the configuration environment
    lua.load(&config_script).exec()?;

    println!("Setting up sandbox environment...");
    
    // Create a sandboxed environment
    let sandbox_env = lua.create_table()?;
    
    // Add standard Luau globals to sandbox
    setup_sandbox_globals(&lua, &sandbox_env)?;
    
    // Optionally add dummy Roblox globals if requested
    let use_roblox_globals = lua.globals().get::<_, bool>("USE_ROBLOX_GLOBALS")
        .unwrap_or(false);
    
    if use_roblox_globals {
        println!("Adding dummy Roblox globals...");
        roblox_globals::setup_roblox_globals(&lua, &sandbox_env)?;
    }

    // Get custom sandbox configuration from the config script
    if let Ok(custom_config) = lua.globals().get::<_, Table>("SANDBOX_CONFIG") {
        for pair in custom_config.pairs::<Value, Value>() {
            let (key, value) = pair?;
            sandbox_env.set(key, value)?;
        }
    }

    println!("Running sandboxed script...\n");
    println!("--- Output ---");
    
    // Execute the sandboxed script in the sandbox environment
    let sandboxed_fn: Function = lua.load(&sandboxed_script)
        .set_environment(sandbox_env)
        .into_function()?;
    
    match sandboxed_fn.call::<_, ()>(()) {
        Ok(_) => {
            println!("\n--- End Output ---");
            println!("\n✓ Script executed successfully");
        }
        Err(e) => {
            println!("\n--- End Output ---");
            println!("\n✗ Script execution failed: {}", e);
        }
    }

    Ok(())
}

fn setup_sandbox_globals(lua: &Lua, env: &Table) -> Result<()> {
    // Add standard Luau functions
    env.set("print", lua.globals().get::<_, Function>("print")?)?;
    env.set("warn", lua.globals().get::<_, Function>("warn")?)?;
    env.set("error", lua.globals().get::<_, Function>("error")?)?;
    env.set("assert", lua.globals().get::<_, Function>("assert")?)?;
    env.set("type", lua.globals().get::<_, Function>("type")?)?;
    env.set("typeof", lua.globals().get::<_, Function>("typeof")?)?;
    env.set("tonumber", lua.globals().get::<_, Function>("tonumber")?)?;
    env.set("tostring", lua.globals().get::<_, Function>("tostring")?)?;
    env.set("select", lua.globals().get::<_, Function>("select")?)?;
    env.set("pcall", lua.globals().get::<_, Function>("pcall")?)?;
    env.set("ipairs", lua.globals().get::<_, Function>("ipairs")?)?;
    env.set("pairs", lua.globals().get::<_, Function>("pairs")?)?;
    env.set("next", lua.globals().get::<_, Function>("next")?)?;
    env.set("rawget", lua.globals().get::<_, Function>("rawget")?)?;
    env.set("rawset", lua.globals().get::<_, Function>("rawset")?)?;
    env.set("rawequal", lua.globals().get::<_, Function>("rawequal")?)?;
    env.set("setmetatable", lua.globals().get::<_, Function>("setmetatable")?)?;
    env.set("getmetatable", lua.globals().get::<_, Function>("getmetatable")?)?;
    
    // Add standard libraries
    env.set("math", lua.globals().get::<_, Table>("math")?)?;
    env.set("string", lua.globals().get::<_, Table>("string")?)?;
    env.set("table", lua.globals().get::<_, Table>("table")?)?;
    env.set("bit32", lua.globals().get::<_, Table>("bit32")?)?;
    env.set("utf8", lua.globals().get::<_, Table>("utf8")?)?;
    
    // Create sandboxed _G and shared
    let self_g = lua.create_table()?;
    env.set("_G", self_g.clone())?;
    env.set("shared", self_g)?;
    
    Ok(())
}
