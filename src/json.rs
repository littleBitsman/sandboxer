#[derive(serde::Serialize)]
pub struct LuauExecutionBinaryInputRequest {
    pub size: usize,
}

#[derive(serde::Deserialize)]
#[expect(non_snake_case)]
pub struct LuauExecutionBinaryInputResponse {
    pub path: String,
    #[expect(dead_code)]
    pub size: usize,
    pub uploadUri: String,
}

#[derive(serde::Serialize)]
#[expect(non_snake_case)]
pub struct LuauExecutionTaskRequest {
    pub script: &'static str,
    pub timeout: &'static str,
    pub binaryInput: String,
    pub enableBinaryOutput: bool,
}

#[derive(serde::Deserialize)]
pub struct LuauExecutionTaskError {
    #[expect(dead_code)]
    pub code: String,
    pub message: String,
}

#[derive(serde::Deserialize)]
pub struct LuauExecutionTaskResult {
    pub suites: u32,
    pub total: u32,
    pub passed: u32,
    pub failed: u32,
    pub success: bool,
    pub time: f64,
}

#[derive(serde::Deserialize)]
pub struct LuauExecutionTaskOutput {
    pub results: [LuauExecutionTaskResult; 1],
}

#[derive(serde::Deserialize)]
#[expect(non_snake_case)]
pub struct LuauExecutionTaskLogEntry {
    pub message: String,
    pub createTime: String,
    pub messageType: String,
}

#[derive(serde::Deserialize)]
#[expect(non_snake_case, dead_code)]
pub struct LuauExecutionTaskLog {
    pub path: String,
    pub messages: [(); 0],
    pub structuredMessages: Vec<LuauExecutionTaskLogEntry>,
}

#[derive(serde::Deserialize)]
#[expect(non_snake_case)]
pub struct LuauExecutionTaskLogsResponse {
    pub luauExecutionSessionTaskLogs: Vec<LuauExecutionTaskLog>,
    pub nextPageToken: String,
}

#[derive(serde::Deserialize)]
#[expect(non_snake_case, dead_code)]
pub struct LuauExecutionTaskResponse {
    pub path: String,
    pub createTime: Option<String>,
    pub updateTime: Option<String>,
    pub user: String,
    pub state: String,
    pub script: String,
    pub timeout: Option<String>,
    pub error: Option<LuauExecutionTaskError>,
    pub output: Option<LuauExecutionTaskOutput>,
    pub binaryInput: String,
    pub enableBinaryOutput: bool,
    pub binaryOutputUri: Option<String>,
}