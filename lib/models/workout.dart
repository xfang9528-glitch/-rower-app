import 'training_goal.dart';

/// 每 500m 一段(原型 ④/⑤ 的分段表)。最后一段可能不足 500m。
class Split {
  final int index; // 1-based
  final double distanceM; // 本段距离(通常 500,末段可能更短)
  final int durationSec; // 本段用时
  final double avgSpm;
  final double avgPower;
  final int? avgHr;

  const Split({
    required this.index,
    required this.distanceM,
    required this.durationSec,
    required this.avgSpm,
    required this.avgPower,
    this.avgHr,
  });

  /// 配速 = 每 500m 秒数(用本段距离归一化,末段不足 500m 也可比)。
  Duration get pace500 => distanceM <= 0
      ? Duration.zero
      : Duration(milliseconds: (durationSec / distanceM * 500 * 1000).round());

  Map<String, dynamic> toJson() => {
        'index': index,
        'distanceM': distanceM,
        'durationSec': durationSec,
        'avgSpm': avgSpm,
        'avgPower': avgPower,
        'avgHr': avgHr,
      };

  factory Split.fromJson(Map<String, dynamic> j) => Split(
        index: j['index'] as int,
        distanceM: (j['distanceM'] as num).toDouble(),
        durationSec: j['durationSec'] as int,
        avgSpm: (j['avgSpm'] as num).toDouble(),
        avgPower: (j['avgPower'] as num).toDouble(),
        avgHr: j['avgHr'] as int?,
      );
}

/// 一次训练记录。本地优先:整条以 JSON 存,字段即为同步契约。
///
/// 数据自洽不变量(PRD §4.3):同一次训练在仪表盘/详情/列表/分段/原始
/// 日志间数字一致 —— 因此这里存的是「定稿快照」,由 WorkoutRecorder 在
/// 训练结束时一次性写出,不再二次推算。
class Workout {
  final String id;
  final String userId;
  final DateTime startTime;
  final int durationSec; // 墙钟时长(连接成功后从 0,含停桨休息)

  final TrainingGoal goal;
  final bool goalAchieved; // 定距/定时/定卡是否达成(自由划恒 false 无意义)

  final double distanceM;
  final int strokes;
  final int pulses; // 会话累计脉冲(自洽校验/调试)

  final double avgSpeed; // m/s,平均(距离/时长),配速由此派生
  final double avgSpm;
  final double avgPower;
  final double peakPower;
  final double calories; // 无参照估算值

  final int? avgHr; // 心率可缺失
  final int? peakHr;
  final bool hrPartial; // 心率中途掉线 → 本次标记部分缺失

  final List<Split> splits;

  /// 轻量采样曲线(详情页配速/心率曲线)。配速曲线存"每 500m 秒数",
  /// 心率曲线存 bpm;按固定间隔采样,控制体积。
  final List<int> paceSeries; // sec/500m 采样点
  final List<int> hrSeries; // bpm 采样点(可空)

  const Workout({
    required this.id,
    required this.userId,
    required this.startTime,
    required this.durationSec,
    required this.goal,
    required this.goalAchieved,
    required this.distanceM,
    required this.strokes,
    required this.pulses,
    required this.avgSpeed,
    required this.avgSpm,
    required this.avgPower,
    required this.peakPower,
    required this.calories,
    this.avgHr,
    this.peakHr,
    this.hrPartial = false,
    this.splits = const [],
    this.paceSeries = const [],
    this.hrSeries = const [],
  });

  Workout copyWith({String? userId}) => Workout(
        id: id,
        userId: userId ?? this.userId,
        startTime: startTime,
        durationSec: durationSec,
        goal: goal,
        goalAchieved: goalAchieved,
        distanceM: distanceM,
        strokes: strokes,
        pulses: pulses,
        avgSpeed: avgSpeed,
        avgSpm: avgSpm,
        avgPower: avgPower,
        peakPower: peakPower,
        calories: calories,
        avgHr: avgHr,
        peakHr: peakHr,
        hrPartial: hrPartial,
        splits: splits,
        paceSeries: paceSeries,
        hrSeries: hrSeries,
      );

  /// 平均配速:每 500m 秒数。avgSpeed<=0 时为 null(展示成 "—")。
  Duration? get avgPace500 => avgSpeed <= 0.05
      ? null
      : Duration(milliseconds: (500 / avgSpeed * 1000).round());

  Map<String, dynamic> toJson() => {
        'v': 1,
        'id': id,
        'userId': userId,
        'startTime': startTime.toIso8601String(),
        'durationSec': durationSec,
        'goal': goal.toJson(),
        'goalAchieved': goalAchieved,
        'distanceM': distanceM,
        'strokes': strokes,
        'pulses': pulses,
        'avgSpeed': avgSpeed,
        'avgSpm': avgSpm,
        'avgPower': avgPower,
        'peakPower': peakPower,
        'calories': calories,
        'avgHr': avgHr,
        'peakHr': peakHr,
        'hrPartial': hrPartial,
        'splits': splits.map((s) => s.toJson()).toList(),
        'paceSeries': paceSeries,
        'hrSeries': hrSeries,
      };

  factory Workout.fromJson(Map<String, dynamic> j) => Workout(
        id: j['id'] as String,
        userId: j['userId'] as String? ?? 'default',
        startTime: DateTime.parse(j['startTime'] as String),
        durationSec: j['durationSec'] as int,
        goal: TrainingGoal.fromJson(
            (j['goal'] as Map?)?.cast<String, dynamic>() ?? const {}),
        goalAchieved: j['goalAchieved'] as bool? ?? false,
        distanceM: (j['distanceM'] as num).toDouble(),
        strokes: j['strokes'] as int,
        pulses: j['pulses'] as int? ?? 0,
        avgSpeed: (j['avgSpeed'] as num?)?.toDouble() ?? 0,
        avgSpm: (j['avgSpm'] as num).toDouble(),
        avgPower: (j['avgPower'] as num).toDouble(),
        peakPower: (j['peakPower'] as num).toDouble(),
        calories: (j['calories'] as num).toDouble(),
        avgHr: j['avgHr'] as int?,
        peakHr: j['peakHr'] as int?,
        hrPartial: j['hrPartial'] as bool? ?? false,
        splits: ((j['splits'] as List?) ?? const [])
            .map((e) => Split.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        paceSeries: ((j['paceSeries'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
        hrSeries: ((j['hrSeries'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
      );
}
