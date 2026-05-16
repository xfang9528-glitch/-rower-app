import 'dart:convert';
import 'dart:io';

/// 记住上次连接成功的划船机,下次直接连,不用再扫一堆蓝牙设备。
/// 存到 exe 同目录的 paired_device.json(与日志同路径策略,免引入插件)。
class PairedStore {
  static String _file() {
    final exe = Platform.resolvedExecutable;
    final i = exe.lastIndexOf(Platform.pathSeparator);
    final dir = i < 0 ? Directory.current.path : exe.substring(0, i);
    return '$dir${Platform.pathSeparator}paired_device.json';
  }

  static ({String id, String name})? load() {
    try {
      final f = File(_file());
      if (!f.existsSync()) return null;
      final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final id = j['id'] as String?;
      if (id == null || id.isEmpty) return null;
      return (id: id, name: (j['name'] as String?) ?? '');
    } catch (_) {
      return null;
    }
  }

  static void save(String id, String name) {
    try {
      File(_file()).writeAsStringSync(jsonEncode({'id': id, 'name': name}));
    } catch (_) {}
  }

  static void clear() {
    try {
      final f = File(_file());
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }
}
