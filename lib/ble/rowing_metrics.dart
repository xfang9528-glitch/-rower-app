import 'dart:collection';

import 'anytum_rower.dart';

/// 把飞轮脉冲流换算成训练指标。
///
/// 没有原厂屏幕也没有别的划船机做绝对参照,所以用 Concept2 的标准关系
/// (功率 = k·v³,配速与功率自洽)+ 一个可调的「米/脉冲」系数,保证
/// 数字自洽、像样、能训练;将来有参照只改这两个常数即可。
///
/// 标定输入(2026-05-16):每桨≈23脉冲、拉桨间隔≈70~95ms、
/// 回桨间隔升到 250~850ms 后骤降=抓水。
class RowingTuning {
  /// 每个飞轮脉冲的赛艇等效距离(米)。0.45 ≈ 每桨(~23脉冲)~10.4m,
  /// 与赛艇"每桨约10m"经验一致。有参照时调这个。
  final double metersPerPulse;

  /// Concept2 功率常数:功率(W) = k · 速度³(m/s)。2.80 为其公开取值。
  final double powerK;

  /// 滚动测速窗口(秒)。窗口内"脉冲数×米/脉冲÷窗口"得到平滑速度,
  /// 避免按单包间隔算导致配速在拉/回桨间狂跳。
  final double speedWindowSec;

  /// 速度上限(m/s)。脉冲突发时短窗测速会瞬时飙高,经立方放大后功率
  /// 离谱(实测见过 2500W+)。6.0 m/s ≈ 1:23/500m,已远超本机可持续
  /// 强度,纯为掐掉数值毛刺,真实努力不会触顶。
  final double maxSpeed;

  /// 速度 EMA 平滑系数:new = old·(1-a) + raw·a。越小越稳。
  final double speedEma;

  /// 抓水判定:自上一桨以来间隔曾高于 catchHighMs,随后跌破 catchLowMs
  /// 记一桨(跨多包也能命中)。
  final int catchHighMs;
  final int catchLowMs;

  const RowingTuning({
    this.metersPerPulse = 0.45,
    this.powerK = 2.80,
    this.speedWindowSec = 3.0,
    this.maxSpeed = 6.0,
    this.speedEma = 0.3,
    this.catchHighMs = 220,
    this.catchLowMs = 150,
  });
}

class RowingMetrics {
  final RowingTuning t;
  RowingMetrics([this.t = const RowingTuning()]);

  bool _started = false;
  int _basePulses = 0;
  int _pulses = 0;
  DateTime? _startTime;

  // 滚动测速窗口: (时间, 会话累计脉冲)
  final Queue<MapEntry<DateTime, int>> _win = Queue();

  int _strokeCount = 0;
  bool _sawRecovery = false;
  DateTime? _lastStrokeTime;
  double _spm = 0;

  double _speed = 0; // m/s, 平滑
  double _powerAccum = 0;
  int _powerSamples = 0;

  int get strokeCount => _strokeCount;
  double get spm => _spm;
  double get distanceM => _pulses * t.metersPerPulse;
  int get sessionPulses => _pulses;
  double get speed => _speed;
  double get powerW => t.powerK * _speed * _speed * _speed;
  double get avgPowerW => _powerSamples == 0 ? 0 : _powerAccum / _powerSamples;

  /// 墙钟计时:第一桨后持续走(含停桨休息),不依赖数据帧。
  Duration get elapsed =>
      _startTime == null ? Duration.zero : DateTime.now().difference(_startTime!);

  /// 当前配速:每 500m 秒数。速度过低返回 null。
  Duration? get split500 {
    if (_speed <= 0.1) return null;
    return Duration(milliseconds: (500 / _speed * 1000).round());
  }

  void reset() {
    _started = false;
    _pulses = 0;
    _strokeCount = 0;
    _sawRecovery = false;
    _spm = 0;
    _speed = 0;
    _powerAccum = 0;
    _powerSamples = 0;
    _startTime = _lastStrokeTime = null;
    _win.clear();
  }

  /// 原始窗口速度 → EMA 平滑 + 上限。脉冲突发产生的瞬时尖峰在这里被
  /// 压平,避免立方放大成离谱功率/卡路里(powerW/avgPowerW/recorder
  /// 的 peakPower 都由 _speed 派生,改这一处即全链路一致回落)。
  double _applySpeed(double raw) {
    if (raw.isNaN || raw < 0) raw = 0;
    final ema = _speed <= 0 ? raw : _speed * (1 - t.speedEma) + raw * t.speedEma;
    return ema.clamp(0.0, t.maxSpeed);
  }

  /// 喂入一个解析样本。返回是否产生新的一桨。
  bool add(AnytumSample s, DateTime now) {
    if (!s.moving) {
      // 停桨:速度/功率自然衰减到 0(滚动窗口里塞入"脉冲不变"的点),
      // 距离/桨数/时间保留。
      if (_started) {
        _sawRecovery = false;
        _win.addLast(MapEntry(now, _pulses));
        final cutoff = now.subtract(
            Duration(milliseconds: (t.speedWindowSec * 1000).round()));
        while (_win.length > 2 && _win.first.key.isBefore(cutoff)) {
          _win.removeFirst();
        }
        final span = now.difference(_win.first.key).inMilliseconds / 1000.0;
        if (span > 0.3) {
          _speed = _applySpeed(
              (_pulses - _win.first.value) * t.metersPerPulse / span);
        }
      }
      return false;
    }

    if (!_started) {
      _started = true;
      _basePulses = s.totalPulses;
      _startTime = now;
      _pulses = 0;
    } else {
      final d = s.totalPulses - _basePulses - _pulses;
      if (d > 0) _pulses += d;
    }

    // 滚动窗口测速
    _win.addLast(MapEntry(now, _pulses));
    final cutoff = now.subtract(
        Duration(milliseconds: (t.speedWindowSec * 1000).round()));
    while (_win.length > 2 && _win.first.key.isBefore(cutoff)) {
      _win.removeFirst();
    }
    final span =
        now.difference(_win.first.key).inMilliseconds / 1000.0;
    if (span > 0.3) {
      final dp = _pulses - _win.first.value;
      _speed = _applySpeed(dp * t.metersPerPulse / span);
      _powerAccum += powerW;
      _powerSamples++;
    }

    // 抓水检测(状态机, 跨多包)
    bool newStroke = false;
    if (s.intervalMs >= t.catchHighMs) _sawRecovery = true;
    if (_sawRecovery && s.intervalMs <= t.catchLowMs) {
      _strokeCount++;
      newStroke = true;
      _sawRecovery = false;
      if (_lastStrokeTime != null) {
        final dt = now.difference(_lastStrokeTime!).inMilliseconds / 1000.0;
        if (dt > 0.5 && dt < 12) {
          final inst = 60.0 / dt;
          _spm = _spm == 0 ? inst : _spm * 0.6 + inst * 0.4;
        }
      }
      _lastStrokeTime = now;
    }
    return newStroke;
  }
}
