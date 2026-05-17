import 'package:flutter/material.dart';

import '../app_state.dart';
import '../ble/rower_connection.dart';
import '../theme/app_theme.dart';

/// 心率设备扫描/连接弹窗(仪表盘 ❤ 入口 / 标定页)。
/// 扫标准 0x180D 设备,选中即连并记住。
Future<void> showHrConnectSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _HrSheet(),
  );
}

class _HrSheet extends StatefulWidget {
  const _HrSheet();

  @override
  State<_HrSheet> createState() => _HrSheetState();
}

class _HrSheetState extends State<_HrSheet> {
  final _conn = RowerConnection.instance;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _conn.addListener(_on);
    WidgetsBinding.instance.addPostFrameCallback((_) => _conn.scanHr());
  }

  @override
  void dispose() {
    _conn.removeListener(_on);
    _conn.stopHrScan();
    super.dispose();
  }

  void _on() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final list = _conn.hrDiscovered.values.toList()
      ..sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite, color: AppColors.red, size: 20),
                const SizedBox(width: 8),
                const Text('连接心率设备', style: AppText.title),
                const Spacer(),
                if (_conn.hrScanning)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('标准蓝牙心率(Xiaomi Watch 心率广播 / Polar / Magene 等)',
                style: AppText.weak),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                    child: Text('扫描中… 请在手表/手环开启心率广播',
                        style: TextStyle(color: AppColors.ink3))),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
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
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.favorite_border,
                          color: AppColors.red),
                      title: Text(name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      subtitle: Text('${d.deviceId}  ·  ${d.rssi ?? "?"} dBm',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.ink3)),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.ink3),
                      onTap: _connecting
                          ? null
                          : () async {
                              setState(() => _connecting = true);
                              final ok = await _conn.connectHr(d);
                              if (ok) {
                                await appState.settings.rememberHrDevice(
                                    d.deviceId, name);
                              }
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        ok ? '已连接心率设备 $name' : '心率连接失败,重试')),
                              );
                            },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
