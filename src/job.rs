//! Asynchronous Cargo job management.
//!
//! A job spawns `cargo <subcommand> <args>` on a dedicated background thread
//! and streams its combined stdout/stderr into a shared, drainable buffer.
//! The Lua side starts a job, polls it on a timer to render new output, and may
//! feed stdin or interrupt it. Running through `tokio::process::Command` with an
//! argument vector means no shell is involved, so arguments cannot be
//! re-interpreted or injected.

use std::collections::HashMap;
use std::process::Stdio;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use std::thread;

use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::process::Command as TokioCommand;
use tokio::sync::{mpsc, oneshot};

/// Output and lifecycle state shared between a job's background thread and the
/// `poll` calls coming from Lua.
#[derive(Default)]
struct JobState {
    /// Lines produced since the last `poll`. Drained on every poll.
    lines: Vec<String>,
    /// Set once the process has exited (or failed to start).
    finished: bool,
    /// Whether the process exited successfully. Only meaningful once finished.
    success: bool,
}

/// Handle to a running job, kept in the global registry.
struct Job {
    state: Arc<Mutex<JobState>>,
    stdin_tx: mpsc::UnboundedSender<String>,
    /// Consumed by the first `interrupt`; sending requests termination.
    kill_tx: Option<oneshot::Sender<()>>,
}

fn registry() -> &'static Mutex<HashMap<u64, Job>> {
    static REG: OnceLock<Mutex<HashMap<u64, Job>>> = OnceLock::new();
    REG.get_or_init(|| Mutex::new(HashMap::new()))
}

fn next_id() -> u64 {
    static COUNTER: AtomicU64 = AtomicU64::new(1);
    COUNTER.fetch_add(1, Ordering::Relaxed)
}

fn push_line(state: &Arc<Mutex<JobState>>, line: String) {
    state
        .lock()
        .expect("job state mutex poisoned")
        .lines
        .push(line);
}

fn finish(state: &Arc<Mutex<JobState>>, success: bool) {
    let mut st = state.lock().expect("job state mutex poisoned");
    st.finished = true;
    st.success = success;
}

/// Start `cargo <subcommand> <args>` and return a job id for later polling.
pub(crate) fn start(subcommand: String, args: Vec<String>) -> u64 {
    let id = next_id();
    let state = Arc::new(Mutex::new(JobState::default()));
    let (stdin_tx, stdin_rx) = mpsc::unbounded_channel::<String>();
    let (kill_tx, kill_rx) = oneshot::channel::<()>();

    let thread_state = Arc::clone(&state);
    thread::spawn(move || {
        let runtime = match tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
        {
            Ok(rt) => rt,
            Err(e) => {
                push_line(&thread_state, format!("Failed to create runtime: {e}"));
                finish(&thread_state, false);
                return;
            }
        };
        runtime.block_on(run_job(subcommand, args, thread_state, stdin_rx, kill_rx));
    });

    registry()
        .lock()
        .expect("job registry mutex poisoned")
        .insert(
            id,
            Job {
                state,
                stdin_tx,
                kill_tx: Some(kill_tx),
            },
        );
    id
}

/// Drain the lines produced since the last poll and report lifecycle state.
///
/// Returns `(lines, finished, success)`. Once a job reports `finished`, its
/// final lines are returned in the same call and the job is removed from the
/// registry. Polling an unknown id reports `finished = true`.
pub(crate) fn poll(id: u64) -> (Vec<String>, bool, bool) {
    let mut reg = registry().lock().expect("job registry mutex poisoned");
    let Some(job) = reg.get(&id) else {
        return (Vec::new(), true, false);
    };

    let (lines, finished, success) = {
        let mut st = job.state.lock().expect("job state mutex poisoned");
        (std::mem::take(&mut st.lines), st.finished, st.success)
    };

    if finished {
        reg.remove(&id);
    }
    (lines, finished, success)
}

/// Send a line of input to a running job's stdin. Unknown ids are ignored.
pub(crate) fn send_input(id: u64, input: String) {
    if let Some(job) = registry()
        .lock()
        .expect("job registry mutex poisoned")
        .get(&id)
    {
        let _ = job.stdin_tx.send(input);
    }
}

/// Request termination of a running job. Unknown ids are ignored.
pub(crate) fn interrupt(id: u64) {
    if let Some(job) = registry()
        .lock()
        .expect("job registry mutex poisoned")
        .get_mut(&id)
    {
        if let Some(tx) = job.kill_tx.take() {
            let _ = tx.send(());
        }
    }
}

async fn run_job(
    subcommand: String,
    args: Vec<String>,
    state: Arc<Mutex<JobState>>,
    mut stdin_rx: mpsc::UnboundedReceiver<String>,
    mut kill_rx: oneshot::Receiver<()>,
) {
    let mut command = TokioCommand::new("cargo");
    command
        .arg(&subcommand)
        .args(&args)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());

    let mut child = match command.spawn() {
        Ok(child) => child,
        Err(e) => {
            push_line(&state, format!("Failed to start `cargo {subcommand}`: {e}"));
            finish(&state, false);
            return;
        }
    };

    let mut stdout = child.stdout.take().map(|s| BufReader::new(s).lines());
    let mut stderr = child.stderr.take().map(|s| BufReader::new(s).lines());
    let mut stdin = child.stdin.take();
    let mut killing = false;

    loop {
        tokio::select! {
            // Prefer reporting newly read output over noticing exit, so the
            // final lines are not lost if the child exits promptly.
            biased;

            res = async { stdout.as_mut().expect("guarded by is_some").next_line().await },
                if stdout.is_some() =>
            {
                match res {
                    Ok(Some(line)) => push_line(&state, line),
                    _ => stdout = None,
                }
            }

            res = async { stderr.as_mut().expect("guarded by is_some").next_line().await },
                if stderr.is_some() =>
            {
                match res {
                    Ok(Some(line)) => push_line(&state, line),
                    _ => stderr = None,
                }
            }

            Some(input) = stdin_rx.recv() => {
                if let Some(pipe) = stdin.as_mut() {
                    let _ = pipe.write_all(input.as_bytes()).await;
                    let _ = pipe.flush().await;
                }
            }

            _ = &mut kill_rx, if !killing => {
                killing = true;
                let _ = child.start_kill();
                push_line(&state, "Process interrupted by user".to_string());
            }

            status = child.wait() => {
                // The child has exited; drain whatever the readers still hold.
                drain(&mut stdout, &state).await;
                drain(&mut stderr, &state).await;
                let success = status.map(|s| s.success()).unwrap_or(false);
                finish(&state, success);
                return;
            }
        }
    }
}

/// Drain any remaining buffered lines from a reader after the child exited.
async fn drain<R>(reader: &mut Option<tokio::io::Lines<R>>, state: &Arc<Mutex<JobState>>)
where
    R: tokio::io::AsyncBufRead + Unpin,
{
    if let Some(lines) = reader.as_mut() {
        while let Ok(Some(line)) = lines.next_line().await {
            push_line(state, line);
        }
    }
    *reader = None;
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{Duration, Instant};

    /// Poll until the job reports finished (or a timeout elapses), collecting
    /// all streamed lines.
    fn wait_for(id: u64) -> (Vec<String>, bool) {
        let deadline = Instant::now() + Duration::from_secs(30);
        let mut collected = Vec::new();
        loop {
            let (lines, finished, success) = poll(id);
            collected.extend(lines);
            if finished {
                return (collected, success);
            }
            assert!(Instant::now() < deadline, "job did not finish in time");
            thread::sleep(Duration::from_millis(10));
        }
    }

    #[test]
    fn unknown_id_reports_finished() {
        let (lines, finished, success) = poll(u64::MAX);
        assert!(lines.is_empty());
        assert!(finished);
        assert!(!success);
    }

    #[test]
    fn successful_command_streams_output_and_succeeds() {
        let id = start("--version".to_string(), Vec::new());
        let (lines, success) = wait_for(id);
        assert!(success, "cargo --version should succeed");
        assert!(
            lines.iter().any(|l| l.contains("cargo")),
            "expected version output, got: {lines:?}"
        );
        // Registry is cleaned up once a finished job has been fully polled.
        assert!(!registry().lock().expect("registry").contains_key(&id));
    }

    #[test]
    fn invalid_subcommand_finishes_unsuccessfully() {
        let id = start("this-is-not-a-cargo-command".to_string(), Vec::new());
        let (_lines, success) = wait_for(id);
        assert!(!success, "an unknown subcommand must not report success");
    }
}
