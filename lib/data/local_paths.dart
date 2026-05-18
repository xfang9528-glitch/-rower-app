import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 应用数据根目录。**关键**:必须在 build 目录之外 —— 开发期每次重编都
/// `rm -rf build/windows`,旧方案(exe 同目录)会连记录一起删掉。
///
/// - Windows: `%APPDATA%\com.xfang\rower_app\`(getApplicationSupportDirectory)
/// - Android: app sandbox 内部存储(随应用,卸载才清)
class LocalPaths {
  static Directory? _root;

  static Future<Directory> root() async {
    if (_root != null) return _root!;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}rower_app');
    if (!await dir.exists()) await dir.create(recursive: true);
    _root = dir;
    return dir;
  }

  static Future<File> file(String name) async {
    final r = await root();
    return File('${r.path}${Platform.pathSeparator}$name');
  }

  static Future<Directory> subdir(String name) async {
    final r = await root();
    final d = Directory('${r.path}${Platform.pathSeparator}$name');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }
}
