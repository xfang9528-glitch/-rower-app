import 'dart:async';

import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

import '../ble/known_uuids.dart';
import 'device_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final Map<String, BleDevice> _devices = {};
  bool _scanning = false;
  AvailabilityState _availability = AvailabilityState.unknown;

  @override
  void initState() {
    super.initState();
    UniversalBle.onAvailabilityChange = (state) {
      if (mounted) setState(() => _availability = state);
    };
    UniversalBle.onScanResult = (device) {
      if (!mounted) return;
      setState(() => _devices[device.deviceId] = device);
    };
  }

  @override
  void dispose() {
    UniversalBle.onScanResult = null;
    if (_scanning) UniversalBle.stopScan();
    super.dispose();
  }

  Future<void> _toggleScan() async {
    if (_scanning) {
      await UniversalBle.stopScan();
      setState(() => _scanning = false);
      return;
    }
    try {
      await UniversalBle.requestPermissions();
    } catch (_) {}
    setState(() {
      _devices.clear();
      _scanning = true;
    });
    try {
      await UniversalBle.startScan();
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    final list = _devices.values.toList()
      ..sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));
    return Scaffold(
      appBar: AppBar(
        title: const Text('小莫划船机 · 蓝牙探测'),
        actions: [
          if (_scanning)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _availabilityBanner(),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text(
                      _scanning ? '扫描中…' : '点击下方按钮开始扫描',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1),
                    itemBuilder: (_, i) => _deviceTile(list[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleScan,
        icon: Icon(_scanning ? Icons.stop : Icons.bluetooth_searching),
        label: Text(_scanning ? '停止' : '扫描'),
      ),
    );
  }

  Widget _availabilityBanner() {
    if (_availability == AvailabilityState.poweredOn ||
        _availability == AvailabilityState.unknown) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      color: Colors.orange.shade900,
      padding: const EdgeInsets.all(8),
      child: Text('蓝牙状态: ${_availability.name} — 请打开蓝牙',
          textAlign: TextAlign.center),
    );
  }

  Widget _deviceTile(BleDevice d) {
    final advertised = d.services
        .map((s) => describeUuid(s) ?? shortUuid(s))
        .toList();
    final looksLikeFtms = d.services.any(
        (s) => s.toLowerCase() == ftmsServiceUuid);
    return ListTile(
      leading: CircleAvatar(
        child: Text('${d.rssi ?? '?'}',
            style: const TextStyle(fontSize: 11)),
      ),
      title: Text(
        (d.name?.isNotEmpty ?? false)
            ? d.name!
            : (d.rawName?.isNotEmpty ?? false)
                ? d.rawName!
                : '(无名设备)',
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(d.deviceId, style: const TextStyle(fontSize: 11)),
          if (advertised.isNotEmpty)
            Text('广播服务: ${advertised.join(", ")}',
                style: const TextStyle(fontSize: 11)),
          if (d.manufacturerDataList.isNotEmpty)
            Text(
              '厂商数据: ${_hex(d.manufacturerDataList.first.toUint8List())}',
              style: const TextStyle(
                  fontSize: 11, fontFamily: 'monospace'),
            ),
        ],
      ),
      trailing: looksLikeFtms
          ? const Chip(
              label: Text('FTMS', style: TextStyle(fontSize: 11)),
              backgroundColor: Colors.green,
              visualDensity: VisualDensity.compact,
            )
          : const Icon(Icons.chevron_right),
      isThreeLine: advertised.isNotEmpty,
      onTap: () async {
        if (_scanning) {
          await UniversalBle.stopScan();
          setState(() => _scanning = false);
        }
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DeviceScreen(device: d),
        ));
      },
    );
  }

  static String _hex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join(' ');
}
