import 'package:flutter/material.dart';

import '../../ble/known_uuids.dart';
import '../../ble/rower_connection.dart';
import '../../theme/app_theme.dart';
import 'connecting_screen.dart';

/// ② 全部蓝牙设备(兜底手动选)。不过滤扫描,按 RSSI 排序。
class AllDevicesScreen extends StatefulWidget {
  const AllDevicesScreen({super.key});

  @override
  State<AllDevicesScreen> createState() => _AllDevicesScreenState();
}

class _AllDevicesScreenState extends State<AllDevicesScreen> {
  final _conn = RowerConnection.instance;

  @override
  void initState() {
    super.initState();
    _conn.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _conn.scanAll());
  }

  @override
  void dispose() {
    _conn.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final list = _conn.sortedDiscovered;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('全部蓝牙设备', style: AppText.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                _conn.state == RowerConnState.scanning
                    ? '扫描中 · ${list.length}'
                    : '共 ${list.length}',
                style: AppText.weak,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: list.isEmpty
            ? const Center(
                child: Text('扫描中…', style: TextStyle(color: AppColors.ink3)))
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.screen),
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppColors.line),
                itemBuilder: (_, i) {
                  final d = list[i];
                  final name = (d.name?.isNotEmpty ?? false)
                      ? d.name!
                      : (d.rawName?.isNotEmpty ?? false)
                          ? d.rawName!
                          : '(无名设备)';
                  final adv = d.services
                      .map((s) => describeUuid(s) ?? shortUuid(s))
                      .join(', ');
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text('${d.rssi ?? '?'}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent)),
                    ),
                    title: Text(name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${d.deviceId}${adv.isNotEmpty ? "\n$adv" : ""}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.ink3),
                    ),
                    isThreeLine: adv.isNotEmpty,
                    trailing:
                        const Icon(Icons.chevron_right, color: AppColors.ink3),
                    onTap: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                          builder: (_) =>
                              ConnectingScreen(manualDevice: d)),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
