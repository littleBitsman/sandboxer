use std::fs::{File, read_to_string};

use rbx_binary::to_writer;
use rbx_dom_weak::{InstanceBuilder, WeakDom};

fn module_script_with_source(name: &str, source: String) -> InstanceBuilder {
    InstanceBuilder::new("ModuleScript")
        .with_name(name)
        .with_property("Source", source)
}

fn main() {
    println!("{:?}", std::fs::read_dir("../").unwrap().collect::<Vec<_>>());
    println!("{:?}", std::fs::read_dir("./").unwrap().collect::<Vec<_>>());
    println!("{:?}", std::fs::read_dir("./src").unwrap().collect::<Vec<_>>());

    let license = {
        let license = read_to_string("LICENSE").expect("Failed to read LICENSE file");
        let mut final_license = String::with_capacity(license.len() + 80);
        final_license.push_str("--[[\n");
        final_license.push_str(&license);
        final_license.push_str("\n--]]\n\n");
        final_license.push_str("script:Destroy()\n");
        final_license.push_str("return error(\"This is a LICENSE file (AGPL v3.0)\")");
        final_license
    };

    let sandboxer_source =
        read_to_string("src/Sandboxer.lua").expect("Failed to read Sandboxer.lua");

    let instance_source = read_to_string("src/Instance.lua").expect("Failed to read Instance.lua");

    let instancelist_source =
        read_to_string("src/InstanceList.lua").expect("Failed to read InstanceList.lua");

    let instancesandboxer_source =
        read_to_string("src/InstanceSandboxer.lua").expect("Failed to read InstanceSandboxer.lua");

    let dom = WeakDom::new(
        InstanceBuilder::new("ModuleScript")
            .with_name("Sandboxer")
            .with_property("Source", sandboxer_source)
            .with_children([
                module_script_with_source("Instance", instance_source),
                module_script_with_source("InstanceList", instancelist_source),
                module_script_with_source("InstanceSandboxer", instancesandboxer_source),
                module_script_with_source("LICENSE", license),
            ])
    );

    let file = File::create("Sandboxer.rbxm").expect("Failed to open Sandboxer.rbxm");

    to_writer(&file, &dom, &[dom.root_ref()]).expect("Failed to write Sandboxer.rbxm");

    eprintln!("Successfully created Sandboxer.rbxm");
}
