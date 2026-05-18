import '../models/workout.dart';
import 'fmt.dart';

/// 训练记录聚合(本周汇总、每周距离、配速趋势、连续打卡、个人最佳)。
/// 纯函数,输入当前用户的记录列表(按时间倒序)。
class WorkoutStats {
  final List<Workout> all;
  WorkoutStats(this.all);

  // ---- 汇总 ----
  int get count => all.length;
  double get totalDistanceM =>
      all.fold(0.0, (s, w) => s + w.distanceM);
  int get totalDurationSec => all.fold(0, (s, w) => s + w.durationSec);

  DateTime get _weekStart {
    final n = DateTime.now();
    final d = DateTime(n.year, n.month, n.day);
    return d.subtract(Duration(days: d.weekday - 1)); // 本周一 00:00
  }

  List<Workout> get thisWeek =>
      all.where((w) => !w.startTime.isBefore(_weekStart)).toList();

  ({int count, double distM, int durSec}) get weekSummary {
    final ws = thisWeek;
    return (
      count: ws.length,
      distM: ws.fold(0.0, (s, w) => s + w.distanceM),
      durSec: ws.fold(0, (s, w) => s + w.durationSec),
    );
  }

  // ---- 每周距离(近 N 周,含本周)----
  List<({String label, double km})> weeklyDistance({int weeks = 8}) {
    final ws = _weekStart;
    final out = <({String label, double km})>[];
    for (var i = weeks - 1; i >= 0; i--) {
      final start = ws.subtract(Duration(days: 7 * i));
      final end = start.add(const Duration(days: 7));
      final km = all
              .where((w) =>
                  !w.startTime.isBefore(start) && w.startTime.isBefore(end))
              .fold(0.0, (s, w) => s + w.distanceM) /
          1000.0;
      out.add((label: i == 0 ? '本周' : 'W${weeks - i}', km: km));
    }
    return out;
  }

  /// 每周平均配速(秒/500m),用于趋势曲线;无记录的周为 0(图里跳过)。
  List<int> weeklyAvgPace({int weeks = 8}) {
    final ws = _weekStart;
    final out = <int>[];
    for (var i = weeks - 1; i >= 0; i--) {
      final start = ws.subtract(Duration(days: 7 * i));
      final end = start.add(const Duration(days: 7));
      final wk = all
          .where((w) =>
              !w.startTime.isBefore(start) &&
              w.startTime.isBefore(end) &&
              w.avgSpeed > 0.05)
          .toList();
      if (wk.isEmpty) {
        out.add(0);
      } else {
        final avg = wk
                .map((w) => 500 / w.avgSpeed)
                .reduce((a, b) => a + b) /
            wk.length;
        out.add(avg.round());
      }
    }
    return out;
  }

  // ---- 连续打卡 ----
  ({int current, int longest}) get streak {
    if (all.isEmpty) return (current: 0, longest: 0);
    final days = all
        .map((w) =>
            DateTime(w.startTime.year, w.startTime.month, w.startTime.day))
        .toSet()
        .toList()
      ..sort();
    int longest = 1, run = 1;
    for (var i = 1; i < days.length; i++) {
      if (days[i].difference(days[i - 1]).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > longest) longest = run;
    }
    // 当前:从今天或昨天往前连续
    final today = DateTime.now();
    final t0 = DateTime(today.year, today.month, today.day);
    int current = 0;
    var cursor = days.contains(t0)
        ? t0
        : (days.contains(t0.subtract(const Duration(days: 1)))
            ? t0.subtract(const Duration(days: 1))
            : null);
    if (cursor != null) {
      final set = days.toSet();
      while (set.contains(cursor)) {
        current++;
        cursor = cursor!.subtract(const Duration(days: 1));
      }
    }
    return (current: current, longest: longest);
  }

  // ---- 个人最佳(PR)----
  /// 某标准距离的最佳"投影用时"= 在覆盖该距离的训练里,按各自均速
  /// 推算划该距离需时,取最小。划船机无绝对参照,这是自洽的可比口径。
  String prFor(double meters) {
    final cands = all.where((w) => w.distanceM >= meters && w.avgSpeed > 0.05);
    if (cands.isEmpty) return '—';
    final best = cands
        .map((w) => meters / w.avgSpeed)
        .reduce((a, b) => a < b ? a : b);
    return Fmt.dur(best.round());
  }

  ({String value, DateTime? date}) get longestDistance {
    if (all.isEmpty) return (value: '—', date: null);
    final w = all.reduce((a, b) => a.distanceM >= b.distanceM ? a : b);
    return (value: '${Fmt.dist(w.distanceM)} m', date: w.startTime);
  }

  ({String value, DateTime? date}) get longestDuration {
    if (all.isEmpty) return (value: '—', date: null);
    final w = all.reduce((a, b) => a.durationSec >= b.durationSec ? a : b);
    return (value: Fmt.dur(w.durationSec), date: w.startTime);
  }

  /// 按日历日分组(已按时间倒序),用于列表分组展示。
  List<({DateTime day, List<Workout> items})> groupedByDay() {
    final out = <({DateTime day, List<Workout> items})>[];
    for (final w in all) {
      final d =
          DateTime(w.startTime.year, w.startTime.month, w.startTime.day);
      if (out.isNotEmpty && Fmt.sameDay(out.last.day, d)) {
        out.last.items.add(w);
      } else {
        out.add((day: d, items: [w]));
      }
    }
    return out;
  }
}
