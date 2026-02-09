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
fn panic_hook(info: &PanicHookInfo) {
    fatal!("{}", info.payload_as_str().unwrap_or("explicit panic"));
    if let Some(location) = info.location() {
        debug!("panicked at {location}");
    }
}

fn module_script_with_source(name: &str, source: String) -> InstanceBuilder {
    InstanceBuilder::with_property_capacity("ModuleScript", 1)
        .with_name(name)
        .with_property("Source", source)
}

fn read_source<P: AsRef<str>>(path: P) -> String {
    read_to_string(path.as_ref()).unwrap_or_else(|_| panic!("Failed to read {}", path.as_ref()))
}

#[inline(always)]
fn build_license() -> String {
    let license = read_source("LICENSE");
    let mut final_license = String::with_capacity(license.len() + 80);
    final_license.push_str("--[[\n");
    final_license.push_str(&license);
    final_license.push_str("\n--]]\n\n");
    final_license.push_str("script:Destroy()\n");
    final_license.push_str("return error(\"This is a LICENSE file (AGPL v3.0)\")");
    final_license
}

#[inline(always)]
fn build_sandboxer_dom() -> WeakDom {
    let license = build_license();

    let sandboxer_source = read_source("./src/init.luau");
    let instancelist_source = read_source("./src/InstanceList.luau");
    let instancesandboxer_source = read_source("./src/InstanceSandboxer.luau");

    let dom = WeakDom::new(
        InstanceBuilder::with_property_capacity("ModuleScript", 1)
            .with_name("Sandboxer")
            .with_property("Source", sandboxer_source)
            .with_children([
                module_script_with_source("InstanceList", instancelist_source),
                module_script_with_source("InstanceSandboxer", instancesandboxer_source),
                module_script_with_source("LICENSE", license),
            ]),
    );

    // guesstimate 32KB
    let mut out = Vec::with_capacity(32 * 1024);
    rbx_binary::to_writer(&mut out, &dom, &[dom.root_ref()])
        .expect("Failed to compile Sandboxer file");
    fs::write("Sandboxer.rbxm", &out).expect("Failed to write Sandboxer.rbxm");
    info!("Wrote Sandboxer.rbxm ({} bytes)", out.len());

    dom
}

#[inline(always)]
fn build_test_rbxm(latest_rbxm: WeakDom) -> Vec<u8> {
    let init_source = read_source("./builder/src/luau/init.luau");
    let testframework_source = read_source("./builder/src/luau/TestFramework.luau");

    let tests_iter = read_dir("./builder/src/luau/scripts")
        .expect("Failed to read scripts directory")
        .filter_map(|entry| {
            let entry = entry.expect("Failed to read test script");
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
                            .with_children(tests_iter),
                    ]),
            ),
    );

    let root = dom.root_ref();
    // transfer the Sandboxer module tree into the new dom (keeps same behavior)
    let sandbox_root = latest_rbxm.clone_into_external(latest_rbxm.root_ref(), &mut dom);
    dom.transfer_within(sandbox_root, root);

    // guesstimate 64 KB
    let mut buf = Vec::with_capacity(64 * 1000);
    rbx_binary::to_writer(&mut buf, &dom, &[root]).expect("Failed to compile rbxm file");

    match fs::write("test.rbxm", &buf) {
        Ok(()) => info!("Wrote test.rbxm ({} bytes)", buf.len()),
        Err(e) => {
            warn!("Failed to write test.rbxm; artifact will not upload to GitHub");
            warn!("Error: {e}");
        }
    }

    buf
}

#[inline(always)]
fn upload_binary(cli: &Client, api_key: &str, buf: &[u8]) -> LuauExecutionBinaryInputResponse {
    info!("Uploading test binary...");
    let binput = cli
        .post("https://apis.roblox.com/cloud/v2/universes/8382727792/luau-execution-session-task-binary-inputs")
        .header("X-Api-Key", api_key)
        .json(&LuauExecutionBinaryInputRequest { size: buf.len() })
        .send()
        .expect("Create binary input request failed")
        .error_for_status()
        .unwrap_or_else(|e| {
            let e = e.without_url();
            match e.status() {
                Some(status) => panic!("Create binary input request failed with HTTP {status}"),
                None => panic!("Create binary input request failed: {e}"),
            }
        }).json::<LuauExecutionBinaryInputResponse>()
        .expect("Failed to parse response");

    cli.put(&binput.uploadUri)
        .body(buf.to_vec())
        .send()
        .expect("Failed to upload binary input")
        .error_for_status()
        .expect("Upload request failed");

    info!("Successfully uploaded test binary");
    binput
}

#[inline(always)]
fn spawn_task(cli: &Client, api_key: &str, binary_path: String) -> LuauExecutionTaskResponse {
    cli
        .post("https://apis.roblox.com/cloud/v2/universes/8382727792/places/122953816609099/luau-execution-session-tasks")
        .header("X-Api-Key", api_key)
        .json(&LuauExecutionTaskRequest {
            script: SCRIPT,
            timeout: "10s",
            binaryInput: binary_path,
            enableBinaryOutput: true,
        })
        .send()
        .expect("Luau execution session request failed")
        .error_for_status()
        .expect("Error while spawning Luau execution session")
        .json::<LuauExecutionTaskResponse>()
        .expect("Failed to parse response")
}

const MAX_POLL_DELAY: Duration = Duration::from_secs(30);
#[inline(always)]
fn poll_task_state(cli: &Client, api_key: &str, id: &str) -> LuauExecutionTaskResponse {
    let state_req = cli
        .get(format!("https://apis.roblox.com/cloud/v2/{id}"))
        .header("X-Api-Key", api_key);

    let mut delay = Duration::from_secs(1);
    loop {
        let resp = unwrap!(unsafe state_req.try_clone())
            .send()
            .expect("Luau execution session state request failed")
            .error_for_status()
            .expect("Error while checking Luau execution session state")
            .json::<LuauExecutionTaskResponse>()
            .expect("Failed to parse response");

        match resp.state {
            LuauExecutionTaskState::Complete | LuauExecutionTaskState::Failed => return resp,
            state => info!(
                "Current state: {state:?}. Waiting {} seconds before polling again...",
                delay.as_secs()
            ),
        }

        sleep(delay);
        delay = MAX_POLL_DELAY.min(delay * 2);
    }
}

#[inline(always)]
fn stream_and_print_logs(cli: &Client, api_key: &str, id: &str) {
    let mut page_token = String::with_capacity(24);

    info!("------- Luau Output -------");
    loop {
        let logs_resp = cli
            .get(format!(
                "https://apis.roblox.com/cloud/v2/{}/logs?view=STRUCTURED&nextPageToken={}",
                id, page_token
            ))
            .header("X-Api-Key", api_key)
            .send()
            .expect("Luau execution session logs request failed")
            .error_for_status()
            .expect("Error while fetching Luau execution session logs")
            .json::<LuauExecutionTaskLogsResponse>()
            .expect("Failed to parse Luau execution logs");

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
}

fn main() {
    set_panic_hook(Box::new(panic_hook));

    let dom = build_sandboxer_dom();
    let buf = build_test_rbxm(dom);

    let api_key = env("ROBLOX_API_KEY").expect("Missing API key");

    let cli = Client::new();

    let binput = upload_binary(&cli, &api_key, &buf);
    let response = spawn_task(&cli, &api_key, binput.path);

    let id = response.path;

    debug!("Luau execution session started with ID: {}", id);
    let result = poll_task_state(&cli, &api_key, &id);
    stream_and_print_logs(&cli, &api_key, &id);

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
        fprint!(time = fmt!(RED BOLD UNDERLINE => "Bruh this is DEFINITELY not a time"); "Bruh.");
        // std::panic::set_hook(Box::new(|_| std::process::exit(101)));
        panic!("BRuh");
    }
}
