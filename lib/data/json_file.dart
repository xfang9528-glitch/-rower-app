import 'dart:convert';
import 'dart:io';

/// 原子 JSON 读写。直接 `writeAsString` 覆盖活文件:进程写一半挂掉/磁盘
/// 满 → 文件损坏 → 下次解析失败被吞 → 紧接着一次 add() 即以"只剩一条"
/// 覆盖,**该用户全部历史无声永久丢失**。这里用 临时文件 + rename 替换,
/// 并保留 .bak;损坏时把坏文件改名留证并回滚 .bak。
class JsonFile {
  /// 临时文件写满 flush,再原子替换;旧文件留为 .bak(可回滚)。
  static Future<void> writeAtomic(File f, Object data) async {
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    if (await f.exists()) {
      final bak = File('${f.path}.bak');
      // Windows 的 rename 不能覆盖已存在目标,先清 .bak。
      if (await bak.exists()) {
        try {
          await bak.delete();
        } catch (_) {}
      }
      try {
        await f.rename(bak.path);
      } catch (_) {
        // 留不成 .bak 不致命,继续替换。
      }
    }
    await tmp.rename(f.path);
  }

  /// 读并解析为 Map。损坏 → 坏文件改名 `*.corrupt.<ts>` 留证,尝试 .bak
  /// 回滚;都不行返回 null(调用方据此走"无数据",但原始数据已留存可恢复)。
  static Future<Map<String, dynamic>?> readMap(File f) async {
    if (!await f.exists()) return null;
    try {
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      try {
        await f.rename(
            '${f.path}.corrupt.${DateTime.now().millisecondsSinceEpoch}');
      } catch (_) {}
      final bak = File('${f.path}.bak');
      if (await bak.exists()) {
        try {
          final m = jsonDecode(await bak.readAsString());
          if (m is Map<String, dynamic>) return m;
        } catch (_) {}
      }
      return null;
    }
  }
}
