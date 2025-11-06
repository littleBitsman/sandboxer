use std::{env::var as env, time::Duration, thread::sleep, fs::{read_dir, read_to_string}};

use rbx_binary::to_writer;
use rbx_dom_weak::{InstanceBuilder, WeakDom};

use reqwest::blocking::*;

const SCRIPT: &str = include_str!("main.luau");

macro_rules! unwrap {
    (unsafe $expr:expr) => {
        unsafe { $expr.unwrap_unchecked() }
    };
}

fn module_script_with_source(name: &str, source: String) -> InstanceBuilder {
    InstanceBuilder::with_property_capacity("ModuleScript", 1)
        .with_name(name)
        .with_property("Source", source)
}

#[expect(non_snake_case)]
#[derive(serde::Deserialize)]
struct LuauExecutionBinaryInputResponse {
    path: String,
    #[expect(unused)]
    size: usize,
    uploadUri: String,
}

#[derive(serde::Serialize)]
#[expect(non_snake_case)]
struct LuauExecutionTaskRequest {
    script: &'static str,
    binaryInput: String,
    enableBinaryOutput: bool
}

#[derive(serde::Deserialize)]
#[expect(unused)]
struct LuauExecutionTaskError {
    code: String,
    message: String,
}

#[derive(serde::Deserialize)]
#[repr(transparent)]
struct LuauExecutionTaskOutput {
    results: Vec<String>
}

#[derive(serde::Deserialize)]
#[expect(non_snake_case, unused)]
struct LuauExecutionTaskResponse {
    path: String,
    createTime: String,
    updateTime: String,
    user: String,
    state: String,
    script: String,
    timeout: String,
    error: Option<LuauExecutionTaskError>,
    output: Option<LuauExecutionTaskOutput>,
    binaryInput: String,
    enableBinaryOutput: bool,
    binaryOutputUri: Option<String>,
}

fn main() {
    let api_key = env("ROBLOX_API_KEY").expect("Missing API key");

    let init_source = read_to_string("./test/init.luau").expect("Failed to read init.luau");
    let testframework_source =
        read_to_string("./test/TestFramework.luau").expect("Failed to read TestFramework.luau");

    let tests = read_dir("./test/tests")
        .expect("Failed to read tests directory")
        .filter_map(|entry| {
            let entry = entry.expect("Failed to read test file entry");
            let path = entry.path();
            if path.extension().and_then(|s| s.to_str()) != Some("luau") {
                return None;
            }
            Some(module_script_with_source(
                unwrap!(unsafe path.file_name())
                    .to_string_lossy()
                    .replace(".luau", "")
                    .as_str(),
                read_to_string(&path)
                    .unwrap_or_else(|_| panic!("Failed to read {}", path.display())),
            ))
        });

    let dom = WeakDom::new(
        InstanceBuilder::with_property_capacity("ModuleScript", 1)
            .with_name("RunTests")
            .with_property("Source", init_source)
            .with_children([
                module_script_with_source("TestFramework", testframework_source),
                InstanceBuilder::new("Folder")
                    .with_name("tests")
                    .with_children(tests),
            ]),
    );

    let mut buf = Vec::new();
    to_writer(&mut buf, &dom, &[dom.root_ref()]).expect("Failed to compile rbxm file");

    let cli = Client::new();
    
    eprintln!("Uploading test binary ({} bytes)...", buf.len());
    let binput = cli.post("https://apis.roblox.com/cloud/v2/universes/8382727792/luau-execution-session-task-binary-inputs")
        .header("X-Api-Key", &api_key)
        .body(format!("{{\"size\": {}}}", buf.len()))
        .send()
        .expect("Create binary input request failed")
        .error_for_status()
        .expect("Error while creating Luau execution binary input")
        .json::<LuauExecutionBinaryInputResponse>()
        .expect("Failed to parse response");

    cli.put(&binput.uploadUri)
        .body(buf)
        .send()
        .expect("Failed to upload binary input")
        .error_for_status()
        .expect("Upload request failed");

    eprintln!("Successfully uploaded test binary");

    let response = cli.post("https://apis.roblox.com/cloud/v2/universes/8382727792/places/122953816609099/luau-execution-session-tasks")
        .header("X-Api-Key", &api_key)
        .json(&LuauExecutionTaskRequest {
            script: SCRIPT,
            binaryInput: binput.path,
            enableBinaryOutput: true
        })
        .send()
        .expect("Luau execution session request failed")
        .error_for_status()
        .expect("Error while spawning Luau execution session")
        .json::<LuauExecutionTaskResponse>()
        .expect("Failed to parse response");

    let id = response.path;
    let state_req = cli.get(format!("https://apis.roblox.com/cloud/v2/{id}"))
        .header("X-Api-Key", &api_key);

    let mut delay = Duration::from_secs(1);
    let response = loop {
        let resp = unwrap!(unsafe state_req.try_clone())
            .send()
            .expect("Luau execution session state request failed")
            .error_for_status()
            .expect("Error while checking Luau execution session state")
            .json::<LuauExecutionTaskResponse>()
            .expect("Failed to parse response");

        match resp.state.as_str() {
            "COMPLETE" => break resp,
            "FAILED" => {
                if let Some(err) = resp.error {
                    panic!("Luau execution session failed: {}", err.message);
                }
            }
            state => eprintln!("Current state: {state}. Waiting {} seconds before retrying...", delay.as_secs()),
        }

        sleep(delay);
        delay *= 2;
    };

    
}
