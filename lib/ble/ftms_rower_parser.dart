import 'dart:typed_data';

/// Decodes the FTMS "Rower Data" characteristic (0x2AD1) per the Bluetooth
/// Fitness Machine Service spec. If the Xiaomo rower is FTMS-compliant this
/// turns its raw notifications into real metrics with zero reverse-engineering.
class RowerData {
  final int? strokeRate; // strokes/min
  final int? strokeCount;
  final int? avgStrokeRate; // strokes/min
  final int? totalDistance; // meters
  final int? instantaneousPace; // seconds / 500m
  final int? averagePace; // seconds / 500m
  final int? instantaneousPower; // watts
  final int? averagePower; // watts
  final int? resistanceLevel;
  final int? totalEnergy; // kcal
  final int? energyPerHour; // kcal
  final int? energyPerMinute; // kcal
  final int? heartRate; // bpm
  final double? metabolicEquivalent;
  final int? elapsedTime; // seconds
  final int? remainingTime; // seconds

  RowerData({
    this.strokeRate,
    this.strokeCount,
    this.avgStrokeRate,
    this.totalDistance,
    this.instantaneousPace,
    this.averagePace,
    this.instantaneousPower,
    this.averagePower,
    this.resistanceLevel,
    this.totalEnergy,
    this.energyPerHour,
    this.energyPerMinute,
    this.heartRate,
    this.metabolicEquivalent,
    this.elapsedTime,
    this.remainingTime,
  });

  /// Returns null if the payload is too short to even hold the flags field.
  static RowerData? parse(Uint8List data) {
    if (data.length < 2) return null;
    final bytes = ByteData.sublistView(data);
    int offset = 0;

    final flags = bytes.getUint16(offset, Endian.little);
    offset += 2;

    bool flag(int bit) => (flags & (1 << bit)) != 0;

    int? u8() {
      if (offset + 1 > data.length) return null;
      final v = bytes.getUint8(offset);
      offset += 1;
      return v;
    }

    int? u16() {
      if (offset + 2 > data.length) return null;
      final v = bytes.getUint16(offset, Endian.little);
      offset += 2;
      return v;
    }

    int? s16() {
      if (offset + 2 > data.length) return null;
      final v = bytes.getInt16(offset, Endian.little);
      offset += 2;
      return v;
    }

    int? u24() {
      if (offset + 3 > data.length) return null;
      final v = bytes.getUint8(offset) |
          (bytes.getUint8(offset + 1) << 8) |
          (bytes.getUint8(offset + 2) << 16);
      offset += 3;
      return v;
    }

    int? sr;
    int? sc;
    // Bit 0 = "More Data": when 0, Stroke Rate + Stroke Count ARE present.
    if (!flag(0)) {
      final raw = u8();
      sr = raw == null ? null : raw ~/ 2; // resolution 0.5 /min
      sc = u16();
    }
    int? asr;
    if (flag(1)) {
      final raw = u8();
      asr = raw == null ? null : raw ~/ 2;
    }
    final dist = flag(2) ? u24() : null;
    final ipace = flag(3) ? u16() : null;
    final apace = flag(4) ? u16() : null;
    final ipow = flag(5) ? s16() : null;
    final apow = flag(6) ? s16() : null;
    final res = flag(7) ? s16() : null;
    int? te;
    int? eph;
    int? epm;
    if (flag(8)) {
      te = u16();
      eph = u16();
      epm = u8();
    }
    final hr = flag(9) ? u8() : null;
    final metRaw = flag(10) ? u8() : null;
    final elapsed = flag(11) ? u16() : null;
    final remaining = flag(12) ? u16() : null;

    return RowerData(
      strokeRate: sr,
      strokeCount: sc,
      avgStrokeRate: asr,
      totalDistance: dist,
      instantaneousPace: ipace,
      averagePace: apace,
      instantaneousPower: ipow,
      averagePower: apow,
      resistanceLevel: res,
      totalEnergy: te,
      energyPerHour: eph,
      energyPerMinute: epm,
      heartRate: hr,
      metabolicEquivalent: metRaw == null ? null : metRaw / 10.0,
      elapsedTime: elapsed,
      remainingTime: remaining,
    );
  }

  /// Compact human-readable summary of only the fields actually present.
  String summary() {
    final parts = <String>[];
    if (strokeRate != null) parts.add('桨频 $strokeRate spm');
    if (strokeCount != null) parts.add('桨数 $strokeCount');
    if (totalDistance != null) parts.add('距离 ${totalDistance}m');
    if (instantaneousPace != null) {
      parts.add('配速 ${_fmtPace(instantaneousPace!)}/500m');
    }
    if (instantaneousPower != null) parts.add('功率 ${instantaneousPower}W');
    if (totalEnergy != null) parts.add('能量 ${totalEnergy}kcal');
    if (heartRate != null) parts.add('心率 $heartRate');
    if (elapsedTime != null) parts.add('用时 ${elapsedTime}s');
    return parts.isEmpty ? '(无可识别字段)' : parts.join('  ·  ');
  }

  static String _fmtPace(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
