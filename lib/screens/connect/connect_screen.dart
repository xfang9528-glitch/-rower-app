import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../goal/goal_setup_screen.dart';
import 'all_devices_screen.dart';
import 'connecting_screen.dart';

/// ① 启动页:大按钮「开始划船」零点击连接;次入口选训练目标;兜底手动选。
class ConnectScreen extends StatelessWidget {
  final VoidCallback? onOpenProfile;
  const ConnectScreen({super.key, this.onOpenProfile});

  @override
  Widget build(BuildContext context) {
    final rower = appState.settings.rower;
    final name = (rower?.name.isNotEmpty ?? false) ? rower!.name : '小莫划船机';
    final sub = rower != null ? 'AT-R79517 · 已记住' : 'AT-R79517';

    return Column(
      children: [
        SizedBox(
          height: 50,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: Row(
              children: [
                const Expanded(child: Text('小莫划船机', style: AppText.title)),
                _circleAction(
                  Icons.person_outline_rounded,
                  onTap: onOpenProfile,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(),
                const RowerBadge(),
                const SizedBox(height: 22),
                Text(name,
                    style: const TextStyle(
                        fontSize: 27, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(sub,
                    style: const TextStyle(
                        color: AppColors.ink2, fontSize: 14)),
                const SizedBox(height: 20),
                Text(
                  '开机后自动连接,中途无需任何操作\n点「开始划船」,拉一下手柄唤醒即可',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.ink3, fontSize: 12.5, height: 1.7),
                ),
                const SizedBox(height: 30),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 264),
                  child: AppButton(
                    '开始划船',
                    icon: Icons.play_arrow_rounded,
                    lg: true,
                    onTap: () => _start(context),
                  ),
                ),
                const SizedBox(height: 11),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 264),
                  child: AppButton(
                    '选择训练目标(定距 / 间歇…)',
                    icon: Icons.flag_outlined,
                    kind: AppBtnKind.ghost,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const GoalSetupScreen())),
                  ),
                ),
                const Spacer(),
                AppLink('连不上?手动选择蓝牙设备',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const AllDevicesScreen()))),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _start(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const ConnectingScreen(),
    ));
  }

  Widget _circleAction(IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: AppColors.card,
          shape: BoxShape.circle,
          boxShadow: AppShadows.card,
        ),
        child: Icon(icon, size: 18, color: AppColors.ink2),
      ),
    );
  }
}
