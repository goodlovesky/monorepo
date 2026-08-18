//! # core-bridge
//!
//! FFI bridge exposing the proxy core to Dart/Flutter.
//!
//! ## 设计原则
//!
//! 1. **C ABI 兼容**：所有导出函数用 `extern "C"`，使用 `#[no_mangle]`
//! 2. **字符串所有权**：Dart 端负责 `free` 我们返回的字符串（用 `libc::free`）
//! 3. **错误码优先**：返回值用整数错误码，详细信息通过字符串函数获取
//! 4. **线程安全**：所有全局状态用 `OnceLock` / `Mutex` 保护
//! 5. **panic-safe**：所有 `extern "C"` 函数用 `std::panic::catch_unwind` 包裹
//!
//! ## 当前阶段
//!
//! Phase 0.2: 最小可用的 FFI demo，验证 `Rust → C ABI → Dart FFI` 链路。
//! 真实 clash-rs 集成在 Phase 1 启用 `full` feature。

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::panic;
use std::sync::OnceLock;

use serde::{Deserialize, Serialize};
use thiserror::Error;

// ========================================================================
// 错误类型
// ========================================================================

/// FFI 错误码
#[repr(i32)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ErrorCode {
    /// 成功
    Ok = 0,
    /// 参数无效
    InvalidArg = -1,
    /// 空指针
    NullPointer = -2,
    /// UTF-8 解码失败
    Utf8 = -3,
    /// 未初始化
    NotInitialized = -4,
    /// 已经初始化
    AlreadyInitialized = -5,
    /// 内部错误（panic / 异常）
    Internal = -100,
    /// 未实现（该功能在当前 phase 不可用）
    NotImplemented = -101,
}

impl ErrorCode {
    pub fn as_i32(self) -> i32 {
        self as i32
    }
}

#[derive(Debug, Error)]
pub enum CoreError {
    #[error("invalid argument: {0}")]
    InvalidArg(String),
    #[error("null pointer")]
    NullPointer,
    #[error("utf-8 decode error: {0}")]
    Utf8(String),
    #[error("not initialized")]
    NotInitialized,
    #[error("already initialized")]
    AlreadyInitialized,
    #[error("internal error: {0}")]
    Internal(String),
    #[error("not implemented: {0}")]
    NotImplemented(String),
}

impl From<CoreError> for ErrorCode {
    fn from(err: CoreError) -> Self {
        match err {
            CoreError::InvalidArg(_) => ErrorCode::InvalidArg,
            CoreError::NullPointer => ErrorCode::NullPointer,
            CoreError::Utf8(_) => ErrorCode::Utf8,
            CoreError::NotInitialized => ErrorCode::NotInitialized,
            CoreError::AlreadyInitialized => ErrorCode::AlreadyInitialized,
            CoreError::Internal(_) => ErrorCode::Internal,
            CoreError::NotImplemented(_) => ErrorCode::NotImplemented,
        }
    }
}

// ========================================================================
// 全局状态（Phase 0 demo 用）
// ========================================================================

/// 全局代理状态
#[derive(Debug, Default, Serialize, Deserialize)]
struct CoreState {
    home_dir: String,
    version: String,
    sdk: i32,
    initialized_at_unix: i64,
}

static STATE: OnceLock<std::sync::Mutex<Option<CoreState>>> = OnceLock::new();

fn state() -> &'static std::sync::Mutex<Option<CoreState>> {
    STATE.get_or_init(|| std::sync::Mutex::new(None))
}

// ========================================================================
// FFI 工具宏
// ========================================================================

/// 捕获 panic 并返回错误码。
/// 所有 `extern "C"` 函数都该用这个包裹。
macro_rules! ffi_guard {
    ($body:expr) => {{
        match panic::catch_unwind(panic::AssertUnwindSafe(|| $body)) {
            Ok(result) => match result {
                Ok(()) => ErrorCode::Ok.as_i32(),
                Err(e) => {
                    tracing::error!(error = %e, "ffi call failed");
                    ErrorCode::from(e).as_i32()
                }
            },
            Err(panic) => {
                let msg = if let Some(s) = panic.downcast_ref::<&'static str>() {
                    s.to_string()
                } else if let Some(s) = panic.downcast_ref::<String>() {
                    s.clone()
                } else {
                    "unknown panic".to_string()
                };
                tracing::error!(panic = %msg, "ffi call panicked");
                ErrorCode::Internal.as_i32()
            }
        }
    }};
}

/// 读取 C 字符串参数
unsafe fn read_c_str<'a>(ptr: *const c_char, name: &str) -> Result<&'a str, CoreError> {
    if ptr.is_null() {
        return Err(CoreError::NullPointer);
    }
    unsafe { CStr::from_ptr(ptr) }
        .to_str()
        .map_err(|e| CoreError::Utf8(format!("{name}: {e}")))
}

/// 把 Rust 字符串复制成 C 字符串，Dart 端用 `free()` 释放。
fn to_c_string(s: String) -> *mut c_char {
    match CString::new(s) {
        Ok(c) => c.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

// ========================================================================
// FFI 导出
// ========================================================================

/// 库版本号
///
/// 返回 C 字符串，Dart 端需 `calloc.free()` 释放。
///
/// # Safety
///
/// 调用方必须保证返回的指针最终用 `libc::free()` 释放。
#[no_mangle]
pub extern "C" fn proxy_version() -> *mut c_char {
    let s = env!("CARGO_PKG_VERSION").to_string();
    to_c_string(s)
}

/// 初始化代理核心。
///
/// # Arguments
///
/// * `home_dir` - 工作目录（通常是 app 的 files 目录）
/// * `version` - 应用版本号
/// * `sdk` - 平台 SDK 版本（Android API Level 或 iOS 版本号 * 100）
///
/// # Returns
///
/// 0 成功，非 0 失败。
///
/// # Safety
///
/// `home_dir` 和 `version` 必须是合法的 UTF-8 C 字符串（可为 NULL，但会导致错误）。
#[no_mangle]
pub extern "C" fn proxy_init(
    home_dir: *const c_char,
    version: *const c_char,
    sdk: i32,
) -> i32 {
    ffi_guard!({
        let home = unsafe { read_c_str(home_dir, "home_dir")? };
        let ver = unsafe { read_c_str(version, "version")? };

        let mut guard = state().lock().map_err(|e| CoreError::Internal(e.to_string()))?;
        if guard.is_some() {
            return Err(CoreError::AlreadyInitialized);
        }

        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs() as i64)
            .unwrap_or(0);

        tracing::info!(home = %home, version = %ver, sdk, "proxy_init");

        *guard = Some(CoreState {
            home_dir: home.to_string(),
            version: ver.to_string(),
            sdk,
            initialized_at_unix: now,
        });
        Ok(())
    })
}

/// 关闭代理核心，释放资源。
#[no_mangle]
pub extern "C" fn proxy_shutdown() -> i32 {
    ffi_guard!({
        let mut guard = state().lock().map_err(|e| CoreError::Internal(e.to_string()))?;
        if guard.is_none() {
            return Err(CoreError::NotInitialized);
        }
        tracing::info!("proxy_shutdown");
        *guard = None;
        Ok(())
    })
}

/// 查询当前状态（JSON 字符串）。
///
/// 返回的指针需要 `libc::free()` 释放。
///
/// # Safety
///
/// 同上。
#[no_mangle]
pub extern "C" fn proxy_query_state() -> *mut c_char {
    let result = panic::catch_unwind(panic::AssertUnwindSafe(|| {
        let guard = state().lock().map_err(|e| CoreError::Internal(e.to_string()))?;
        let state = guard.as_ref().ok_or(CoreError::NotInitialized)?;
        let json = serde_json::to_string(state)
            .map_err(|e| CoreError::Internal(e.to_string()))?;
        Ok::<String, CoreError>(json)
    }));

    match result {
        Ok(Ok(s)) => to_c_string(s),
        Ok(Err(e)) => {
            tracing::error!(error = %e, "proxy_query_state failed");
            std::ptr::null_mut()
        }
        Err(_) => std::ptr::null_mut(),
    }
}

/// 获取最后一次错误的描述（人类可读）。
///
/// 返回的指针需要 `libc::free()` 释放。
#[no_mangle]
pub extern "C" fn proxy_last_error_message(code: i32) -> *mut c_char {
    let msg = match code {
        0 => "ok",
        -1 => "invalid argument",
        -2 => "null pointer",
        -3 => "utf-8 decode error",
        -4 => "not initialized",
        -5 => "already initialized",
        -100 => "internal error",
        -101 => "not implemented",
        _ => "unknown error",
    };
    to_c_string(msg.to_string())
}

/// 简单的 ping 接口，验证 FFI 链路。
///
/// 输入字符串，输出 `"pong: <input>"`。
#[no_mangle]
pub extern "C" fn proxy_pong(input: *const c_char) -> *mut c_char {
    let result = panic::catch_unwind(panic::AssertUnwindSafe(|| {
        let s = unsafe { read_c_str(input, "input")? };
        Ok::<String, CoreError>(format!("pong: {s}"))
    }));

    match result {
        Ok(Ok(s)) => to_c_string(s),
        _ => std::ptr::null_mut(),
    }
}

/// 释放由本库分配的 C 字符串。
///
/// Dart 端应优先用 `calloc.free()` 释放，这里只是为了对称。
///
/// # Safety
///
/// `ptr` 必须是由本库的某个返回 `*mut c_char` 的函数返回的指针，或者为 NULL。
#[no_mangle]
pub extern "C" fn proxy_free_string(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        let _ = CString::from_raw(ptr);
    }
}

// ========================================================================
// 单元测试
// ========================================================================

#[cfg(test)]
mod tests {
    use super::*;

    fn make_cstr(s: &str) -> *mut c_char {
        CString::new(s).unwrap().into_raw()
    }

    unsafe fn read_cstring(ptr: *mut c_char) -> String {
        // SAFETY: 函数标记为 unsafe，调用方保证 ptr 有效
        CStr::from_ptr(ptr).to_string_lossy().into_owned()
    }

    #[test]
    fn test_version() {
        let v_ptr = proxy_version();
        assert!(!v_ptr.is_null());
        let v = unsafe { read_cstring(v_ptr) };
        proxy_free_string(v_ptr);
        assert_eq!(v, env!("CARGO_PKG_VERSION"));
    }

    #[test]
    fn test_pong() {
        let input = make_cstr("hello");
        let out = proxy_pong(input);
        let _ = unsafe { CString::from_raw(input) };
        assert!(!out.is_null());
        let s = unsafe { read_cstring(out) };
        proxy_free_string(out);
        assert_eq!(s, "pong: hello");
    }

    #[test]
    fn test_init_shutdown() {
        // 重置 state
        {
            let mut guard = state().lock().unwrap();
            *guard = None;
        }

        let home = make_cstr("/tmp/proxy_test");
        let ver = make_cstr("0.1.0");

        let rc = proxy_init(home, ver, 35);
        unsafe {
            let _ = CString::from_raw(home);
            let _ = CString::from_raw(ver);
        }
        assert_eq!(rc, 0);

        // 二次 init 应该失败
        let home2 = make_cstr("/tmp/proxy_test");
        let ver2 = make_cstr("0.1.0");
        let rc2 = proxy_init(home2, ver2, 35);
        unsafe {
            let _ = CString::from_raw(home2);
            let _ = CString::from_raw(ver2);
        }
        assert_eq!(rc2, ErrorCode::AlreadyInitialized.as_i32());

        // shutdown 应该成功
        assert_eq!(proxy_shutdown(), 0);

        // 再次 shutdown 应该失败
        assert_eq!(proxy_shutdown(), ErrorCode::NotInitialized.as_i32());
    }

    #[test]
    fn test_query_state() {
        // 重置
        {
            let mut guard = state().lock().unwrap();
            *guard = None;
        }

        // 未初始化查询
        let ptr = proxy_query_state();
        assert!(ptr.is_null());

        // 初始化
        let home = make_cstr("/tmp/proxy_test");
        let ver = make_cstr("0.1.0");
        let _ = proxy_init(home, ver, 35);
        unsafe {
            let _ = CString::from_raw(home);
            let _ = CString::from_raw(ver);
        }

        // 查询
        let ptr = proxy_query_state();
        assert!(!ptr.is_null());
        let s = unsafe { read_cstring(ptr) };
        proxy_free_string(ptr);
        assert!(s.contains("/tmp/proxy_test"));
        assert!(s.contains("0.1.0"));
        assert!(s.contains("35"));

        // 清理
        let _ = proxy_shutdown();
    }

    #[test]
    fn test_null_safety() {
        let rc = proxy_init(std::ptr::null(), std::ptr::null(), 0);
        assert_eq!(rc, ErrorCode::NullPointer.as_i32());
    }

    #[test]
    fn test_invalid_utf8() {
        // 0xFF 0xFE 不是合法 UTF-8
        let bad = [0xFFu8, 0xFEu8, 0x00u8];
        let ptr = bad.as_ptr() as *const c_char;
        let rc = proxy_init(ptr, ptr, 0);
        assert_eq!(rc, ErrorCode::Utf8.as_i32());
    }
}
