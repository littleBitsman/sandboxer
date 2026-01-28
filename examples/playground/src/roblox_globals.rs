use mlua::{Lua, Result, Table, UserData, UserDataMethods, MetaMethod, Function, Value};

/// A dummy Instance userdata that mimics basic Roblox Instance behavior
#[derive(Clone)]
pub struct DummyInstance {
    name: String,
    class_name: String,
    parent: Option<Box<DummyInstance>>,
}

impl DummyInstance {
    fn new(class_name: String, name: Option<String>) -> Self {
        Self {
            name: name.unwrap_or_else(|| class_name.clone()),
            class_name,
            parent: None,
        }
    }
}

impl UserData for DummyInstance {
    fn add_methods<'lua, M: UserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_method("IsA", |_, this, class_name: String| {
            Ok(this.class_name == class_name)
        });

        methods.add_method("GetFullName", |_, this, ()| {
            let mut path = vec![this.name.clone()];
            let mut current = &this.parent;
            while let Some(parent) = current {
                path.insert(0, parent.name.clone());
                current = &parent.parent;
            }
            Ok(path.join("."))
        });

        methods.add_method("FindFirstChild", |_, _this, (_name, _recursive): (String, Option<bool>)| {
            // Return nil - no children in dummy implementation
            Ok(Value::Nil)
        });

        methods.add_method("GetChildren", |lua, _this, ()| {
            // Return empty table
            lua.create_table()
        });

        methods.add_field_method_get("Name", |_, this| Ok(this.name.clone()));
        methods.add_field_method_get("ClassName", |_, this| Ok(this.class_name.clone()));

        methods.add_meta_method(MetaMethod::ToString, |_, this, ()| {
            Ok(this.name.clone())
        });
    }
}

/// Set up dummy Roblox globals in the sandbox environment
pub fn setup_roblox_globals(lua: &Lua, env: &Table) -> Result<()> {
    // Create dummy game
    let game = DummyInstance::new("DataModel".to_string(), Some("game".to_string()));
    env.set("game", game.clone())?;
    env.set("Game", game)?;

    // Create dummy workspace
    let workspace = DummyInstance::new("Workspace".to_string(), Some("Workspace".to_string()));
    env.set("workspace", workspace.clone())?;
    env.set("Workspace", workspace)?;

    // Create dummy script
    let script = DummyInstance::new("Script".to_string(), Some("Script".to_string()));
    env.set("script", script)?;

    // Create dummy Instance library
    let instance_lib = lua.create_table()?;
    
    instance_lib.set("new", lua.create_function(|_, (class_name, parent): (String, Option<Value>)| {
        let mut instance = DummyInstance::new(class_name.clone(), None);
        
        // Set parent if provided
        if let Some(Value::UserData(parent_ud)) = parent {
            if let Ok(parent_inst) = parent_ud.borrow::<DummyInstance>() {
                instance.parent = Some(Box::new(parent_inst.clone()));
            }
        }
        
        Ok(instance)
    })?)?;

    env.set("Instance", instance_lib)?;

    // Add dummy data types
    add_dummy_vector3(lua, env)?;
    add_dummy_cframe(lua, env)?;
    add_dummy_color3(lua, env)?;
    add_dummy_udim2(lua, env)?;

    // Add dummy Enum
    add_dummy_enum(lua, env)?;

    Ok(())
}

/// Dummy Vector3 implementation
#[derive(Clone, Copy)]
struct DummyVector3 {
    x: f64,
    y: f64,
    z: f64,
}

impl UserData for DummyVector3 {
    fn add_methods<'lua, M: UserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_field_method_get("X", |_, this| Ok(this.x));
        methods.add_field_method_get("x", |_, this| Ok(this.x));
        methods.add_field_method_get("Y", |_, this| Ok(this.y));
        methods.add_field_method_get("y", |_, this| Ok(this.y));
        methods.add_field_method_get("Z", |_, this| Ok(this.z));
        methods.add_field_method_get("z", |_, this| Ok(this.z));

        methods.add_meta_method(MetaMethod::ToString, |_, this, ()| {
            Ok(format!("{}, {}, {}", this.x, this.y, this.z))
        });

        methods.add_meta_method(MetaMethod::Add, |_, this, other: DummyVector3| {
            Ok(DummyVector3 {
                x: this.x + other.x,
                y: this.y + other.y,
                z: this.z + other.z,
            })
        });

        methods.add_meta_method(MetaMethod::Sub, |_, this, other: DummyVector3| {
            Ok(DummyVector3 {
                x: this.x - other.x,
                y: this.y - other.y,
                z: this.z - other.z,
            })
        });

        methods.add_meta_method(MetaMethod::Mul, |_, this, scalar: f64| {
            Ok(DummyVector3 {
                x: this.x * scalar,
                y: this.y * scalar,
                z: this.z * scalar,
            })
        });
    }
}

fn add_dummy_vector3(lua: &Lua, env: &Table) -> Result<()> {
    let vector3_lib = lua.create_table()?;
    vector3_lib.set("new", lua.create_function(|_, (x, y, z): (f64, f64, f64)| {
        Ok(DummyVector3 { x, y, z })
    })?)?;
    env.set("Vector3", vector3_lib)?;
    Ok(())
}

/// Dummy CFrame implementation
#[derive(Clone, Copy)]
struct DummyCFrame {
    x: f64,
    y: f64,
    z: f64,
}

impl UserData for DummyCFrame {
    fn add_methods<'lua, M: UserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_meta_method(MetaMethod::Index, |_, this, key: String| {
            match key.as_str() {
                "X" | "x" => Ok(Value::Number(this.x)),
                "Y" | "y" => Ok(Value::Number(this.y)),
                "Z" | "z" => Ok(Value::Number(this.z)),
                "Position" | "position" => Ok(Value::UserData(DummyVector3 { 
                    x: this.x, 
                    y: this.y, 
                    z: this.z 
                })),
                _ => Ok(Value::Nil),
            }
        });

        methods.add_meta_method(MetaMethod::ToString, |_, this, ()| {
            Ok(format!("{}, {}, {}", this.x, this.y, this.z))
        });

        methods.add_meta_method(MetaMethod::Mul, |_, this, other: DummyCFrame| {
            Ok(DummyCFrame {
                x: this.x + other.x,
                y: this.y + other.y,
                z: this.z + other.z,
            })
        });
    }
}

fn add_dummy_cframe(lua: &Lua, env: &Table) -> Result<()> {
    let cframe_lib = lua.create_table()?;
    cframe_lib.set("new", lua.create_function(|_, (x, y, z): (Option<f64>, Option<f64>, Option<f64>)| {
        Ok(DummyCFrame { 
            x: x.unwrap_or(0.0), 
            y: y.unwrap_or(0.0), 
            z: z.unwrap_or(0.0) 
        })
    })?)?;
    env.set("CFrame", cframe_lib)?;
    Ok(())
}

/// Dummy Color3 implementation
#[derive(Clone, Copy)]
struct DummyColor3 {
    r: f64,
    g: f64,
    b: f64,
}

impl UserData for DummyColor3 {
    fn add_methods<'lua, M: UserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_meta_method(MetaMethod::Index, |_, this, key: String| {
            match key.as_str() {
                "R" | "r" => Ok(Value::Number(this.r)),
                "G" | "g" => Ok(Value::Number(this.g)),
                "B" | "b" => Ok(Value::Number(this.b)),
                _ => Ok(Value::Nil),
            }
        });

        methods.add_meta_method(MetaMethod::ToString, |_, this, ()| {
            Ok(format!("{}, {}, {}", this.r, this.g, this.b))
        });
    }
}

fn add_dummy_color3(lua: &Lua, env: &Table) -> Result<()> {
    let color3_lib = lua.create_table()?;
    color3_lib.set("new", lua.create_function(|_, (r, g, b): (f64, f64, f64)| {
        Ok(DummyColor3 { r, g, b })
    })?)?;
    color3_lib.set("fromRGB", lua.create_function(|_, (r, g, b): (f64, f64, f64)| {
        Ok(DummyColor3 { 
            r: r / 255.0, 
            g: g / 255.0, 
            b: b / 255.0 
        })
    })?)?;
    env.set("Color3", color3_lib)?;
    Ok(())
}

/// Dummy UDim2 implementation
#[derive(Clone, Copy)]
struct DummyUDim2 {
    x_scale: f64,
    x_offset: f64,
    y_scale: f64,
    y_offset: f64,
}

impl UserData for DummyUDim2 {
    fn add_methods<'lua, M: UserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_meta_method(MetaMethod::ToString, |_, this, ()| {
            Ok(format!("{{{}, {}}}, {{{}, {}}}", 
                this.x_scale, this.x_offset, 
                this.y_scale, this.y_offset))
        });
    }
}

fn add_dummy_udim2(lua: &Lua, env: &Table) -> Result<()> {
    let udim2_lib = lua.create_table()?;
    udim2_lib.set("new", lua.create_function(|_, (x_scale, x_offset, y_scale, y_offset): (f64, f64, f64, f64)| {
        Ok(DummyUDim2 { x_scale, x_offset, y_scale, y_offset })
    })?)?;
    env.set("UDim2", udim2_lib)?;
    Ok(())
}

/// Dummy Enum implementation
fn add_dummy_enum(lua: &Lua, env: &Table) -> Result<()> {
    let enum_table = lua.create_table()?;
    
    // Add some common enum categories
    let material = lua.create_table()?;
    material.set("Plastic", 256)?;
    material.set("Wood", 512)?;
    material.set("Concrete", 816)?;
    material.set("Metal", 1088)?;
    enum_table.set("Material", material)?;

    let part_type = lua.create_table()?;
    part_type.set("Ball", 0)?;
    part_type.set("Block", 1)?;
    part_type.set("Cylinder", 2)?;
    enum_table.set("PartType", part_type)?;

    env.set("Enum", enum_table)?;
    Ok(())
}
