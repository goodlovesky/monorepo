#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/method_result_functions.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <shellapi.h>

#include <memory>
#include <string>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void BeginQuit();
  void InstallTrayIcon();
  void RemoveTrayIcon();
  void ShowTrayMenu();

  static constexpr UINT kTrayMessage = WM_APP + 42;
  static constexpr UINT kTrayShow = 40001;
  static constexpr UINT kTrayQuit = 40002;
  static constexpr UINT kQuitReady = WM_APP + 43;
  static constexpr UINT_PTR kQuitTimer = 1;
  NOTIFYICONDATA tray_icon_{};
  bool close_to_tray_ = true;
  bool exiting_ = false;
  bool quit_cleanup_started_ = false;
  std::string tray_click_action_ = "show";

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      lifecycle_channel_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
