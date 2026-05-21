import 'json_file.dart';
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
  double metersPerPulse = 0.35;
  double powerK = 2.80;
  int catchHighMs = 220;
  int catchLowMs = 150;

  RememberedDevice? rower; // 记住的划船机
  RememberedDevice? hrDevice; // 记住的心率设备

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final f = await LocalPaths.file('settings.json');
    final j = await JsonFile.readMap(f);
    if (j != null) {
      // 旧版默认 0.45 已被证明偏高(issue #7),静默迁移到新默认 0.35。
      // 用户在设置里手动调过其他值(非 0.45)的会原样保留。
      final stored = (j['metersPerPulse'] as num?)?.toDouble();
      metersPerPulse = (stored == null || stored == 0.45) ? 0.35 : stored;
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
      await JsonFile.writeAtomic(f, {
        'metersPerPulse': metersPerPulse,
        'powerK': powerK,
        'catchHighMs': catchHighMs,
        'catchLowMs': catchLowMs,
        'rower': rower?.toJson(),
        'hrDevice': hrDevice?.toJson(),
      });
    } catch (_) {}
  }
}
