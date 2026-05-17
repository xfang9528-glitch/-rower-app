import '../models/workout.dart';

/// 云同步接缝(PRD §4.5:本地优先,但数据层须预留"上传/云端同步"接口,
/// 不写死)。当前默认 [NoopSyncBackend] —— 全部本地、离线可用。将来接云
/// 端只需实现这个接口并在 AppData 注入,store 调用点已就位。
abstract class SyncBackend {
  /// 一条训练落盘后触发(fire-and-forget,失败不影响本地)。
  Future<void> onWorkoutSaved(Workout w);

  /// 一条训练删除后触发。
  Future<void> onWorkoutDeleted(String workoutId);

  /// 主动全量上推(将来"立即同步"按钮用)。
  Future<void> pushAll(List<Workout> all);
}

class NoopSyncBackend implements SyncBackend {
  const NoopSyncBackend();
  @override
  Future<void> onWorkoutSaved(Workout w) async {}
  @override
  Future<void> onWorkoutDeleted(String workoutId) async {}
  @override
  Future<void> pushAll(List<Workout> all) async {}
}
