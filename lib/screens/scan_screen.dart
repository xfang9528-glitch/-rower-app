import 'dart:async';

import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

import '../ble/known_uuids.dart';
import '../ble/paired_store.dart';
import '../ble/session_log.dart';
import 'device_screen.dart';

/// 划船机蓝牙名固定为此值;广播服务为 0xFFE0。
const String kAutoConnectName = 'AT-R79517';
const String kRowerService = '0000ffe0-0000-1000-8000-00805f9b34fb';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final Map<String, BleDevice> _devices = {};
  bool _scanning = false;
  bool _autoNavigated = false;
  bool _showAll = false;
  ({String id, String name})? _paired;
  AvailabilityState _availability = AvailabilityState.unknown;

  @override
  void initState() {
    super.initState();
    _paired = PairedStore.load();
    UniversalBle.onAvailabilityChange = (state) {
      SessionLog.line('[蓝牙状态] ${state.name}');
      if (mounted) setState(() => _availability = state);
    };
    UniversalBle.onScanResult = (device) {
      if (!mounted) return;
      final isNew = !_devices.containsKey(device.deviceId);
      setState(() => _devices[device.deviceId] = device);
      if (isNew) {
        SessionLog.line('[发现设备] name="${device.name}" '
            'raw="${device.rawName}" id=${device.deviceId} '
            'rssi=${device.rssi} 广播服务=${device.services}');
      }
      final n = (device.name ?? device.rawName ?? '').trim();
      final isTarget = n == kAutoConnectName ||
          (_paired != null && device.deviceId == _paired!.id);
      if (!_autoNavigated && isTarget) {
        _autoNavigated = true;
        SessionLog.line('[自动匹配] 命中 $n，直连…');
        _openDevice(device);
      }
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  @override
  void dispose() {
    UniversalBle.onScanResult = null;
    if (_scanning) UniversalBle.stopScan();
    super.dispose();
  }

  Future<void> _openDevice(BleDevice d) async {
    if (_scanning) {
      await UniversalBle.stopScan();
      if (mounted) setState(() => _scanning = false);
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DeviceScreen(device: d),
    ));
    _autoNavigated = true;
    setState(() => _paired = PairedStore.load());
  }

  Future<void> _startScan({bool all = false}) async {
    if (_scanning) await UniversalBle.stopScan();
    SessionLog.start('目标设备: $kAutoConnectName'
        '${_paired != null ? " (已记住 ${_paired!.id})" : ""}');
    try {
      await UniversalBle.requestPermissions();
    } catch (_) {}
    setState(() {
      _devices.clear();
      _scanning = true;
      _showAll = all;
    });
    SessionLog.line('[扫描] 开始${all ? "(全部设备)" : "(只过滤划船机)"}…');
    try {
      await UniversalBle.startScan(
        scanFilter: all
            ? null
            : ScanFilter(
                withServices: [kRowerService],
                withNamePrefix: ['AT'],
              ),
      );
    } catch (e) {
      SessionLog.line('[扫描失败] $e');
      if (mounted) {
        setState(() => _scanning = false);
        _snack('扫描失败: $e');
      }
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _isCandidate(BleDevice d) {
    final n = (d.name ?? d.rawName ?? '').trim();
    return n.startsWith('AT') ||
        d.services.any((s) => s.toLowerCase() == kRowerService);
  }

  @override
  Widget build(BuildContext context) {
    final all = _devices.values.toList()
      ..sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));
    final candidates =
        _showAll ? all : all.where(_isCandidate).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('小莫划船机')),
      body: Column(
        children: [
          if (_availability != AvailabilityState.poweredOn &&
              _availability != AvailabilityState.unknown)
            Container(
              width: double.infinity,
              color: Colors.orange.shade900,
              padding: const EdgeInsets.all(8),
              child: Text('蓝牙未开启 (${_availability.name})',
                  textAlign: TextAlign.center),
            ),
          Expanded(
            child: _showAll
                ? _allDevicesList(candidates)
                : _connectCard(candidates),
          ),
        ],
      ),
    );
  }

  /// 默认干净界面:只显示"这台划船机 + 连接按钮",不堆一屏蓝牙设备。
  Widget _connectCard(List<BleDevice> candidates) {
    final name = _paired?.name.isNotEmpty == true
        ? _paired!.name
        : kAutoConnectName;
    BleDevice? found;
    for (final d in candidates) {
      final n = (d.name ?? d.rawName ?? '').trim();
      if (n == kAutoConnectName ||
          (_paired != null && d.deviceId == _paired!.id)) {
        found = d;
        break;
      }
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rowing,
                size: 72, color: Colors.blue.shade300),
            const SizedBox(height: 16),
            Text(name,
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              _paired != null ? '已记住的划船机' : '小莫划船机',
              style: TextStyle(color: Colors.grey.shade400),
            ),
            const SizedBox(height: 28),
            if (found != null)
              FilledButton.icon(
                onPressed: () => _openDevice(found!),
                icon: const Icon(Icons.bluetooth_connected),
                style: FilledButton.styleFrom(
                    minimumSize: const Size(220, 52)),
                label: const Text('连接', style: TextStyle(fontSize: 18)),
              )
            else
              Column(
                children: [
                  const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(height: 14),
                  Text(
                    _scanning
                        ? '正在查找…\n请确认划船机已开机,拉一下手柄唤醒'
                        : '未在扫描',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                ],
              ),
            const SizedBox(height: 36),
            TextButton(
              onPressed: () => _startScan(all: true),
              child: const Text('找不到?显示全部蓝牙设备'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _allDevicesList(List<BleDevice> list) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.black26,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                  child: Text(_scanning
                      ? '扫描全部设备中… (${list.length})'
                      : '共 ${list.length} 个')),
              TextButton(
                onPressed: () => _startScan(all: false),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('扫描中…'))
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => _deviceTile(list[i]),
                ),
        ),
      ],
    );
  }

  Widget _deviceTile(BleDevice d) {
    final advertised =
        d.services.map((s) => describeUuid(s) ?? shortUuid(s)).toList();
    return ListTile(
      leading: CircleAvatar(
        child: Text('${d.rssi ?? '?'}',
            style: const TextStyle(fontSize: 11)),
      ),
      title: Text((d.name?.isNotEmpty ?? false)
          ? d.name!
          : (d.rawName?.isNotEmpty ?? false)
              ? d.rawName!
              : '(无名设备)'),
      subtitle: Text(
        '${d.deviceId}'
        '${advertised.isNotEmpty ? "\n${advertised.join(", ")}" : ""}',
        style: const TextStyle(fontSize: 11),
      ),
      isThreeLine: advertised.isNotEmpty,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openDevice(d),
    );
  }
}
