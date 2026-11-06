#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {

bool HasAutostartArg(const std::vector<std::string>& args) {
  for (const auto& a : args) {
    if (a == "--autostart" || a == "--background") {
      return true;
    }
  }
  return false;
}

// One background instance at a time. A second --autostart exit immediately.
// A normal (UI) launch can still start; the mutex is only for background.
HANDLE g_bg_mutex = nullptr;

bool AcquireBackgroundMutex() {
  g_bg_mutex = CreateMutexW(nullptr, TRUE, L"Local\\KhmerCalendar.Background");
  if (g_bg_mutex == nullptr) {
    return false;
  }
  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    CloseHandle(g_bg_mutex);
    g_bg_mutex = nullptr;
    return false;
  }
  return true;
}

void ReleaseBackgroundMutex() {
  if (g_bg_mutex != nullptr) {
    ReleaseMutex(g_bg_mutex);
    CloseHandle(g_bg_mutex);
    g_bg_mutex = nullptr;
  }
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  const bool background = HasAutostartArg(command_line_arguments);

  if (background) {
    if (!AcquireBackgroundMutex()) {
      // Already running as background service — do not start a second copy.
      ::CoUninitialize();
      return EXIT_SUCCESS;
    }
  }

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  window.SetBackgroundMode(background);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(background ? 1 : 1280, background ? 1 : 720);
  if (!window.Create(L"Khmer Calendar", origin, size)) {
    ReleaseBackgroundMutex();
    ::CoUninitialize();
    return EXIT_FAILURE;
  }
  // Background service must not quit when the hidden window is destroyed by the OS.
  window.SetQuitOnClose(!background);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ReleaseBackgroundMutex();
  ::CoUninitialize();
  return EXIT_SUCCESS;
}
