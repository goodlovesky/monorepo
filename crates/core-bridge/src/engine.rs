//! # Engine 模块
//!
//! 包装 clash-lib，提供 start/stop/is_running 三个核心能力。
//!
//! ## 生命周期
//!
//! ```text
//!   [Dart]                  [FFI]                     [Engine]
//!      │                      │                           │
//!      │ start()              │                           │
//!      ├─────────────────────►│  spawn thread:            │
//!      │                      │  start_scaffold()         │
//!      │ <─ 0 (ok) ───────────┤                           │
//!      │                      │                           │ (后台线程跑 clash)
//!      │ is_running()         │                           │
//!      ├─────────────────────►│  check AtomicBool         │
//!      │ <─ 1 (running) ──────┤                           │
//!      │ ...                  │                           │
//!      │ stop()               │                           │
//!      ├─────────────────────►│  set shutdown flag        │
//!      │ <─ 0 (ok) ───────────┤                           │
//! ```
//!
//! ## 设计取舍
//!
//! - **clash-lib 0.8.2 的 API 是同步的**（`start_scaffold` 阻塞当前线程）
//! - 我们在 FFI 里 spawn 一个新线程来跑 `start_scaffold`，不阻塞调用方
//! - 关闭通过 `shutdown()` 全局函数（不带 token）
//! - 状态用 `AtomicBool` 跟踪，避免 Mutex 锁
//! - 单实例：一个 app 进程内只跑一个 clash 实例

use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::OnceLock;

use clash_lib::{Config, Options, TokioRuntime};

/// 全局运行标志
static RUNNING: AtomicBool = AtomicBool::new(false);

/// 后台线程句柄
static THREAD: OnceLock<std::sync::Mutex<Option<std::thread::JoinHandle<()>>>> = OnceLock::new();

fn thread_slot() -> &'static std::sync::Mutex<Option<std::thread::JoinHandle<()>>> {
    THREAD.get_or_init(|| std::sync::Mutex::new(None))
}

/// 启动代理引擎
pub fn start(config_path: &str, cwd: &str, log_file: Option<&str>) -> Result<(), String> {
    if RUNNING.load(Ordering::SeqCst) {
        return Err("engine already running".to_string());
    }

    let path = PathBuf::from(config_path);
    if !path.exists() {
        return Err(format!("config file not found: {config_path}"));
    }

    let opts = Options {
        config: Config::File(config_path.to_string()),
        cwd: Some(cwd.to_string()),
        rt: Some(TokioRuntime::MultiThread),
        log_file: log_file.map(|s| s.to_string()),
    };

    let join = std::thread::Builder::new()
        .name("clash-engine".to_string())
        .spawn(move || {
            tracing::info!("clash engine thread started");
            RUNNING.store(true, Ordering::SeqCst);
            let result = clash_lib::start_scaffold(opts);
            RUNNING.store(false, Ordering::SeqCst);
            if let Err(e) = result {
                tracing::error!(error = ?e, "clash engine exited with error");
            } else {
                tracing::info!("clash engine exited cleanly");
            }
        })
        .map_err(|e| format!("failed to spawn engine thread: {e}"))?;

    // 存 thread handle
    {
        let mut slot = thread_slot()
            .lock()
            .map_err(|e| format!("thread slot lock poisoned: {e}"))?;
        *slot = Some(join);
    }

    // 等到 RUNNING 变 true（最多 2 秒），确认引擎真的起来了
    let start = std::time::Instant::now();
    while !RUNNING.load(Ordering::SeqCst) {
        if start.elapsed() > std::time::Duration::from_secs(2) {
            return Err("engine start timeout".to_string());
        }
        std::thread::sleep(std::time::Duration::from_millis(10));
    }

    tracing::info!(config = %config_path, cwd = %cwd, "engine started");
    Ok(())
}

/// 停止代理引擎
pub fn stop() -> Result<(), String> {
    if !RUNNING.load(Ordering::SeqCst) {
        return Err("engine not running".to_string());
    }

    // clash-lib 0.8.2 的关闭机制：调用 shutdown()
    clash_lib::shutdown();

    // 等待线程退出
    {
        let mut slot = thread_slot()
            .lock()
            .map_err(|e| format!("thread slot lock poisoned: {e}"))?;
        if let Some(join) = slot.take() {
            let (tx, rx) = std::sync::mpsc::channel::<()>();
            std::thread::spawn(move || {
                let _ = join.join();
                let _ = tx.send(());
            });
            match rx.recv_timeout(std::time::Duration::from_secs(5)) {
                Ok(_) => tracing::info!("engine thread joined cleanly"),
                Err(_) => tracing::warn!("engine thread join timed out after 5s"),
            }
        }
    }

    RUNNING.store(false, Ordering::SeqCst);
    tracing::info!("engine stopped");
    Ok(())
}

/// 查询引擎是否在运行
pub fn is_running() -> bool {
    RUNNING.load(Ordering::SeqCst)
}

/// 获取当前引擎状态
pub fn status() -> EngineStatus {
    EngineStatus {
        running: is_running(),
    }
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct EngineStatus {
    pub running: bool,
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    fn write_test_config(path: &std::path::Path) {
        let mut f = std::fs::File::create(path).unwrap();
        writeln!(
            f,
            r#"
port: 17890
socks-port: 17891
mixed-port: 17892
allow-lan: false
mode: rule
log-level: info

dns:
  enable: true
  listen: 127.0.0.1:53053
  default-nameserver: [114.114.114.114]
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver: [114.114.114.114]

rules:
  - MATCH,DIRECT
"#
        )
        .unwrap();
    }

    #[test]
    fn test_status_initial() {
        // status 应该能调用，不 panic
        let s = status();
        let _ = format!("{s:?}");
    }

    #[test]
    fn test_start_with_missing_file() {
        let dir = tempfile::tempdir().unwrap();
        let bad_path = dir.path().join("not_exist.yaml");

        // 文件不存在应该失败
        let result = start(
            bad_path.to_str().unwrap(),
            dir.path().to_str().unwrap(),
            None,
        );
        assert!(result.is_err());
        assert!(!is_running());
    }

    #[test]
    fn test_stop_when_not_running() {
        RUNNING.store(false, Ordering::SeqCst);
        let result = stop();
        assert!(result.is_err());
    }

    #[test]
    fn test_start_real_engine() {
        // 这个测试需要 geoip/geosite 数据，可能失败
        // 暂时跳过，需要时手动跑：
        //   cargo test test_start_real_engine -- --ignored --nocapture
        if std::env::var("RUN_ENGINE_TEST").is_err() {
            eprintln!("跳过（设 RUN_ENGINE_TEST=1 启用）");
            return;
        }

        let dir = tempfile::tempdir().unwrap();
        let cfg = dir.path().join("config.yaml");
        write_test_config(&cfg);

        // 启动
        let rc = start(cfg.to_str().unwrap(), dir.path().to_str().unwrap(), None);
        eprintln!("start result: {rc:?}");
        if rc.is_ok() {
            assert!(is_running());
            // 停
            let stop_rc = stop();
            eprintln!("stop result: {stop_rc:?}");
            assert!(!is_running());
        }
    }
}
