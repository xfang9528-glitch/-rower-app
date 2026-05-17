import 'package:flutter/foundation.dart';

import 'data/settings_store.dart';
import 'data/user_store.dart';
import 'data/workout_store.dart';
import 'models/workout.dart';

/// 全局应用状态。本应用规模小,用单例 + ChangeNotifier 足够,不引入
/// provider/riverpod。屏幕用 `ListenableBuilder(listenable: appState)` 监听。
class AppState extends ChangeNotifier {
  final UserStore users = UserStore();
  final SettingsStore settings = SettingsStore();
  late final WorkoutStore workouts = WorkoutStore();

  bool ready = false;

  Future<void> init() async {
    await users.load();
    await settings.load();
    await workouts.loadFor(users.currentId);
    ready = true;
    notifyListeners();
  }

  Future<void> switchUser(String userId) async {
    await users.switchTo(userId);
    await workouts.loadFor(users.currentId);
    notifyListeners();
  }

  Future<void> addUser(String name) async {
    final u = await users.addUser(name);
    await switchUser(u.id);
  }

  /// 落盘一条训练(归属当前用户)。返回最终入库的记录。
  Future<Workout> saveWorkout(Workout w) async {
    final saved = w.copyWith(userId: users.currentId);
    await workouts.add(saved);
    notifyListeners();
    return saved;
  }

  Future<void> deleteWorkout(String id) async {
    await workouts.delete(id);
    notifyListeners();
  }

  Future<void> reloadWorkouts() async {
    await workouts.loadFor(users.currentId);
    notifyListeners();
  }

  /// 外部改了设置/记忆设备等,需要刷新监听该状态的屏。
  void refresh() => notifyListeners();
}

final AppState appState = AppState();
