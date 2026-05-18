/// 训练目标模式(原型 ③ 训练目标设置的 6 种单选)。
enum TrainingMode { free, distance, time, calorie, interval, pace }

extension TrainingModeX on TrainingMode {
  /// 与原型一致的中文短名(也用于「开始训练 · {名} {档}」按钮文案)。
  String get label => switch (this) {
        TrainingMode.free => '自由划',
        TrainingMode.distance => '定距',
        TrainingMode.time => '定时',
        TrainingMode.calorie => '定卡',
        TrainingMode.interval => '间歇',
        TrainingMode.pace => '配速',
      };

  String get title => switch (this) {
        TrainingMode.free => '自由划',
        TrainingMode.distance => '定距',
        TrainingMode.time => '定时',
        TrainingMode.calorie => '定卡',
        TrainingMode.interval => '间歇训练',
        TrainingMode.pace => '目标配速',
      };

  String get subtitle => switch (this) {
        TrainingMode.free => '不设目标,拉了就记',
        TrainingMode.distance => '划满设定距离自动结束',
        TrainingMode.time => '划满设定时间自动结束',
        TrainingMode.calorie => '烧完目标卡路里结束',
        TrainingMode.interval => '分组间歇 · 组间休息',
        TrainingMode.pace => '配速船 · 跟目标配速划',
      };

  static TrainingMode fromName(String n) =>
      TrainingMode.values.firstWhere((e) => e.name == n,
          orElse: () => TrainingMode.free);
}

/// 一次训练选定的目标:模式 + 可选的目标档位(展示用文案 + 归一化数值)。
class TrainingGoal {
  final TrainingMode mode;

  /// 目标档位展示文案,如 "2000 m" / "20 min" / "100 kcal";自由划为 null。
  final String? targetLabel;

  /// 归一化目标量(便于"达成"判定):定距=米、定时=秒、定卡=kcal;
  /// 自由划/无目标为 null。
  final double? targetValue;

  const TrainingGoal({required this.mode, this.targetLabel, this.targetValue});

  const TrainingGoal.free() : this(mode: TrainingMode.free);

  String get startButtonLabel => targetLabel == null
      ? '开始训练 · ${mode.label}'
      : '开始训练 · ${mode.label} $targetLabel';

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'targetLabel': targetLabel,
        'targetValue': targetValue,
      };

  factory TrainingGoal.fromJson(Map<String, dynamic> j) => TrainingGoal(
        mode: TrainingModeX.fromName(j['mode'] as String? ?? 'free'),
        targetLabel: j['targetLabel'] as String?,
        targetValue: (j['targetValue'] as num?)?.toDouble(),
      );
}
