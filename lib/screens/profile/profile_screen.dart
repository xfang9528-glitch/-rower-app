import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../ble/rower_connection.dart';
import '../../data/local_paths.dart';
import '../../models/workout.dart';
import '../../theme/app_theme.dart';
import '../../util/fmt.dart';
import '../../util/workout_stats.dart';
import '../../widgets/hr_connect_sheet.dart';
import 'settings_screen.dart';
import 'user_switch_screen.dart';

/// ⑧ 我的:个人档案 + 累计统计 + 多用户 / 心率 / 标定 / 导出 / 关于。
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final u = appState.users.current;
        final st = WorkoutStats(appState.workouts.items);
        final conn = RowerConnection.instance;
        final s = appState.settings;
        return Column(
          children: [
            SizedBox(
              height: 50,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                child: Row(
                  children: [
                    const Expanded(child: Text('我的', style: AppText.title)),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined,
                          color: AppColors.ink2),
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen())),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0,
                    AppSpacing.screen, AppSpacing.screen),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(u.avatarColorA),
                                Color(u.avatarColorB)
                              ],
                            ),
                          ),
                          child: Text(u.initial,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u.name,
                                  style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              const Text('本地账号 · 数据存本机',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.ink2)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _push(context, const UserSwitchScreen()),
                          child: const Text('切换 ›',
                              style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                  _statsRow(st),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      boxShadow: AppShadows.card,
                    ),
                    child: Column(
                      children: [
                        _item(Icons.group_outlined, '切换 / 添加用户',
                            '每人独立训练记录', '${u.name} ›',
                            onTap: () =>
                                _push(context, const UserSwitchScreen())),
                        _item(
                            Icons.favorite_border,
                            '心率设备',
                            conn.hrConnected
                                ? '${s.hrDevice?.name ?? "已连接"} · 已连接'
                                : (s.hrDevice != null
                                    ? '${s.hrDevice!.name} · 已记住'
                                    : '未连接 · 可选'),
                            '',
                            onTap: () => showHrConnectSheet(context)),
                        _item(
                            Icons.tune,
                            '训练标定',
                            '米/脉冲 ${s.metersPerPulse.toStringAsFixed(2)} · '
                                'k ${s.powerK.toStringAsFixed(2)}',
                            '',
                            onTap: () =>
                                _push(context, const SettingsScreen())),
                        _item(
                            Icons.rowing,
                            '划船机设备',
                            s.rower != null
                                ? '${s.rower!.name} · 已记住'
                                : '未记住',
                            '',
                            onTap: () => _forgetRower(context)),
                        _item(Icons.download_outlined, '导出数据',
                            '导出全部训练记录 CSV', '',
                            onTap: () => _exportCsv(context)),
                        _item(Icons.info_outline, '关于',
                            'v0.3 · 自建 Anytum 协议', '',
                            last: true,
                            onTap: () => _about(context)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _push(BuildContext c, Widget s) =>
      Navigator.of(c).push(MaterialPageRoute(builder: (_) => s));

  Widget _statsRow(WorkoutStats st) {
    Widget col(String v, String u, String l) => Expanded(
          child: Column(
            children: [
              RichText(
                text: TextSpan(
                  text: v,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink),
                  children: [
                    if (u.isNotEmpty)
                      TextSpan(
                          text: u,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(l,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.ink2)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          col('${st.count}', '', '累计训练'),
          _vDiv(),
          col((st.totalDistanceM / 1000).toStringAsFixed(0), 'km', '累计距离'),
          _vDiv(),
          col((st.totalDurationSec / 3600).toStringAsFixed(1), 'h', '累计时长'),
        ],
      ),
    );
  }

  Widget _vDiv() => Container(width: 1, height: 36, color: AppColors.line);

  Widget _item(IconData ic, String title, String sub, String trailing,
      {bool last = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppColors.line)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(ic, size: 18, color: AppColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.ink3)),
                ],
              ),
            ),
            Text(trailing.isEmpty ? '›' : trailing,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.ink3)),
          ],
        ),
      ),
    );
  }

  Future<void> _forgetRower(BuildContext context) async {
    final s = appState.settings;
    if (s.rower == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前没有记住的划船机')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('忘记此划船机?'),
        content: Text('下次需重新自动扫描连接 ${s.rower!.name}。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('忘记')),
        ],
      ),
    );
    if (ok != true) return;
    await s.forgetRower();
    appState.refresh();
  }

  Future<void> _exportCsv(BuildContext context) async {
    final items = appState.workouts.items;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂无记录可导出')));
      return;
    }
    final b = StringBuffer(
        '开始时间,模式,目标,距离m,时长s,桨数,平均配速500m,均功率W,峰值功率W,卡路里,平均心率,达成\n');
    for (final Workout w in items) {
      final p = w.avgPace500;
      b.writeln([
        '${Fmt.ymd(w.startTime)} ${Fmt.hm(w.startTime)}',
        w.goal.mode.name,
        w.goal.targetLabel ?? '',
        w.distanceM.round(),
        w.durationSec,
        w.strokes,
        p == null ? '' : Fmt.dur(p.inSeconds),
        w.avgPower.round(),
        w.peakPower.round(),
        w.calories.round(),
        w.avgHr ?? '',
        w.goalAchieved ? '是' : '',
      ].join(','));
    }
    try {
      final f = await LocalPaths.file(
          'export_${DateTime.now().millisecondsSinceEpoch}.csv');
      await f.writeAsString(b.toString());
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导出 ${items.length} 条:${f.path}')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导出失败:$e')));
    }
  }

  void _about(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('关于'),
        content: const Text(
            '小莫划船机 App v0.3\n\n为停服的小莫/Anytum 划船机自建,'
            '私有 BLE 协议(0xFFE0/0xFFE4)。\n训练指标为无绝对参照的自洽估算。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('好')),
        ],
      ),
    );
  }
}
