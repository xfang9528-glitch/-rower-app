import 'dart:io';

/// Single shared capture log written next to the executable so Claude can read
/// it directly (path: `<exe dir>/ble_live.log`). Used by both the scan screen
/// (so we can see why auto-connect stalls) and the device screen (GATT + data).
class SessionLog {
  static String? _path;
  static bool _truncatedThisRun = false;

  static String get path => _path ?? '(未初始化)';
  static bool get started => _path != null;

  static String _dir() {
    final exe = Platform.resolvedExecutable;
    final i = exe.lastIndexOf(Platform.pathSeparator);
    return i < 0 ? Directory.current.path : exe.substring(0, i);
  }

  /// Initialize the log path. Truncates the file only ONCE per app launch;
  /// later calls (scan retry / BLE reconnect) only append a marker so a
  /// capture is never destroyed by a mid-session reconnect.
  static void start(String header) {
    try {
      _path = '${_dir()}${Platform.pathSeparator}ble_live.log';
      if (!_truncatedThisRun) {
        File(_path!).writeAsStringSync(
          '# 小莫划船机 BLE 实时抓包\n$header\n会话开始: ${DateTime.now()}\n\n',
        );
        _truncatedThisRun = true;
      } else {
        line('\n--- 重新开始 ($header) @ ${DateTime.now()} ---');
      }
    } catch (_) {
      _path = null;
    }
  }

  /// Append a line (best-effort, flushed so it survives a crash/kill).
  static void line(String s) {
    final p = _path;
    if (p == null) return;
    try {
      File(p).writeAsStringSync('$s\n', mode: FileMode.append, flush: true);
    } catch (_) {}
  }
}
