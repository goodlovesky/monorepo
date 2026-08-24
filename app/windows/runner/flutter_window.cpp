#include "flutter_window.h"

#include <optional>
#include <windowsx.h>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  lifecycle_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.proxyapp.app/desktop_lifecycle",
          &flutter::StandardMethodCodec::GetInstance());
  lifecycle_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() == "setCloseToTray") {
          if (const auto* enabled =
                  std::get_if<bool>(call.arguments())) {
            close_to_tray_ = *enabled;
          }
          result->Success();
          return;
        }
        if (call.method_name() == "setTrayClickAction") {
          if (const auto* action =
                  std::get_if<std::string>(call.arguments())) {
            tray_click_action_ = *action == "quit" ? "quit" : "show";
          }
          result->Success();
          return;
        }
        if (call.method_name() == "quit") {
          PostMessage(GetHandle(), WM_COMMAND, kTrayQuit, 0);
          result->Success();
          return;
        }
        result->NotImplemented();
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  InstallTrayIcon();

  const bool silent_start =
      wcsstr(GetCommandLineW(), L"--silent") != nullptr;
  flutter_controller_->engine()->SetNextFrameCallback([&, silent_start]() {
    if (!silent_start) this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  RemoveTrayIcon();
  lifecycle_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_CLOSE:
      if (close_to_tray_ && !exiting_) {
        ShowWindow(hwnd, SW_HIDE);
        return 0;
      }
      break;
    case kTrayMessage:
      if (LOWORD(lparam) == WM_LBUTTONUP ||
          LOWORD(lparam) == WM_LBUTTONDBLCLK) {
        if (tray_click_action_ == "quit") {
          PostMessage(hwnd, WM_COMMAND, kTrayQuit, 0);
        } else {
          ShowWindow(hwnd, SW_RESTORE);
          SetForegroundWindow(hwnd);
        }
        return 0;
      }
      if (LOWORD(lparam) == WM_RBUTTONUP || LOWORD(lparam) == WM_CONTEXTMENU) {
        ShowTrayMenu();
        return 0;
      }
      break;
    case WM_COMMAND:
      if (LOWORD(wparam) == kTrayShow) {
        ShowWindow(hwnd, SW_RESTORE);
        SetForegroundWindow(hwnd);
        return 0;
      }
      if (LOWORD(wparam) == kTrayQuit) {
        BeginQuit();
        return 0;
      }
      break;
    case kQuitReady:
      KillTimer(hwnd, kQuitTimer);
      exiting_ = true;
      DestroyWindow(hwnd);
      return 0;
    case WM_TIMER:
      if (wparam == kQuitTimer && quit_cleanup_started_) {
        PostMessage(hwnd, kQuitReady, 0, 0);
        return 0;
      }
      break;
    case WM_QUERYENDSESSION:
      // Windows does not wait for asynchronous Flutter work here. Start the
      // same bounded cleanup used by tray/installer exit, then permit shutdown.
      BeginQuit();
      return TRUE;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::BeginQuit() {
  if (quit_cleanup_started_) return;
  quit_cleanup_started_ = true;
  exiting_ = true;
  // Always leave a bounded escape hatch: a broken Dart isolate must not make
  // upgrades, uninstall or Windows shutdown hang forever.
  SetTimer(GetHandle(), kQuitTimer, 8000, nullptr);
  if (!lifecycle_channel_) {
    PostMessage(GetHandle(), kQuitReady, 0, 0);
    return;
  }
  const HWND window = GetHandle();
  lifecycle_channel_->InvokeMethod(
      "prepareForQuit", nullptr,
      std::make_unique<flutter::MethodResultFunctions<flutter::EncodableValue>>(
          [window](const flutter::EncodableValue*) {
            PostMessage(window, kQuitReady, 0, 0);
          },
          [window](const std::string&, const std::string&,
                   const flutter::EncodableValue*) {
            PostMessage(window, kQuitReady, 0, 0);
          },
          [window]() { PostMessage(window, kQuitReady, 0, 0); }));
}

void FlutterWindow::InstallTrayIcon() {
  tray_icon_.cbSize = sizeof(NOTIFYICONDATA);
  tray_icon_.hWnd = GetHandle();
  tray_icon_.uID = 1;
  tray_icon_.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  tray_icon_.uCallbackMessage = kTrayMessage;
  tray_icon_.hIcon =
      LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));
  wcscpy_s(tray_icon_.szTip, L"Clash RS");
  Shell_NotifyIcon(NIM_ADD, &tray_icon_);
}

void FlutterWindow::RemoveTrayIcon() {
  if (tray_icon_.hWnd != nullptr) Shell_NotifyIcon(NIM_DELETE, &tray_icon_);
  tray_icon_.hWnd = nullptr;
}

void FlutterWindow::ShowTrayMenu() {
  POINT cursor{};
  GetCursorPos(&cursor);
  HMENU menu = CreatePopupMenu();
  AppendMenu(menu, MF_STRING, kTrayShow, L"显示 Clash RS");
  AppendMenu(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenu(menu, MF_STRING, kTrayQuit, L"退出 Clash RS");
  SetForegroundWindow(GetHandle());
  TrackPopupMenu(menu, TPM_RIGHTBUTTON | TPM_BOTTOMALIGN, cursor.x, cursor.y,
                 0, GetHandle(), nullptr);
  DestroyMenu(menu);
}
