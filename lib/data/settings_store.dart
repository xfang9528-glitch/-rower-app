import 'dart:convert';

import 'local_paths.dart';

/// 一台 BLE 设备的记忆(划船机 / 心率设备)。
class RememberedDevice {
  final String id;
  final String name;
  const RememberedDevice(this.id, this.name);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory RememberedDevice.fromJson(Map<String, dynamic> j) =>
      RememberedDevice(j['id'] as String? ?? '', j['name'] as String? ?? '');
}

/// 标定参数 + 记住的设备(原型 ⑧ 训练标定)。取代旧的 exe 同目录
/// paired_device.json,统一进 app 数据目录,重编不丢。
class SettingsStore {
  // 标定(默认值与 rowing_metrics.dart 的 RowingTuning 一致)
  double metersPerPulse = 0.45;
  double powerK = 2.80;
  int catchHighMs = 220;
  int catchLowMs = 150;

  RememberedDevice? rower; // 记住的划船机
  RememberedDevice? hrDevice; // 记住的心率设备

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final f = await LocalPaths.file('settings.json');
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        metersPerPulse = (j['metersPerPulse'] as num?)?.toDouble() ?? 0.45;
        powerK = (j['powerK'] as num?)?.toDouble() ?? 2.80;
        catchHighMs = j['catchHighMs'] as int? ?? 220;
        catchLowMs = j['catchLowMs'] as int? ?? 150;
        final r = j['rower'];
        if (r is Map) rower = RememberedDevice.fromJson(r.cast<String, dynamic>());
        final h = j['hrDevice'];
        if (h is Map) {
          hrDevice = RememberedDevice.fromJson(h.cast<String, dynamic>());
        }
      }
    } catch (_) {}
    _loaded = true;
  }

  Future<void> saveCalibration({
    double? metersPerPulse,
    double? powerK,
    int? catchHighMs,
    int? catchLowMs,
  }) async {
    this.metersPerPulse = metersPerPulse ?? this.metersPerPulse;
    this.powerK = powerK ?? this.powerK;
    this.catchHighMs = catchHighMs ?? this.catchHighMs;
    this.catchLowMs = catchLowMs ?? this.catchLowMs;
    await _persist();
  }

  Future<void> rememberRower(String id, String name) async {
    rower = RememberedDevice(id, name);
    await _persist();
  }

  Future<void> rememberHrDevice(String id, String name) async {
    hrDevice = RememberedDevice(id, name);
    await _persist();
  }

  Future<void> forgetRower() async {
    rower = null;
    await _persist();
  }

  Future<void> forgetHrDevice() async {
    hrDevice = null;
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final f = await LocalPaths.file('settings.json');
      await f.writeAsString(jsonEncode({
        'metersPerPulse': metersPerPulse,
        'powerK': powerK,
        'catchHighMs': catchHighMs,
        'catchLowMs': catchLowMs,
        'rower': rower?.toJson(),
        'hrDevice': hrDevice?.toJson(),
      }));
    } catch (_) {}
  }
}
