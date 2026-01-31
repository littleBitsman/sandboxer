use std::{
    env::var as env,
    fs::{self, read_dir, read_to_string},
    panic::{PanicHookInfo, set_hook as set_panic_hook},
    process,
    thread::sleep,
    time::Duration,
};

mod json;
use json::*;

#[macro_use]
mod macros;

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

fn panic_hook(info: &PanicHookInfo) {
    fatal!("{}", info.payload_as_str().unwrap_or("explicit panic"));
    if let Some(location) = info.location() {
        debug!("panicked at {location}");
    }
}

fn main() {
    set_panic_hook(Box::new(panic_hook));

    let mut latest_rbxm = rbx_binary::from_reader(fs::File::open("Sandboxer.rbxm").unwrap()).unwrap();

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
                // SAFETY: we know this is a file
                unwrap!(unsafe path.file_name())
                    .to_string_lossy()
                    .replace(".luau", "")
                    .as_str(),
                read_to_string(&path)
                    .unwrap_or_else(|_| panic!("Failed to read {}", path.display())),
            ))
        });

    let mut dom = WeakDom::new(
        InstanceBuilder::new("Model")
            .with_name("Sandboxer-Tests")
            .with_child(
                InstanceBuilder::with_property_capacity("ModuleScript", 1)
                    .with_name("RunTests")
                    .with_property("Source", init_source)
                    .with_children([
                        module_script_with_source("TestFramework", testframework_source),
                        InstanceBuilder::new("Folder")
                            .with_name("tests")
                            .with_children(tests),
                    ]),
            ),
    );
    let root = dom.root_ref();
    latest_rbxm.transfer(latest_rbxm.root().children()[0], &mut dom, root);
    drop(latest_rbxm);

    let mut buf = Vec::new();
    rbx_binary::to_writer(&mut buf, &dom, &[root]).expect("Failed to compile rbxm file");

    match fs::write("test.rbxm", &buf) {
        Ok(()) => info!("Wrote test.rbxm ({} bytes)", buf.len()),
        Err(e) => {
            warn!("Failed to write test.rbxm; artifact will not upload to GitHub");
            warn!("Error: {e}");
        }
    }

    let api_key = env("ROBLOX_API_KEY").expect("Missing API key");

    let cli = Client::new();

    info!("Uploading test binary ({} bytes)...", buf.len());
    let binput = cli.post("https://apis.roblox.com/cloud/v2/universes/8382727792/luau-execution-session-task-binary-inputs")
        .header("X-Api-Key", &api_key)
        .json(&LuauExecutionBinaryInputRequest { size: buf.len() })
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

    info!("Successfully uploaded test binary");

    let response = cli.post("https://apis.roblox.com/cloud/v2/universes/8382727792/places/122953816609099/luau-execution-session-tasks")
        .header("X-Api-Key", &api_key)
        .json(&LuauExecutionTaskRequest {
            script: SCRIPT,
            timeout: "10s",
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

    debug!("Luau execution session started with ID: {}", id);

    let state_req = cli
        .get(format!("https://apis.roblox.com/cloud/v2/{id}"))
        .header("X-Api-Key", &api_key);

    let mut delay = Duration::from_secs(1);
    let result = loop {
        let resp = unwrap!(unsafe state_req.try_clone())
            .send()
            .expect("Luau execution session state request failed")
            .error_for_status()
            .expect("Error while checking Luau execution session state")
            .json::<LuauExecutionTaskResponse>()
            .expect("Failed to parse response");

        match resp.state {
            LuauExecutionTaskState::Complete | LuauExecutionTaskState::Failed => break resp,
            state => info!(
                "Current state: {state:?}. Waiting {} seconds before polling again...",
                delay.as_secs()
            ),
        }

        sleep(delay);
        delay *= 2;
    };

    let mut page_token = String::with_capacity(24);

    info!("------- Luau Output -------");
    loop {
        let logs_resp = cli
            .get(format!(
                "https://apis.roblox.com/cloud/v2/{}/logs?view=STRUCTURED&nextPageToken={}",
                id, page_token
            ))
            .header("X-Api-Key", &api_key)
            .send()
            .expect("Luau execution session logs request failed")
            .error_for_status()
            .expect("Error while fetching Luau execution session logs")
            .json::<LuauExecutionTaskLogsResponse>()
            .expect("Failed to read logs response");

        for log in logs_resp.luauExecutionSessionTaskLogs {
            for entry in log.structuredMessages {
                if entry.message.contains("Failed to load sound")
                    || entry.messageType == LogMessageType::Unspecified
                {
                    continue;
                }
                match entry.messageType {
                    LogMessageType::Error => error!(time = entry.createTime; "{}", entry.message),
                    LogMessageType::Warning => warn!(time = entry.createTime; "{}", entry.message),
                    LogMessageType::Info => info!(time = entry.createTime; "{}", entry.message),
                    LogMessageType::Output => fprint!(time = entry.createTime; "{}", entry.message),
                    _ => unreachable!(),
                }
            }
        }

        page_token = logs_resp.nextPageToken;
        if page_token.is_empty() {
            break;
        }
    }
    info!("----- End Luau Output -----");

    if result.state == LuauExecutionTaskState::Failed {
        if let Some(err) = result.error {
            panic!("Luau execution session failed: {}", err.message);
        } else {
            panic!("Luau execution session failed for unknown reason");
        }
    } else if result.state != LuauExecutionTaskState::Complete {
        // this is handled by the polling loop
        unreachable!()
    }

    if let Some(LuauExecutionTaskOutput { results: [result] }) = result.output {
        let percent = if result.total > 0 {
            (result.passed as f64 / result.total as f64) * 100.0
        } else {
            100.0
        };
        info!(
            "Results ({:.02?}): {} suites, {} tests ({} passed, {} failed) - {}% passed",
            Duration::from_secs_f64(result.time),
            fmt!(BOLD => "{}", result.suites),
            fmt!(BOLD => "{}", result.total),
            fmt!(GREEN BOLD => "{}", result.passed),
            fmt!(RED BOLD => "{}", result.failed),
            match percent {
                100.0 => fmt!(GREEN BOLD => "{:.02}", percent),
                p if p >= 75.0 => fmt!(YELLOW BOLD => "{:.02}", percent),
                a => fmt!(RED BOLD => "{:.02}", a),
            }
        );
        process::exit(if result.success { 0 } else { 1 })
    } else {
        panic!("Luau execution session has no output");
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[cfg(test)]
    #[test]
    #[should_panic]
    fn br() {
        set_panic_hook(Box::new(panic_hook));
        fprint!("Hello!");
        warn!("idk");
        error!("oops");
        info!("FYI");
        debug!("debugging");

        debug!("Done, {}, stuff after", fmt!(RED BOLD => "Hello!"));
        // std::panic::set_hook(Box::new(|_| std::process::exit(101)));
        panic!("BRuh");
    }
}
