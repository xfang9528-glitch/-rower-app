import 'dart:convert';
import 'dart:io';

import '../models/workout.dart';
import 'local_paths.dart';
import 'sync_backend.dart';

/// 每用户一个文件 `workouts/<userId>.json`(多用户记录隔离,PRD §4.5)。
/// 内存缓存当前用户的记录;落盘后触发同步接缝(默认 no-op)。
class WorkoutStore {
  final SyncBackend sync;
  WorkoutStore({this.sync = const NoopSyncBackend()});

  String? _userId;
  List<Workout> _cache = [];

  /// 当前用户记录,按开始时间倒序(最新在前)。
  List<Workout> get items => List.unmodifiable(_cache);

  Future<File> _fileFor(String userId) async {
    final dir = await LocalPaths.subdir('workouts');
    return File('${dir.path}${Platform.pathSeparator}$userId.json');
  }

  /// 切到某用户:载入其记录到缓存。切换用户后必须调用。
  Future<void> loadFor(String userId) async {
    _userId = userId;
    _cache = [];
    try {
      final f = await _fileFor(userId);
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        _cache = ((j['workouts'] as List?) ?? const [])
            .map((e) => Workout.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      }
    } catch (_) {
      _cache = [];
    }
    _sort();
  }

  /// 读某用户记录的汇总(不动当前缓存),切换用户页展示用。
  Future<({int count, double distM})> summaryFor(String userId) async {
    try {
      final f = await _fileFor(userId);
      if (!await f.exists()) return (count: 0, distM: 0.0);
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final list = ((j['workouts'] as List?) ?? const [])
          .map((e) => Workout.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      return (
        count: list.length,
        distM: list.fold(0.0, (s, w) => s + w.distanceM),
      );
    } catch (_) {
      return (count: 0, distM: 0.0);
    }
  }

  void _sort() =>
      _cache.sort((a, b) => b.startTime.compareTo(a.startTime));

  Future<void> add(Workout w) async {
    _cache = [..._cache, w];
    _sort();
    await _persist();
    sync.onWorkoutSaved(w); // fire-and-forget
  }

  Future<void> delete(String id) async {
    _cache = _cache.where((w) => w.id != id).toList();
    await _persist();
    sync.onWorkoutDeleted(id);
  }

  Future<void> _persist() async {
    final uid = _userId;
    if (uid == null) return;
    try {
      final f = await _fileFor(uid);
      await f.writeAsString(jsonEncode({
        'v': 1,
        'workouts': _cache.map((w) => w.toJson()).toList(),
      }));
    } catch (_) {}
  }
}
