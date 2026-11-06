#include "autostart.h"

#include <glib.h>
#include <glib/gstdio.h>
#include <unistd.h>

#include <string>

namespace {

constexpr const char kDesktopId[] = "com.mounsokdara.khmercalendar.desktop";
constexpr const char kBgName[] = "khmer-calendar-bg";

std::string ExePath() {
  char buf[4096];
  ssize_t n = readlink("/proc/self/exe", buf, sizeof(buf) - 1);
  if (n <= 0) {
    return std::string();
  }
  buf[n] = '\0';
  return std::string(buf);
}

std::string DirOf(const std::string& path) {
  size_t slash = path.find_last_of('/');
  if (slash == std::string::npos) {
    return std::string();
  }
  return path.substr(0, slash);
}

std::string BackgroundExec() {
  std::string exe = ExePath();
  if (exe.empty()) {
    return std::string();
  }
  std::string dir = DirOf(exe);
  std::string bg = dir + "/" + kBgName;
  if (g_file_test(bg.c_str(), G_FILE_TEST_IS_EXECUTABLE)) {
    return bg;
  }
  return exe + " --autostart";
}

std::string DesktopPath() {
  const char* dir = g_get_user_config_dir();
  if (dir == nullptr || dir[0] == '\0') {
    return std::string();
  }
  gchar* path = g_build_filename(dir, "autostart", kDesktopId, nullptr);
  std::string out(path);
  g_free(path);
  return out;
}

bool WriteDesktop() {
  std::string exec_line = BackgroundExec();
  std::string dest = DesktopPath();
  if (exec_line.empty() || dest.empty()) {
    return false;
  }
  gchar* folder = g_path_get_dirname(dest.c_str());
  g_mkdir_with_parents(folder, 0755);
  g_free(folder);

  std::string try_exec = exec_line;
  size_t space = try_exec.find(' ');
  if (space != std::string::npos) {
    try_exec.resize(space);
  }

  g_autoptr(GKeyFile) kf = g_key_file_new();
  g_key_file_set_string(kf, "Desktop Entry", "Type", "Application");
  g_key_file_set_string(kf, "Desktop Entry", "Version", "1.0");
  g_key_file_set_string(kf, "Desktop Entry", "Name",
                        "Khmer Calendar Background");
  g_key_file_set_locale_string(kf, "Desktop Entry", "Name", "km",
                               "ប្រតិទិនខ្មែរ (ផ្ទៃខាងក្រោយ)");
  g_key_file_set_string(kf, "Desktop Entry", "Comment",
                        "Background reminders for Khmer Calendar");
  gchar* exec = nullptr;
  if (exec_line.find(' ') == std::string::npos) {
    exec = g_strdup_printf("\"%s\"", exec_line.c_str());
  } else {
    size_t sp = exec_line.find(' ');
    std::string bin = exec_line.substr(0, sp);
    exec = g_strdup_printf("\"%s\" --autostart", bin.c_str());
  }
  g_key_file_set_string(kf, "Desktop Entry", "Exec", exec);
  g_free(exec);
  g_key_file_set_string(kf, "Desktop Entry", "TryExec", try_exec.c_str());
  g_key_file_set_string(kf, "Desktop Entry", "Categories",
                        "Utility;Calendar;");
  g_key_file_set_boolean(kf, "Desktop Entry", "Terminal", FALSE);
  g_key_file_set_boolean(kf, "Desktop Entry", "StartupNotify", FALSE);
  g_key_file_set_boolean(kf, "Desktop Entry", "Hidden", FALSE);
  g_key_file_set_boolean(kf, "Desktop Entry", "NoDisplay", TRUE);
  g_key_file_set_boolean(kf, "Desktop Entry", "X-GNOME-Autostart-enabled",
                         TRUE);
  g_key_file_set_integer(kf, "Desktop Entry", "X-GNOME-Autostart-Delay", 2);

  g_autoptr(GError) error = nullptr;
  gboolean ok = g_key_file_save_to_file(kf, dest.c_str(), &error);
  if (!ok) {
    g_warning("autostart write failed: %s",
              error != nullptr ? error->message : "unknown");
  }
  return ok == TRUE;
}

bool RemoveDesktop() {
  std::string dest = DesktopPath();
  if (dest.empty()) {
    return true;
  }
  if (!g_file_test(dest.c_str(), G_FILE_TEST_EXISTS)) {
    return true;
  }
  return g_remove(dest.c_str()) == 0;
}

bool DesktopEnabled() {
  std::string dest = DesktopPath();
  if (dest.empty() || !g_file_test(dest.c_str(), G_FILE_TEST_IS_REGULAR)) {
    return false;
  }
  g_autoptr(GKeyFile) kf = g_key_file_new();
  g_autoptr(GError) error = nullptr;
  if (!g_key_file_load_from_file(kf, dest.c_str(), G_KEY_FILE_NONE, &error)) {
    return false;
  }
  if (g_key_file_get_boolean(kf, "Desktop Entry", "Hidden", nullptr)) {
    return false;
  }
  if (g_key_file_has_key(kf, "Desktop Entry", "X-GNOME-Autostart-enabled",
                         nullptr) &&
      !g_key_file_get_boolean(kf, "Desktop Entry",
                              "X-GNOME-Autostart-enabled", nullptr)) {
    return false;
  }
  return true;
}

bool EnsureRunning() {
  std::string exe = ExePath();
  if (exe.empty()) {
    return false;
  }
  std::string dir = DirOf(exe);
  std::string bg = dir + "/" + kBgName;
  gchar* argv[4] = {nullptr, nullptr, nullptr, nullptr};
  if (g_file_test(bg.c_str(), G_FILE_TEST_IS_EXECUTABLE)) {
    argv[0] = g_strdup(bg.c_str());
  } else {
    argv[0] = g_strdup(exe.c_str());
    argv[1] = g_strdup("--autostart");
  }
  g_autoptr(GError) error = nullptr;
  // Silence output so nothing attaches a terminal when we spawn the helper.
  gboolean ok = g_spawn_async(
      dir.c_str(), argv, nullptr,
      static_cast<GSpawnFlags>(G_SPAWN_DO_NOT_REAP_CHILD |
                               G_SPAWN_SEARCH_PATH |
                               G_SPAWN_STDOUT_TO_DEV_NULL |
                               G_SPAWN_STDERR_TO_DEV_NULL),
      nullptr, nullptr, nullptr, &error);
  for (int i = 0; argv[i] != nullptr; i++) {
    g_free(argv[i]);
  }
  if (!ok) {
    g_warning("ensureRunning failed: %s",
              error != nullptr ? error->message : "unknown");
  }
  return ok == TRUE;
}

void RespondBool(FlMethodCall* call, bool value) {
  g_autoptr(FlValue) v = fl_value_new_bool(value);
  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_success_response_new(v));
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(call, response, &error)) {
    g_warning("autostart reply failed: %s",
              error != nullptr ? error->message : "unknown");
  }
}

void MethodCb(FlMethodChannel* /*channel*/, FlMethodCall* call,
              gpointer /*data*/) {
  const gchar* method = fl_method_call_get_name(call);
  if (g_strcmp0(method, "enable") == 0) {
    RespondBool(call, WriteDesktop() && DesktopEnabled());
    return;
  }
  if (g_strcmp0(method, "disable") == 0) {
    RemoveDesktop();
    RespondBool(call, !DesktopEnabled());
    return;
  }
  if (g_strcmp0(method, "isEnabled") == 0) {
    RespondBool(call, DesktopEnabled());
    return;
  }
  if (g_strcmp0(method, "ensureRunning") == 0) {
    RespondBool(call, EnsureRunning());
    return;
  }
  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  fl_method_call_respond(call, response, nullptr);
}

}  // namespace

FlMethodChannel* khmer_autostart_channel_new(FlView* view) {
  FlEngine* engine = fl_view_get_engine(view);
  FlBinaryMessenger* messenger = fl_engine_get_binary_messenger(engine);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* channel = fl_method_channel_new(
      messenger, "khmer.autostart", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, MethodCb, nullptr,
                                            nullptr);
  return channel;
}
