#ifndef RUNNER_AUTOSTART_H_
#define RUNNER_AUTOSTART_H_

// HKCU Run key + StartupApproved. Prefers khmer-calendar-bg.exe when present.
bool KhmerAutostartEnable();
bool KhmerAutostartDisable();
bool KhmerAutostartIsEnabled();
// Start the background helper (or main --autostart) if not already running.
bool KhmerAutostartEnsureRunning();

#endif  // RUNNER_AUTOSTART_H_
