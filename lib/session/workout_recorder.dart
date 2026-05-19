import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ble/anytum_rower.dart';
import '../ble/rower_connection.dart';
import '../ble/rowing_metrics.dart';
import '../models/training_goal.dart';
import '../models/workout.dart';

/// 一次训练的录制器:把实时指标收敛成可落盘的 [Workout]。
///
/// 计时规则(PRD §4.1):连接成功后从 0 起 —— 锚点是本录制器创建时刻
/// (进入仪表盘 = 倒计时结束),墙钟计时,停桨休息不清零不暂停。
///
/// 停桨自动收尾(房总确认的默认策略):有过运动后,停桨超过
/// [autoEndSec] 自动结束并落盘;太短(无意义)的不存。
class WorkoutRecorder extends ChangeNotifier {
  final TrainingGoal goal;
  final RowerConnection conn;
  final RowingMetrics metrics;

  WorkoutRecorder({
    required this.goal,
    required this.conn,
    required RowingTuning tuning,
  }) : metrics = RowingMetrics(tuning);

  static const int autoEndSec = 90;

  final DateTime startTime = DateTime.now();
  StreamSubscription<AnytumSample>? _sub;
  Timer? _ticker;

  double peakPower = 0;
  double calories = 0;

  // 会话级桨频累计(指标引擎只给瞬时 spm,结束时已停桨≈0,需自己求均值)
  double _spmSum = 0;
  int _spmCount = 0;
  double get avgSpm => _spmCount == 0 ? 0 : _spmSum / _spmCount;

  // 心率累计(用于平均/峰值;无数据则记录里为 null)
  int _hrSum = 0;
  int _hrCount = 0;
  int peakHr = 0;

  // 分段(每 500m)
  final List<Split> splits = [];
  int _splitIndex = 1;
  double _splitStartDist = 0;
  int _splitStartElapsedMs = 0;
  double _segSpmSum = 0, _segPowSum = 0;
  int _segSamples = 0;
  int _segHrSum = 0, _segHrCount = 0;
  static const double splitMeters = 500;

  // 轻量曲线采样(详情页);每 5s 一点。配速/心率瞬时值在桨与桨之间会
  // 短暂缺失(回桨速度跌破阈值、心率信号瞬断),用上一有效值补,保持曲线
  // 连续 —— 否则缺失点被图表当 <=0 滤掉,曲线退化成断点/占位基线(#4)。
  final List<int> paceSeries = [];
  final List<int> hrSeries = [];
  int _lastSampleSec = -5;
  int _lastPaceSec = 0; // 上一有效配速(秒/500m);首个有效值前为 0
  int _lastHr = 0; // 上一有效心率(bpm);首个有效值前为 0

  DateTime _lastMoving = DateTime.now();
  bool _everMoved = false;
  bool finished = false;
  Workout? result;

  /// 墙钟时长(实时显示用,PRD §4.1:停桨不暂停)。
  Duration get elapsed => DateTime.now().difference(startTime);
  int get elapsedSec => elapsed.inSeconds;

  /// 末段静置宽限(秒):保留最后一桨的滑行,不算进有效时长。
  static const int tailGraceSec = 5;

  /// 有效时长(秒)= 起始 → 最后一次划动 + 宽限,且不超过墙钟。
  /// 卡路里/平均配速/落盘 durationSec 用它:停桨自动收尾的 90s 检测
  /// 延迟(及任何尾部静置)不会污染记录;中途间歇休息因后续仍有划动
  /// 会更新 _lastMoving,不受影响。墙钟值仅留实时计时显示。
  int get effectiveSec => effectiveDuration(
        everMoved: _everMoved,
        lastMoveMs: _lastMoving.difference(startTime).inMilliseconds,
        wallSec: elapsedSec,
      );

  /// 纯函数(可单测):有效时长 = min(墙钟, 最后划动+宽限);没划过 = 0。
  static int effectiveDuration({
    required bool everMoved,
    required int lastMoveMs,
    required int wallSec,
    int grace = tailGraceSec,
  }) {
    if (!everMoved) return 0;
    final eff = (lastMoveMs / 1000.0 + grace).round();
    return eff < wallSec ? eff : wallSec;
  }

  /// 曲线采样单步(纯函数,可单测):本刻读数 [reading](null/<=0=该刻
  /// 缺失)与上一有效值 [last]。有新值用新值;缺失则沿用 [last] 保持曲线
  /// 连续。[last] 仍为 0 = 首个有效值尚未出现,记 0(图表按 <=0 跳过这些
  /// 前导点)。#4 回归:不再把桨间缺失记成 0 打断曲线 → 退化成占位基线。
  static int curveSample(int? reading, int last) =>
      (reading != null && reading > 0) ? reading : last;

  void start() {
    conn.resetHrSessionFlag();
    _sub = conn.samples.listen(_onSample);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  void _onSample(AnytumSample s) {
    final now = DateTime.now();
    metrics.add(s, now);
    if (s.moving) {
      _everMoved = true;
      _lastMoving = now;
    }
    final p = metrics.powerW;
    if (p > peakPower) peakPower = p;
    // 段内累计
    if (s.moving) {
      if (metrics.spm > 0) {
        _spmSum += metrics.spm;
        _spmCount++;
      }
      _segSpmSum += metrics.spm;
      _segPowSum += metrics.powerW;
      _segSamples++;
      final hr = conn.hrBpm;
      if (hr != null && !conn.hrSignalWeak) {
        _segHrSum += hr;
        _segHrCount++;
      }
    }
    _maybeCloseSplit();
    notifyListeners();
  }

  void _tick() {
    // 卡路里:Concept2 公开模型 Cal/hr = 4·W·0.8604 + 300(无参照估算)。
    // 用有效时长 → 停桨后实时卡路里也停涨,与落盘值一致(PRD §4.3)。
    final avgP = metrics.avgPowerW;
    calories = ((4 * avgP * 0.8604) + 300) / 3600 * effectiveSec;

    // 心率累计 + 曲线采样
    final hr = conn.hrBpm;
    if (hr != null && !conn.hrSignalWeak) {
      _hrSum += hr;
      _hrCount++;
      if (hr > peakHr) peakHr = hr;
    }
    if (elapsedSec - _lastSampleSec >= 5) {
      _lastSampleSec = elapsedSec;
      _lastPaceSec = curveSample(metrics.split500?.inSeconds, _lastPaceSec);
      paceSeries.add(_lastPaceSec);
      final hrNow = (hr != null && !conn.hrSignalWeak) ? hr : null;
      _lastHr = curveSample(hrNow, _lastHr);
      hrSeries.add(_lastHr);
    }

    // 目标达成 → 自动收尾
    if (!finished && _goalReached()) {
      finalizeAndStop();
      return;
    }
    // 停桨超时 → 自动收尾
    if (!finished &&
        _everMoved &&
        DateTime.now().difference(_lastMoving).inSeconds >= autoEndSec) {
      finalizeAndStop();
      return;
    }
    notifyListeners();
  }

  void _maybeCloseSplit() {
    while (metrics.distanceM >= _splitStartDist + splitMeters) {
      final segMs = elapsed.inMilliseconds - _splitStartElapsedMs;
      splits.add(Split(
        index: _splitIndex,
        distanceM: splitMeters,
        durationSec: (segMs / 1000).round(),
        avgSpm: _segSamples == 0 ? 0 : _segSpmSum / _segSamples,
        avgPower: _segSamples == 0 ? 0 : _segPowSum / _segSamples,
        avgHr: _segHrCount == 0 ? null : (_segHrSum / _segHrCount).round(),
      ));
      _splitIndex++;
      _splitStartDist += splitMeters;
      _splitStartElapsedMs = elapsed.inMilliseconds;
      _segSpmSum = _segPowSum = 0;
      _segSamples = 0;
      _segHrSum = _segHrCount = 0;
    }
  }

  bool _goalReached() {
    final tv = goal.targetValue;
    if (tv == null) return false;
    return switch (goal.mode) {
      TrainingMode.distance => metrics.distanceM >= tv,
      TrainingMode.time => elapsedSec >= tv,
      TrainingMode.calorie => calories >= tv,
      _ => false,
    };
  }

  /// 末段(不足 500m)收尾。
  void _closeTailSplit() {
    final tail = metrics.distanceM - _splitStartDist;
    if (tail < 20) return; // 太短不单列
    // 用有效时长结尾,避免尾部静置 90s 进入末段。
    final segMs = effectiveSec * 1000 - _splitStartElapsedMs;
    splits.add(Split(
      index: _splitIndex,
      distanceM: tail,
      durationSec: (segMs / 1000).round(),
      avgSpm: _segSamples == 0 ? 0 : _segSpmSum / _segSamples,
      avgPower: _segSamples == 0 ? 0 : _segPowSum / _segSamples,
      avgHr: _segHrCount == 0 ? null : (_segHrSum / _segHrCount).round(),
    ));
  }

  /// 结束并产出记录。太短(<30s 或 <3 桨 或 <20m)返回 null(不存)。
  Workout? finalizeAndStop() {
    if (finished) return result;
    finished = true;
    _sub?.cancel();
    _ticker?.cancel();
    _closeTailSplit();

    final dist = metrics.distanceM;
    final dur = effectiveSec; // 有效时长:不含尾部静置/收尾检测延迟
    if (dur < 30 || metrics.strokeCount < 3 || dist < 20) {
      result = null;
      notifyListeners();
      return null;
    }
    // 卡路里按有效时长定稿(与实时一致,避免尾部静置虚高)。
    calories = ((4 * metrics.avgPowerW * 0.8604) + 300) / 3600 * dur;
    result = Workout(
      id: 'w_${startTime.millisecondsSinceEpoch}',
      userId: '', // 由调用方(AppState)填当前用户
      startTime: startTime,
      durationSec: dur,
      goal: goal,
      goalAchieved: _goalReached(),
      distanceM: dist,
      strokes: metrics.strokeCount,
      pulses: metrics.sessionPulses,
      avgSpeed: dur == 0 ? 0 : dist / dur,
      avgSpm: avgSpm,
      avgPower: metrics.avgPowerW,
      peakPower: peakPower,
      calories: calories,
      avgHr: _hrCount == 0 ? null : (_hrSum / _hrCount).round(),
      peakHr: peakHr == 0 ? null : peakHr,
      hrPartial: conn.hrPartial,
      splits: List.of(splits),
      paceSeries: List.of(paceSeries),
      hrSeries: hrSeries.any((e) => e > 0) ? List.of(hrSeries) : const [],
    );
    notifyListeners();
    return result;
  }
}
