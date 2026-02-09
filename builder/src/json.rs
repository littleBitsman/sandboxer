#![expect(dead_code)]

#[derive(serde::Serialize, Debug)]
pub struct LuauExecutionBinaryInputRequest {
    pub size: usize,
}

#[derive(serde::Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct LuauExecutionBinaryInputResponse {
    pub path: String,
    pub size: usize,
    #[serde(rename = "uploadUri")]
    pub upload_url: String,
}

#[derive(serde::Serialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct LuauExecutionTaskRequest {
    pub script: &'static str,
    pub timeout: &'static str,
    pub binary_input: String,
    pub enable_binary_output: bool,
}

#[derive(serde::Deserialize, Debug, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum LuauExecutionError {
    ScriptError,
    DeadlineExceeded,
    OutputSizeLimitExceeded,
    InternalError,
    #[serde(rename = "ERROR_CODE_UNSPECIFIED", other)]
    Unspecified,
}

#[derive(serde::Deserialize, Debug)]
pub struct LuauExecutionTaskError {
    pub code: LuauExecutionError,
    pub message: String,
}

#[derive(serde::Deserialize, Debug)]
pub struct LuauExecutionTaskResult {
    pub suites: u32,
    pub total: u32,
    pub passed: u32,
    pub failed: u32,
    pub success: bool,
    pub time: f64,
}

#[derive(serde::Deserialize, Debug)]
pub struct LuauExecutionTaskOutput {
    pub results: [LuauExecutionTaskResult; 1],
}

#[derive(serde::Deserialize, Debug, PartialEq, Eq)]
#[serde(rename_all = "UPPERCASE")]
pub enum LogMessageType {
    Error,
    Warning,
    Info,
    Output,
    #[serde(rename = "MESSAGE_TYPE_UNSPECIFIED", other)]
    Unspecified,
}

#[derive(serde::Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct LuauExecutionTaskLogEntry {
    pub message: String,
    pub create_time: String,
    pub message_type: LogMessageType,
}

#[derive(serde::Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct LuauExecutionTaskLog {
    pub path: String,
    pub messages: [(); 0],
    pub structured_messages: Vec<LuauExecutionTaskLogEntry>,
}

#[derive(serde::Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct LuauExecutionTaskLogsResponse {
    pub luau_execution_session_task_logs: Vec<LuauExecutionTaskLog>,
    pub next_page_token: String,
}

#[derive(serde::Deserialize, Debug, PartialEq, Eq)]
#[serde(rename_all = "UPPERCASE")]
pub enum LuauExecutionTaskState {
    Queued,
    Processing,
    Cancelled,
    Complete,
    Failed,
    #[serde(rename = "STATE_UNSPECIFIED", other)]
    Unspecified
}

#[derive(serde::Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct LuauExecutionTaskResponse {
    pub path: String,
    pub create_time: Option<String>,
    pub update_time: Option<String>,
    pub user: String,
    pub state: LuauExecutionTaskState,
    pub script: String,
    pub timeout: Option<String>,
    pub error: Option<LuauExecutionTaskError>,
    pub output: Option<LuauExecutionTaskOutput>,
    pub binary_input: String,
    pub enable_binary_output: bool,
    pub binary_output_uri: Option<String>,
}