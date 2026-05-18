import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import 'connecting_screen.dart';

/// 边界态:蓝牙未开启。banner + 禁用「开始划船」+ 重新检测。
class BtOffScreen extends StatelessWidget {
  const BtOffScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const AppBanner('蓝牙未开启 — 请到系统设置打开蓝牙后重试'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(),
                    const RowerBadge(muted: true),
                    const SizedBox(height: 22),
                    const Text('小莫划船机',
                        style: TextStyle(
                            fontSize: 27, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    const Text('AT-R79517 · 等待蓝牙开启',
                        style: TextStyle(
                            color: AppColors.ink2, fontSize: 14)),
                    const SizedBox(height: 30),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 264),
                      child: const AppButton('开始划船',
                          lg: true, kind: AppBtnKind.disabled),
                    ),
                    AppLink('前往系统蓝牙设置', onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('请在系统设置中打开蓝牙,再点「重新检测」')),
                      );
                    }),
                    const Spacer(),
                    AppLink('蓝牙已打开?重新检测', onTap: () {
                      Navigator.of(context).pushReplacement(MaterialPageRoute(
                          builder: (_) => const ConnectingScreen()));
                    }),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
