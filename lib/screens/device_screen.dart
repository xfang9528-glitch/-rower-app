import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_ble/universal_ble.dart';

import '../ble/ftms_rower_parser.dart';
import '../ble/known_uuids.dart';

class DeviceScreen extends StatefulWidget {
  final BleDevice device;
  const DeviceScreen({super.key, required this.device});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _LogEntry {
  final DateTime t;
  final String charUuid;
  final Uint8List value;
  final int? deltaMs;
  final String? parsed;
  _LogEntry(this.t, this.charUuid, this.value, this.deltaMs, this.parsed);
}

class _DeviceScreenState extends State<DeviceScreen> {
  String get _id => widget.device.deviceId;

  bool _connected = false;
  String _status = '连接中…';
  List<BleService> _services = [];
  final Set<String> _subscribed = {};
  final List<_LogEntry> _log = [];
  final Map<String, DateTime> _lastSeen = {};
  final ScrollController _logScroll = ScrollController();
  bool _autoScroll = true;
  static const int _maxLog = 5000;

  @override
  void initState() {
    super.initState();
    UniversalBle.onConnectionChange = _onConnectionChange;
    UniversalBle.onValueChange = _onValueChange;
    _connect();
  }

  @override
  void dispose() {
    UniversalBle.onValueChange = null;
    UniversalBle.onConnectionChange = null;
    UniversalBle.disconnect(_id);
    _logScroll.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() => _status = '连接中…');
    try {
      await UniversalBle.connect(_id);
      final services =
          await UniversalBle.discoverServices(_id, withDescriptors: true);
      if (!mounted) return;
      setState(() {
        _connected = true;
        _services = services;
        _status = '已连接 · ${services.length} 个服务';
      });
    } catch (e) {
      if (mounted) setState(() => _status = '连接失败: $e');
    }
  }

  void _onConnectionChange(String deviceId, bool isConnected, String? error) {
    if (deviceId != _id || !mounted) return;
    setState(() {
      _connected = isConnected;
      if (!isConnected) _status = '已断开${error != null ? " ($error)" : ""}';
    });
  }

  void _onValueChange(
      String deviceId, String charUuid, Uint8List value, int? ts) {
    if (deviceId != _id || !mounted) return;
    final now = DateTime.now();
    final last = _lastSeen[charUuid];
    final delta = last == null ? null : now.difference(last).inMilliseconds;
    _lastSeen[charUuid] = now;

    String? parsed;
    if (isRowerDataChar(charUuid)) {
      parsed = RowerData.parse(value)?.summary();
    }

    setState(() {
      _log.add(_LogEntry(now, charUuid, value, delta, parsed));
      if (_log.length > _maxLog) _log.removeRange(0, _log.length - _maxLog);
    });
    if (_autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logScroll.hasClients) {
          _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
        }
      });
    }
  }

  Future<void> _toggleSubscribe(BleService s, BleCharacteristic c) async {
    final key = c.uuid;
    try {
      if (_subscribed.contains(key)) {
        await UniversalBle.unsubscribe(_id, s.uuid, c.uuid);
        setState(() => _subscribed.remove(key));
      } else {
        if (c.properties.contains(CharacteristicProperty.notify)) {
          await UniversalBle.subscribeNotifications(_id, s.uuid, c.uuid);
        } else {
          await UniversalBle.subscribeIndications(_id, s.uuid, c.uuid);
        }
        setState(() => _subscribed.add(key));
      }
    } catch (e) {
      _snack('订阅操作失败: $e');
    }
  }

  Future<void> _subscribeAll() async {
    for (final s in _services) {
      for (final c in s.characteristics) {
        final canNotify =
            c.properties.contains(CharacteristicProperty.notify) ||
                c.properties.contains(CharacteristicProperty.indicate);
        if (canNotify && !_subscribed.contains(c.uuid)) {
          try {
            if (c.properties.contains(CharacteristicProperty.notify)) {
              await UniversalBle.subscribeNotifications(_id, s.uuid, c.uuid);
            } else {
              await UniversalBle.subscribeIndications(_id, s.uuid, c.uuid);
            }
            setState(() => _subscribed.add(c.uuid));
          } catch (e) {
            _snack('订阅 ${shortUuid(c.uuid)} 失败: $e');
          }
        }
      }
    }
  }

  Future<void> _read(BleService s, BleCharacteristic c) async {
    try {
      final v = await UniversalBle.read(_id, s.uuid, c.uuid);
      _onValueChange(_id, c.uuid, v, null);
    } catch (e) {
      _snack('读取失败: $e');
    }
  }

  Future<void> _write(BleService s, BleCharacteristic c) async {
    final ctrl = TextEditingController();
    final hex = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('写入 ${shortUuid(c.uuid)}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '十六进制，如  01 02 ff  或  0102ff',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('发送')),
        ],
      ),
    );
    if (hex == null || hex.trim().isEmpty) return;
    final bytes = _parseHex(hex);
    if (bytes == null) {
      _snack('十六进制格式错误');
      return;
    }
    try {
      final wor = c.properties
              .contains(CharacteristicProperty.writeWithoutResponse) &&
          !c.properties.contains(CharacteristicProperty.write);
      await UniversalBle.write(_id, s.uuid, c.uuid,
          Uint8List.fromList(bytes),
          withoutResponse: wor);
      _snack('已写入 ${bytes.length} 字节');
    } catch (e) {
      _snack('写入失败: $e');
    }
  }

  static List<int>? _parseHex(String s) {
    final clean = s.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (clean.isEmpty || clean.length.isOdd) return null;
    final out = <int>[];
    for (var i = 0; i < clean.length; i += 2) {
      out.add(int.parse(clean.substring(i, i + 2), radix: 16));
    }
    return out;
  }

  String _dumpText() {
    final sb = StringBuffer();
    sb.writeln('# 小莫划船机 BLE 抓包');
    sb.writeln('设备: ${widget.device.name ?? widget.device.rawName} '
        '(${widget.device.deviceId})');
    sb.writeln('时间: ${DateTime.now()}');
    sb.writeln('');
    sb.writeln('## GATT 结构');
    for (final s in _services) {
      sb.writeln('服务 ${shortUuid(s.uuid)}  ${describeUuid(s.uuid) ?? ""}');
      for (final c in s.characteristics) {
        final props = c.properties.map((p) => p.name).join(',');
        sb.writeln('  特征 ${shortUuid(c.uuid)}  [$props]  '
            '${describeUuid(c.uuid) ?? ""}');
      }
    }
    sb.writeln('');
    sb.writeln('## 数据日志 (${_log.length} 条)');
    for (final e in _log) {
      sb.writeln(
        '${_ts(e.t)}  ${shortUuid(e.charUuid)}  '
        'd=${e.deltaMs ?? "-"}ms  len=${e.value.length}  '
        'HEX ${_hex(e.value)}  ASCII ${_ascii(e.value)}'
        '${e.parsed != null ? "  ⇒ ${e.parsed}" : ""}',
      );
    }
    return sb.toString();
  }

  Future<void> _copyDump() async {
    await Clipboard.setData(ClipboardData(text: _dumpText()));
    _snack('已复制全部日志到剪贴板');
  }

  Future<void> _saveDump() async {
    if (kIsWeb) {
      _snack('Web 不支持文件保存，请用复制');
      return;
    }
    try {
      final name =
          'ble_log_${DateTime.now().millisecondsSinceEpoch}.txt';
      final f = File('${Directory.current.path}${Platform.pathSeparator}$name');
      await f.writeAsString(_dumpText());
      _snack('已保存: ${f.path}');
    } catch (e) {
      _snack('保存失败: $e');
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m)));
  }

  bool get _hasRowerData => _services.any((s) =>
      s.characteristics.any((c) => isRowerDataChar(c.uuid)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name?.isNotEmpty == true
            ? widget.device.name!
            : '设备'),
        actions: [
          IconButton(
            tooltip: '复制全部日志',
            icon: const Icon(Icons.copy_all),
            onPressed: _log.isEmpty ? null : _copyDump,
          ),
          IconButton(
            tooltip: '保存日志到文件',
            icon: const Icon(Icons.save_alt),
            onPressed: _log.isEmpty ? null : _saveDump,
          ),
        ],
      ),
      body: Column(
        children: [
          _statusBar(),
          if (_hasRowerData) _ftmsBanner(),
          Expanded(
            child: Row(
              children: [
                Expanded(flex: 2, child: _gattPanel()),
                const VerticalDivider(width: 1),
                Expanded(flex: 3, child: _logPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: _connected
          ? Colors.green.shade900
          : Colors.red.shade900.withValues(alpha: 0.6),
      child: Row(
        children: [
          Icon(_connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_status)),
          if (!_connected)
            TextButton(onPressed: _connect, child: const Text('重连')),
        ],
      ),
    );
  }

  Widget _ftmsBanner() {
    return Container(
      width: double.infinity,
      color: Colors.green.shade700,
      padding: const EdgeInsets.all(10),
      child: const Text(
        '✅ 检测到标准 FTMS「Rower Data」特征 — 划船机走通用协议，可直接解析数据！',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _gattPanel() {
    if (_services.isEmpty) {
      return const Center(child: Text('无服务（等待连接 / 发现）'));
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        FilledButton.tonalIcon(
          onPressed: _connected ? _subscribeAll : null,
          icon: const Icon(Icons.notifications_active),
          label: const Text('一键订阅所有可通知特征'),
        ),
        const SizedBox(height: 8),
        for (final s in _services) _serviceCard(s),
      ],
    );
  }

  Widget _serviceCard(BleService s) {
    final name = describeUuid(s.uuid);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${shortUuid(s.uuid)}${name != null ? "  ·  $name" : ""}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            for (final c in s.characteristics) _charRow(s, c),
          ],
        ),
      ),
    );
  }

  Widget _charRow(BleService s, BleCharacteristic c) {
    final cName = describeUuid(c.uuid);
    final canNotify =
        c.properties.contains(CharacteristicProperty.notify) ||
            c.properties.contains(CharacteristicProperty.indicate);
    final canRead = c.properties.contains(CharacteristicProperty.read);
    final canWrite =
        c.properties.contains(CharacteristicProperty.write) ||
            c.properties
                .contains(CharacteristicProperty.writeWithoutResponse);
    final subscribed = _subscribed.contains(c.uuid);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${shortUuid(c.uuid)}'
              '${cName != null ? "  ·  $cName" : ""}'),
          Text(
            c.properties.map((p) => p.name).join(' · '),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
          ),
          Wrap(
            spacing: 6,
            children: [
              if (canNotify)
                OutlinedButton(
                  onPressed: _connected ? () => _toggleSubscribe(s, c) : null,
                  child: Text(subscribed ? '取消订阅' : '订阅'),
                ),
              if (canRead)
                OutlinedButton(
                  onPressed: _connected ? () => _read(s, c) : null,
                  child: const Text('读'),
                ),
              if (canWrite)
                OutlinedButton(
                  onPressed: _connected ? () => _write(s, c) : null,
                  child: const Text('写'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _logPanel() {
    return Column(
      children: [
        Container(
          color: Colors.black26,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Text('数据日志 (${_log.length})'),
              const Spacer(),
              const Text('自动滚动', style: TextStyle(fontSize: 12)),
              Switch(
                value: _autoScroll,
                onChanged: (v) => setState(() => _autoScroll = v),
              ),
              IconButton(
                tooltip: '清空',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(_log.clear),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.black,
            child: ListView.builder(
              controller: _logScroll,
              padding: const EdgeInsets.all(8),
              itemCount: _log.length,
              itemBuilder: (_, i) {
                final e = _log[i];
                final rower = e.parsed != null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_ts(e.t)}  ${shortUuid(e.charUuid)}  '
                        'd=${e.deltaMs ?? "-"}ms  len=${e.value.length}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.cyan.shade200),
                      ),
                      Text(
                        _hex(e.value),
                        style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: Colors.greenAccent),
                      ),
                      Text(
                        'ASCII  ${_ascii(e.value)}',
                        style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Colors.grey.shade500),
                      ),
                      if (rower)
                        Text(
                          '⇒ ${e.parsed}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade300,
                              fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  static String _ts(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}.'
      '${t.millisecond.toString().padLeft(3, '0')}';

  static String _hex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join(' ');

  static String _ascii(List<int> b) => b
      .map((x) => (x >= 0x20 && x < 0x7f) ? String.fromCharCode(x) : '.')
      .join();
}
