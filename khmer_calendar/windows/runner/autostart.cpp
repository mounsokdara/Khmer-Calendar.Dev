#include "autostart.h"

#include <objbase.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <windows.h>

#include <string>

namespace {

constexpr wchar_t kRunKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kApprovedKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\StartupApproved\\Run";
constexpr wchar_t kApprovedFolderKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\StartupApproved\\StartupFolder";
constexpr wchar_t kValueName[] = L"KhmerCalendar";
constexpr wchar_t kShortcutName[] = L"Khmer Calendar.lnk";
constexpr wchar_t kBgExeName[] = L"khmer-calendar-bg.exe";

std::wstring ExePath() {
  wchar_t buf[MAX_PATH] = {};
  DWORD n = GetModuleFileNameW(nullptr, buf, MAX_PATH);
  if (n == 0 || n >= MAX_PATH) {
    return std::wstring();
  }
  return std::wstring(buf);
}

std::wstring DirOf(const std::wstring& path) {
  size_t slash = path.find_last_of(L"\\/");
  if (slash == std::wstring::npos) {
    return std::wstring();
  }
  return path.substr(0, slash);
}

// Prefer dedicated background executable; fall back to main.exe --autostart.
std::wstring BackgroundCommand() {
  std::wstring exe = ExePath();
  if (exe.empty()) {
    return std::wstring();
  }
  std::wstring dir = DirOf(exe);
  std::wstring bg = dir + L"\\" + kBgExeName;
  if (GetFileAttributesW(bg.c_str()) != INVALID_FILE_ATTRIBUTES) {
    return L"\"" + bg + L"\"";
  }
  return L"\"" + exe + L"\" --autostart";
}

bool WriteSz(HKEY root, const wchar_t* subkey, const wchar_t* name,
             const std::wstring& value) {
  HKEY key = nullptr;
  LONG st = RegCreateKeyExW(root, subkey, 0, nullptr, 0, KEY_SET_VALUE,
                            nullptr, &key, nullptr);
  if (st != ERROR_SUCCESS) {
    return false;
  }
  const BYTE* data = reinterpret_cast<const BYTE*>(value.c_str());
  DWORD bytes =
      static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t));
  st = RegSetValueExW(key, name, 0, REG_SZ, data, bytes);
  RegCloseKey(key);
  return st == ERROR_SUCCESS;
}

bool DeleteValue(HKEY root, const wchar_t* subkey, const wchar_t* name) {
  HKEY key = nullptr;
  LONG st = RegOpenKeyExW(root, subkey, 0, KEY_SET_VALUE, &key);
  if (st != ERROR_SUCCESS) {
    return true;
  }
  RegDeleteValueW(key, name);
  RegCloseKey(key);
  return true;
}

bool ReadSz(HKEY root, const wchar_t* subkey, const wchar_t* name,
            std::wstring* out) {
  HKEY key = nullptr;
  LONG st = RegOpenKeyExW(root, subkey, 0, KEY_QUERY_VALUE, &key);
  if (st != ERROR_SUCCESS) {
    return false;
  }
  DWORD type = 0;
  DWORD bytes = 0;
  st = RegQueryValueExW(key, name, nullptr, &type, nullptr, &bytes);
  if (st != ERROR_SUCCESS || type != REG_SZ || bytes < sizeof(wchar_t)) {
    RegCloseKey(key);
    return false;
  }
  std::wstring buf(bytes / sizeof(wchar_t), L'\0');
  st = RegQueryValueExW(key, name, nullptr, &type,
                        reinterpret_cast<BYTE*>(buf.data()), &bytes);
  RegCloseKey(key);
  if (st != ERROR_SUCCESS) {
    return false;
  }
  if (!buf.empty() && buf.back() == L'\0') {
    buf.pop_back();
  }
  *out = buf;
  return true;
}

bool ApprovedEnabled(HKEY root, const wchar_t* subkey, const wchar_t* name) {
  HKEY key = nullptr;
  LONG st = RegOpenKeyExW(root, subkey, 0, KEY_QUERY_VALUE, &key);
  if (st != ERROR_SUCCESS) {
    return true;
  }
  BYTE data[16] = {};
  DWORD type = 0;
  DWORD bytes = sizeof(data);
  st = RegQueryValueExW(key, name, nullptr, &type, data, &bytes);
  RegCloseKey(key);
  if (st != ERROR_SUCCESS || bytes == 0) {
    return true;
  }
  return (data[0] & 0x01) == 0;
}

bool WriteApprovedEnabled(HKEY root, const wchar_t* subkey,
                          const wchar_t* name) {
  HKEY key = nullptr;
  LONG st = RegCreateKeyExW(root, subkey, 0, nullptr, 0, KEY_SET_VALUE,
                            nullptr, &key, nullptr);
  if (st != ERROR_SUCCESS) {
    return false;
  }
  BYTE data[12] = {0x02, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
  st = RegSetValueExW(key, name, 0, REG_BINARY, data, sizeof(data));
  RegCloseKey(key);
  return st == ERROR_SUCCESS;
}

std::wstring StartupFolder() {
  PWSTR path = nullptr;
  HRESULT hr = SHGetKnownFolderPath(FOLDERID_Startup, 0, nullptr, &path);
  if (FAILED(hr) || path == nullptr) {
    return std::wstring();
  }
  std::wstring out(path);
  CoTaskMemFree(path);
  return out;
}

std::wstring ShortcutPath() {
  std::wstring dir = StartupFolder();
  if (dir.empty()) {
    return std::wstring();
  }
  if (dir.back() != L'\\' && dir.back() != L'/') {
    dir.push_back(L'\\');
  }
  dir.append(kShortcutName);
  return dir;
}

bool RemoveShortcut() {
  std::wstring dest = ShortcutPath();
  if (dest.empty()) {
    return true;
  }
  if (GetFileAttributesW(dest.c_str()) == INVALID_FILE_ATTRIBUTES) {
    return true;
  }
  return DeleteFileW(dest.c_str()) != 0;
}

bool ShortcutExists() {
  std::wstring dest = ShortcutPath();
  if (dest.empty()) {
    return false;
  }
  return GetFileAttributesW(dest.c_str()) != INVALID_FILE_ATTRIBUTES;
}

}  // namespace

bool KhmerAutostartEnable() {
  std::wstring cmd = BackgroundCommand();
  if (cmd.empty()) {
    return false;
  }
  bool run = WriteSz(HKEY_CURRENT_USER, kRunKey, kValueName, cmd);
  WriteApprovedEnabled(HKEY_CURRENT_USER, kApprovedKey, kValueName);
  RemoveShortcut();
  DeleteValue(HKEY_CURRENT_USER, kApprovedFolderKey, kShortcutName);
  return run;
}

bool KhmerAutostartDisable() {
  DeleteValue(HKEY_CURRENT_USER, kRunKey, kValueName);
  DeleteValue(HKEY_CURRENT_USER, kApprovedKey, kValueName);
  DeleteValue(HKEY_CURRENT_USER, kApprovedFolderKey, kShortcutName);
  RemoveShortcut();
  return !KhmerAutostartIsEnabled();
}

bool KhmerAutostartIsEnabled() {
  std::wstring value;
  bool run = ReadSz(HKEY_CURRENT_USER, kRunKey, kValueName, &value);
  if (run && !value.empty() &&
      ApprovedEnabled(HKEY_CURRENT_USER, kApprovedKey, kValueName)) {
    return true;
  }
  if (ShortcutExists() &&
      ApprovedEnabled(HKEY_CURRENT_USER, kApprovedFolderKey, kShortcutName)) {
    return true;
  }
  return false;
}
