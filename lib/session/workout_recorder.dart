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

  // 轻量曲线采样(详情页);每 5s 一点
  final List<int> paceSeries = [];
  final List<int> hrSeries = [];
  int _lastSampleSec = -5;

  DateTime _lastMoving = DateTime.now();
  bool _everMoved = false;
  bool finished = false;
  Workout? result;

  Duration get elapsed => DateTime.now().difference(startTime);
  int get elapsedSec => elapsed.inSeconds;

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
    final avgP = metrics.avgPowerW;
    calories = ((4 * avgP * 0.8604) + 300) / 3600 * elapsedSec;

    // 心率累计 + 曲线采样
    final hr = conn.hrBpm;
    if (hr != null && !conn.hrSignalWeak) {
      _hrSum += hr;
      _hrCount++;
      if (hr > peakHr) peakHr = hr;
    }
    if (elapsedSec - _lastSampleSec >= 5) {
      _lastSampleSec = elapsedSec;
      final sp = metrics.split500;
      paceSeries.add(sp == null ? 0 : sp.inSeconds);
      hrSeries.add((hr != null && !conn.hrSignalWeak) ? hr : 0);
    }

    // 目标达成 → 自动收尾
    if (!finished && _goalReached()) {
      finalizeAndStop(auto: true);
      return;
    }
    // 停桨超时 → 自动收尾
    if (!finished &&
        _everMoved &&
        DateTime.now().difference(_lastMoving).inSeconds >= autoEndSec) {
      finalizeAndStop(auto: true);
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
    final segMs = elapsed.inMilliseconds - _splitStartElapsedMs;
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
  Workout? finalizeAndStop({bool auto = false}) {
    if (finished) return result;
    finished = true;
    _sub?.cancel();
    _ticker?.cancel();
    _closeTailSplit();

    final dist = metrics.distanceM;
    if (elapsedSec < 30 || metrics.strokeCount < 3 || dist < 20) {
      result = null;
      notifyListeners();
      return null;
    }
    final dur = elapsedSec;
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
