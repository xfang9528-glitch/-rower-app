import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import 'anytum_rower.dart';
import 'heart_rate.dart';
import 'known_uuids.dart';
import 'session_log.dart';

/// 划船机蓝牙名固定;广播服务 0xFFE0;数据走 0xFFE4 notify。
const String kAutoConnectName = 'AT-R79517';
const String kRowerService = '0000ffe0-0000-1000-8000-00805f9b34fb';

enum RowerConnState {
  idle,
  btOff,
  scanning,
  found,
  connecting,
  connected,
  failed,
  disconnected,
}

enum _ScanPurpose { rower, all, hr }

/// 一帧原始通知(原始调试视图用)。
class RawFrame {
  final DateTime t;
  final String charUuid;
  final Uint8List value;
  final int? deltaMs;
  final String? parsed;
  RawFrame(this.t, this.charUuid, this.value, this.deltaMs, this.parsed);
}

/// 零点击连接状态机 + BLE 数据中枢。universal_ble 的回调是全局单例,
/// 因此本控制器也是单例:连接流程驱动它,仪表盘/原始调试订阅它的流。
///
/// 复用冒烟版验证过的策略:按名 `AT-R79517` 或已记住设备自动连;首次
/// 握手常瞬时失败 → 自动重试至多 8 次。
class RowerConnection extends ChangeNotifier {
  RowerConnection._();
  static final RowerConnection instance = RowerConnection._();

  RowerConnState state = RowerConnState.idle;
  String statusMessage = '';
  AvailabilityState availability = AvailabilityState.unknown;

  final Map<String, BleDevice> discovered = {};
  BleDevice? device;
  List<BleService> services = [];
  final Set<String> subscribed = {};

  final AnytumRower _anytum = AnytumRower();
  AnytumSample? lastSample;

  final _samples = StreamController<AnytumSample>.broadcast();
  Stream<AnytumSample> get samples => _samples.stream;
  final _rawFrames = StreamController<RawFrame>.broadcast();
  Stream<RawFrame> get rawFrames => _rawFrames.stream;

  final Map<String, DateTime> _lastSeen = {};
  bool _scanning = false;
  bool _cancelled = false;
  bool _wiredCallbacks = false;
  String? _targetId; // 已记住的划船机 id(优先于名字匹配)
  _ScanPurpose _scanPurpose = _ScanPurpose.rower;

  // ---- 心率(可选第二 BLE 设备,标准 0x180D/0x2A37)----
  final Map<String, BleDevice> hrDiscovered = {};
  BleDevice? hrDevice;
  int? hrBpm;
  DateTime? hrLastUpdate;
  bool hrScanning = false;
  bool _hrEverConnected = false; // 本会话曾连上 → 后续掉线记"部分缺失"
  bool hrPartial = false;
  final _hrCtrl = StreamController<int>.broadcast();
  Stream<int> get hrStream => _hrCtrl.stream;

  /// >5s 无心率更新 = 信号弱(PRD §4.4)。
  bool get hrSignalWeak =>
      hrLastUpdate != null &&
      DateTime.now().difference(hrLastUpdate!).inSeconds > 5;
  bool get hrConnected => hrDevice != null;

  static const int maxAttempts = 8;

  bool get isConnected => state == RowerConnState.connected;

  void _set(RowerConnState s, [String? msg]) {
    state = s;
    if (msg != null) statusMessage = msg;
    notifyListeners();
  }

  void _wireCallbacks() {
    if (_wiredCallbacks) return;
    _wiredCallbacks = true;
    UniversalBle.onAvailabilityChange = (s) {
      availability = s;
      SessionLog.line('[蓝牙状态] ${s.name}');
      if (s != AvailabilityState.poweredOn &&
          s != AvailabilityState.unknown &&
          state != RowerConnState.connected) {
        _set(RowerConnState.btOff, '蓝牙未开启');
      } else {
        notifyListeners();
      }
    };
    UniversalBle.onScanResult = _onScanResult;
    UniversalBle.onConnectionChange = _onConnectionChange;
    UniversalBle.onValueChange = _onValueChange;
  }

  /// 启动页「开始划船」:检查蓝牙 → 过滤扫描 → 命中目标自动连。
  Future<void> startAuto({String? rememberedId}) async {
    _wireCallbacks();
    _cancelled = false;
    _targetId = rememberedId;
    _scanPurpose = _ScanPurpose.rower;
    discovered.clear();
    lastSample = null;
    _anytum.reset();

    try {
      availability = await UniversalBle.getBluetoothAvailabilityState();
    } catch (_) {}
    if (availability != AvailabilityState.poweredOn &&
        availability != AvailabilityState.unknown) {
      _set(RowerConnState.btOff, '蓝牙未开启');
      return;
    }

    SessionLog.start('目标设备: $kAutoConnectName'
        '${rememberedId != null ? " (已记住 $rememberedId)" : ""}');
    try {
      await UniversalBle.requestPermissions();
    } catch (_) {}

    _set(RowerConnState.scanning, '正在扫描划船机…');
    SessionLog.line('[扫描] 开始(只过滤划船机)…');
    try {
      await _startScan(
        ScanFilter(withServices: [kRowerService], withNamePrefix: ['AT']),
      );
    } catch (e) {
      SessionLog.line('[扫描失败] $e');
      _set(RowerConnState.failed, '扫描失败:$e');
    }
  }

  /// 兜底:不过滤扫描全部设备(手动选设备页用)。
  Future<void> scanAll() async {
    _wireCallbacks();
    _cancelled = false;
    _scanPurpose = _ScanPurpose.all;
    discovered.clear();
    _set(RowerConnState.scanning, '扫描全部蓝牙设备…');
    try {
      await UniversalBle.requestPermissions();
    } catch (_) {}
    try {
      await _startScan(null);
    } catch (e) {
      SessionLog.line('[扫描失败] $e');
      _set(RowerConnState.failed, '扫描失败:$e');
    }
  }

  Future<void> _startScan(ScanFilter? filter) async {
    if (_scanning) {
      await UniversalBle.stopScan();
    }
    _scanning = true;
    await UniversalBle.startScan(scanFilter: filter);
  }

  Future<void> _stopScan() async {
    if (!_scanning) return;
    _scanning = false;
    try {
      await UniversalBle.stopScan();
    } catch (_) {}
  }

  void _onScanResult(BleDevice d) {
    if (_scanPurpose == _ScanPurpose.hr) {
      hrDiscovered[d.deviceId] = d;
      notifyListeners();
      return;
    }
    final isNew = !discovered.containsKey(d.deviceId);
    discovered[d.deviceId] = d;
    if (isNew) {
      SessionLog.line('[发现设备] name="${d.name}" raw="${d.rawName}" '
          'id=${d.deviceId} rssi=${d.rssi} 广播服务=${d.services}');
    }
    notifyListeners();

    if (_cancelled || state == RowerConnState.connecting) return;
    final n = (d.name ?? d.rawName ?? '').trim();
    final isTarget =
        n == kAutoConnectName || (_targetId != null && d.deviceId == _targetId);
    if (isTarget && state == RowerConnState.scanning) {
      _set(RowerConnState.found, '已发现 $kAutoConnectName · 信号良好');
      SessionLog.line('[自动匹配] 命中 $n,直连…');
      connectTo(d);
    }
  }

  /// 连接 + 自动重试 + 发现服务 + 订阅所有可通知特征。
  Future<void> connectTo(BleDevice d) async {
    _wireCallbacks();
    _cancelled = false;
    device = d;
    await _stopScan();
    final id = d.deviceId;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (_cancelled) {
        _set(RowerConnState.idle, '已取消');
        return;
      }
      _set(RowerConnState.connecting, '正在建立连接… (第 $attempt 次)');
      try {
        await UniversalBle.connect(id);
        final svcs =
            await UniversalBle.discoverServices(id, withDescriptors: true);
        if (_cancelled) return;
        services = svcs;
        if (!SessionLog.started) {
          SessionLog.start('设备直连: ${d.name} ($id)');
        }
        SessionLog.line('[已连接] 第 $attempt 次成功, '
            '发现 ${svcs.length} 个服务');
        await _subscribeAll(id);
        _set(RowerConnState.connected, '已连接 · ${svcs.length} 个服务');
        return;
      } catch (e) {
        SessionLog.line('[连接失败] 第 $attempt/$maxAttempts 次: $e');
        _set(RowerConnState.connecting, '连接失败,重试中… ($attempt/$maxAttempts)');
        await Future.delayed(const Duration(milliseconds: 1200));
      }
    }
    _set(RowerConnState.failed, '已重试 $maxAttempts 次仍连不上 $kAutoConnectName');
  }

  Future<void> _subscribeAll(String id) async {
    subscribed.clear();
    for (final s in services) {
      for (final c in s.characteristics) {
        final notify = c.properties.contains(CharacteristicProperty.notify);
        final indicate =
            c.properties.contains(CharacteristicProperty.indicate);
        if (!notify && !indicate) continue;
        try {
          if (notify) {
            await UniversalBle.subscribeNotifications(id, s.uuid, c.uuid);
          } else {
            await UniversalBle.subscribeIndications(id, s.uuid, c.uuid);
          }
          subscribed.add(c.uuid);
          SessionLog.line('[订阅成功] ${shortUuid(c.uuid)}');
        } catch (e) {
          SessionLog.line('[订阅失败] ${shortUuid(c.uuid)}: $e');
        }
      }
    }
  }

  void _onConnectionChange(String deviceId, bool isConnected, String? error) {
    // 心率设备掉线:不影响划船记录,自动重连;本次标"部分缺失"。
    if (hrDevice != null && deviceId == hrDevice!.deviceId) {
      if (!isConnected) {
        if (_hrEverConnected) hrPartial = true;
        SessionLog.line('[心率] 断开,自动重连…');
        _autoReconnectHr();
      }
      notifyListeners();
      return;
    }
    if (device == null || deviceId != device!.deviceId) return;
    SessionLog.line('[连接状态] ${isConnected ? "已连接" : "已断开"}'
        '${error != null ? " ($error)" : ""}');
    if (!isConnected && state == RowerConnState.connected) {
      // 训练中意外断开:自动重连,训练数据由 recorder 保留。
      _set(RowerConnState.disconnected, '连接已断开,正在自动重连…');
      _autoReconnect();
    }
  }

  Future<void> _autoReconnect() async {
    final d = device;
    if (d == null) return;
    for (var i = 1; i <= maxAttempts; i++) {
      if (_cancelled) return;
      try {
        await UniversalBle.connect(d.deviceId);
        final svcs = await UniversalBle.discoverServices(d.deviceId,
            withDescriptors: true);
        services = svcs;
        await _subscribeAll(d.deviceId);
        _set(RowerConnState.connected, '已重连 · 训练继续');
        return;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    }
    _set(RowerConnState.disconnected, '重连失败,请检查划船机');
  }

  // ---------- 心率设备(可选第二 BLE)----------

  /// 扫描标准心率设备(广播 0x180D)。结果进 [hrDiscovered]。
  Future<void> scanHr() async {
    _wireCallbacks();
    _scanPurpose = _ScanPurpose.hr;
    hrDiscovered.clear();
    hrScanning = true;
    notifyListeners();
    try {
      await UniversalBle.requestPermissions();
    } catch (_) {}
    try {
      await _startScan(ScanFilter(withServices: [hrServiceUuid]));
    } catch (e) {
      SessionLog.line('[心率扫描失败] $e');
    }
  }

  Future<void> stopHrScan() async {
    hrScanning = false;
    _scanPurpose = _ScanPurpose.rower;
    await _stopScan();
    notifyListeners();
  }

  /// 连接选定心率设备并订阅 0x2A37。
  Future<bool> connectHr(BleDevice d) async {
    await stopHrScan();
    try {
      await UniversalBle.connect(d.deviceId);
      final svcs = await UniversalBle.discoverServices(d.deviceId,
          withDescriptors: true);
      for (final s in svcs) {
        for (final c in s.characteristics) {
          if (shortUuid(c.uuid) == '0x2A37') {
            await UniversalBle.subscribeNotifications(
                d.deviceId, s.uuid, c.uuid);
          }
        }
      }
      hrDevice = d;
      _hrEverConnected = true;
      hrLastUpdate = DateTime.now();
      SessionLog.line('[心率] 已连接 ${d.name ?? d.deviceId}');
      notifyListeners();
      return true;
    } catch (e) {
      SessionLog.line('[心率连接失败] $e');
      return false;
    }
  }

  Future<void> _autoReconnectHr() async {
    final d = hrDevice;
    if (d == null) return;
    for (var i = 1; i <= maxAttempts; i++) {
      try {
        await UniversalBle.connect(d.deviceId);
        final svcs = await UniversalBle.discoverServices(d.deviceId,
            withDescriptors: true);
        for (final s in svcs) {
          for (final c in s.characteristics) {
            if (shortUuid(c.uuid) == '0x2A37') {
              await UniversalBle.subscribeNotifications(
                  d.deviceId, s.uuid, c.uuid);
            }
          }
        }
        SessionLog.line('[心率] 已自动重连');
        notifyListeners();
        return;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 2000));
      }
    }
  }

  /// 训练开始时由 WorkoutRecorder 调用,清掉上一次的"部分缺失"标记。
  void resetHrSessionFlag() {
    hrPartial = false;
  }

  Future<void> disconnectHr() async {
    final d = hrDevice;
    hrDevice = null;
    hrBpm = null;
    hrLastUpdate = null;
    if (d != null) {
      try {
        await UniversalBle.disconnect(d.deviceId);
      } catch (_) {}
    }
    notifyListeners();
  }

  void _onValueChange(
      String deviceId, String charUuid, Uint8List value, int? ts) {
    final now = DateTime.now();
    final last = _lastSeen[charUuid];
    final delta = last == null ? null : now.difference(last).inMilliseconds;
    _lastSeen[charUuid] = now;

    String? parsed;
    if (shortUuid(charUuid) == '0xFFE4') {
      final s = _anytum.parse(value);
      if (s != null) {
        lastSample = s;
        parsed = AnytumRower.summary(s);
        if (!_samples.isClosed) _samples.add(s);
      }
    } else if (shortUuid(charUuid) == '0x2A37') {
      final bpm = parseHeartRate(value);
      if (bpm != null && bpm > 0) {
        hrBpm = bpm;
        hrLastUpdate = now;
        parsed = '心率 $bpm bpm';
        if (!_hrCtrl.isClosed) _hrCtrl.add(bpm);
        notifyListeners();
      }
    }
    SessionLog.line('${_ts(now)}  ${shortUuid(charUuid)}  '
        'd=${delta ?? "-"}ms  len=${value.length}  '
        'HEX ${_hex(value)}${parsed != null ? "  ⇒ $parsed" : ""}');
    if (!_rawFrames.isClosed) {
      _rawFrames.add(RawFrame(now, charUuid, value, delta, parsed));
    }
  }

  /// 用户在「连接中」点取消。
  void cancel() {
    _cancelled = true;
    _stopScan();
    _set(RowerConnState.idle, '已取消');
  }

  /// 训练结束:断开设备,但保留单例与回调以便下次快速再连。
  Future<void> disconnectDevice() async {
    final d = device;
    if (d != null) {
      try {
        await UniversalBle.disconnect(d.deviceId);
      } catch (_) {}
    }
    _set(RowerConnState.idle, '');
  }

  List<BleDevice> get sortedDiscovered {
    final list = discovered.values.toList()
      ..sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));
    return list;
  }

  static String _ts(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}.'
      '${t.millisecond.toString().padLeft(3, '0')}';
  static String _hex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join(' ');
}
