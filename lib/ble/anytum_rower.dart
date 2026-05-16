import 'dart:typed_data';

/// 一次飞轮脉冲样本(从 0xFFE4 的 13 字节帧解出)。
class AnytumSample {
  final int intervalMs; // B9:B10 大端;0 = 静止心跳帧
  final int rawCounter; // B11:B12 大端,设备原始 16 位脉冲计数
  final int totalPulses; // 翻转修正后的累计脉冲
  final bool moving;

  AnytumSample(this.intervalMs, this.rawCounter, this.totalPulses, this.moving);
}

/// Anytum/莫比(AT-R79517)私有协议解析器。
///
/// 0xFFE4 通知,定长 13 字节,每个飞轮脉冲发一包:
///   B0      = 0xAB 帧头
///   B1..B8  = 04 01 09 00 64 01 00 00  (恒定)
///   B9:B10  = 大端 uint16 = 距上一脉冲的毫秒数(0 = 静止心跳帧)
///   B11:B12 = 大端 uint16 = 累计脉冲计数器(设备直接给绝对值)
///
/// 静止时设备周期发 `... 00 00 00 00`(间隔 0、计数保持)作为心跳。
///
/// 标定结论(2026-05-16,用户数着划 + 日志比对):
///   - 每桨 ≈ 22~24 脉冲
///   - 拉桨间隔 ≈ 70~95ms;回桨间隔升至 250~850ms;回落(骤降)= 抓水点
class AnytumRower {
  static const int frameLen = 13;
  static const int header = 0xAB;

  int _last = -1;
  int _wraps = 0;

  /// 翻转修正后的累计脉冲(支持超 65535 的长时段)。
  int get totalPulses => _last < 0 ? 0 : _wraps * 65536 + _last;

  void reset() {
    _last = -1;
    _wraps = 0;
  }

  /// 返回 null 表示不是本协议的帧。
  AnytumSample? parse(Uint8List d) {
    if (d.length != frameLen || d[0] != header) return null;
    final intervalMs = (d[9] << 8) | d[10];
    final counter = (d[11] << 8) | d[12];
    if (_last >= 0 && counter < _last - 1000) _wraps++; // 16 位翻转
    _last = counter;
    return AnytumSample(intervalMs, counter, totalPulses, intervalMs > 0);
  }

  static String summary(AnytumSample s) {
    if (!s.moving) return '静止(心跳)';
    return '间隔 ${s.intervalMs}ms · 累计脉冲 ${s.totalPulses}';
  }
}
