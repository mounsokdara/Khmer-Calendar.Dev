#include "flutter_window.h"

#include <optional>

#include <flutter/standard_method_codec.h>

#include "autostart.h"
#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

void FlutterWindow::RegisterAutostartChannel() {
  autostart_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "khmer.autostart",
          &flutter::StandardMethodCodec::GetInstance());
  autostart_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        const std::string& method = call.method_name();
        if (method == "enable") {
          result->Success(flutter::EncodableValue(KhmerAutostartEnable()));
        } else if (method == "disable") {
          result->Success(flutter::EncodableValue(KhmerAutostartDisable()));
        } else if (method == "isEnabled") {
          result->Success(flutter::EncodableValue(KhmerAutostartIsEnabled()));
        } else if (method == "ensureRunning") {
          result->Success(
              flutter::EncodableValue(KhmerAutostartEnsureRunning()));
        } else {
          result->NotImplemented();
        }
      });
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  RegisterAutostartChannel();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  if (background_) {
    ShowWindow(GetHandle(), SW_HIDE);
  } else {
    flutter_controller_->engine()->SetNextFrameCallback([&]() {
      this->Show();
    });
    flutter_controller_->ForceRedraw();
  }

  return true;
}

void FlutterWindow::OnDestroy() {
  autostart_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
