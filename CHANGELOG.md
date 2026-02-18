# Changelog

## v2.3.0 — Deep Code Audit Release

### Crash & Runtime Safety
- Fixed pipe deadlock in `loadTopProcesses()` — read data before `waitUntilExit()` using `readDataToEndOfFile()`
- Added timeout semaphores to ALL external Process calls across the entire codebase to prevent indefinite hangs:
  - `FeatureManager`: `calculateDirectorySize()` (5s), `cleanRAM()` memory_pressure (10s)
  - `HardwareIntegrityManager`: `runSystemProfiler()` (10s)
  - `DiskHealthManager`: `getDiskInfo()` (5s), `getDetailedDiskInfo()` (5s), `getSMARTData()` (10s)
  - `SystemReportManager`: `getBatteryInfo()` (5s), `getNetworkInfo()` (5s), `getTopProcesses()` (5s)
  - `SmartCleanManager`: `calculateSize()` (5s)
- Replaced all deprecated `Process.launchPath` with `Process.executableURL` (macOS 14+ compatibility)

### Logic & Data Integrity
- Changed `CacheManager.cleanTempFiles()` and `deleteContentsOfDirectory()` from permanent deletion (`removeItem`) to recoverable trash (`trashItem`)
- Fixed hardcoded app version "2.0.0" in `FeedbackManager` — now reads dynamically from `Bundle.main`
- Set `LSUIElement = true` in Info.plist (menu bar app should not appear in Dock)
- Removed all fake `Thread.sleep()` delays from `HardwareIntegrityManager.performScan()` (10 calls removed)

### Performance & Memory
- Fixed Mach port leak: added `deinit` with `mach_port_deallocate()` to `SystemMonitor`, `FeatureManager`, and `SystemReportManager`
- Removed dead code: deleted unused `createAppInfo()` method from `AppManager` (replaced by `createAppInfoFast()`)

### Security
- Audited all shell command execution for injection vulnerabilities — all clean
- Verified all `@Published` property updates are dispatched to main thread
- No hardcoded secrets, API keys, or credentials found

## v2.2.0

- Previous release
