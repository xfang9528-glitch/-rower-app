import 'package:flutter/material.dart';

import '../../ble/rower_connection.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import 'all_devices_screen.dart';
import 'connecting_screen.dart';

/// 边界态:重试上限后仍连不上。重试 / 手动选设备 / 返回。
class ConnFailScreen extends StatelessWidget {
  const ConnFailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final msg = RowerConnection.instance.statusMessage;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 34),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFDEBEC),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.priority_high_rounded,
                      size: 38, color: AppColors.red),
                ),
                const SizedBox(height: 18),
                const Text('连接失败',
                    style: TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(
                  msg.isEmpty ? '连不上 $kAutoConnectName' : msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.ink2, fontSize: 14),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    '确认划船机已通电,并拉一下手柄唤醒它;\n太远或被遮挡也会连不上',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Color(0xFFC2630A),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.7),
                  ),
                ),
                const SizedBox(height: 26),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: AppButton('重试连接', onTap: () {
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (_) => const ConnectingScreen()));
                  }),
                ),
                AppLink('手动选择蓝牙设备',
                    onTap: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                            builder: (_) => const AllDevicesScreen()))),
                AppLink('返回',
                    onTap: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
