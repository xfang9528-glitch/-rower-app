import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../models/training_goal.dart';
import '../../models/workout.dart';
import '../../theme/app_theme.dart';
import '../../util/fmt.dart';
import '../../widgets/line_chart.dart';
import '../../widgets/ui.dart';

/// ⑤ 单次记录详情:统计 + 配速/心率曲线 + 分段明细 + 分享/删除。
/// [fromSession]=true 时由刚结束的训练进入,返回回到首页(而非记录列表)。
class DetailScreen extends StatelessWidget {
  final Workout workout;
  final bool fromSession;
  const DetailScreen(
      {super.key, required this.workout, this.fromSession = false});

  @override
  Widget build(BuildContext context) {
    final w = workout;
    final pace = w.avgPace500;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(fromSession ? Icons.close : Icons.chevron_left),
          onPressed: () => fromSession
              ? Navigator.of(context).popUntil((r) => r.isFirst)
              : Navigator.of(context).pop(),
        ),
        title: Text('${Fmt.mdShort(w.startTime)} 训练',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            if (fromSession)
              Container(
                margin: const EdgeInsets.only(bottom: 13),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F8EF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.ok, size: 16),
                    SizedBox(width: 8),
                    Text('训练已保存到记录',
                        style: TextStyle(
                            color: AppColors.ok,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            // detail-hero
            Column(
              children: [
                Text('${Fmt.ymd(w.startTime)} · ${Fmt.hm(w.startTime)} 开始',
                    style: const TextStyle(
                        color: AppColors.ink2, fontSize: 13)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(Fmt.dist(w.distanceM), style: AppText.detailDist),
                    const Text(' m',
                        style: TextStyle(
                            fontSize: 20, color: AppColors.ink2)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '用时 ${Fmt.dur(w.durationSec)} · ${w.strokes} 桨'
                  '${w.goalAchieved ? " · ${w.goal.mode.label}达成" : ""}',
                  style: const TextStyle(
                      color: AppColors.ink2,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _statGrid(w, pace),
            const SizedBox(height: 14),
            _chartCard('配速曲线 /500m', AppColors.pace,
                LineChart(data: w.paceSeries, color: AppColors.pace)),
            if (w.hrSeries.isNotEmpty)
              _chartCard('心率曲线 bpm', AppColors.heart,
                  LineChart(data: w.hrSeries, color: AppColors.heart)),
            _splitsCard(w),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: AppButton('分享',
                      kind: AppBtnKind.ghost,
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('分享 — 后续迭代')))),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: AppButton('删除',
                      kind: AppBtnKind.danger,
                      onTap: () => _confirmDelete(context)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statGrid(Workout w, Duration? pace) {
    final cells = [
      ('平均配速', pace == null ? '—' : Fmt.dur(pace.inSeconds), AppColors.pace),
      ('平均桨频', w.avgSpm.round().toString(), AppColors.spm),
      ('峰值功率 W', w.peakPower.round().toString(), AppColors.power),
      ('平均功率 W', w.avgPower.round().toString(), AppColors.power),
      ('卡路里 kcal', w.calories.round().toString(), AppColors.calories),
      ('峰值心率', w.peakHr?.toString() ?? '—', AppColors.heart),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.line,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      clipBehavior: Clip.antiAlias,
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.35,
        mainAxisSpacing: 1,
        crossAxisSpacing: 1,
        children: [
          for (final c in cells)
            Container(
              color: AppColors.card,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(c.$2,
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: c.$3)),
                  const SizedBox(height: 4),
                  Text(c.$1,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.ink2)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _chartCard(String title, Color dot, Widget chart) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.card),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: dot, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          chart,
        ],
      ),
    );
  }

  Widget _splitsCard(Workout w) {
    if (w.splits.isEmpty) return const SizedBox.shrink();
    int bestIdx = 0;
    for (var i = 1; i < w.splits.length; i++) {
      if (w.splits[i].pace500 < w.splits[bestIdx].pace500) bestIdx = i;
    }
    TextStyle h = const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.ink3);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.card),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 8),
            const Text('分段明细 · 每 500m',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.5),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
              4: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: AppColors.line))),
                children: [
                  _th('段', h, left: true),
                  _th('用时', h),
                  _th('配速', h),
                  _th('桨频', h),
                  _th('功率', h),
                ],
              ),
              for (var i = 0; i < w.splits.length; i++)
                _row(w.splits[i], i + 1,
                    best: i == bestIdx && w.splits.length > 1),
            ],
          ),
        ],
      ),
    );
  }

  Widget _th(String t, TextStyle s, {bool left = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(t,
            style: s, textAlign: left ? TextAlign.left : TextAlign.right),
      );

  TableRow _row(dynamic sp, int idx, {bool best = false}) {
    final c = best ? AppColors.ok : AppColors.ink;
    TextStyle v = TextStyle(
        fontSize: 12.5, fontWeight: FontWeight.w700, color: c);
    return TableRow(
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line))),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text('$idx · ${sp.distanceM.round()}m',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: best ? AppColors.ok : AppColors.ink2)),
        ),
        _vc(Fmt.dur(sp.durationSec), v),
        _vc(Fmt.dur(sp.pace500.inSeconds), v),
        _vc(sp.avgSpm.round().toString(), v),
        _vc(sp.avgPower.round().toString(), v),
      ],
    );
  }

  Widget _vc(String t, TextStyle s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(t, textAlign: TextAlign.right, style: s),
      );

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这次训练?'),
        content: const Text('删除后不可恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await appState.deleteWorkout(workout.id);
    if (!context.mounted) return;
    fromSession
        ? Navigator.of(context).popUntil((r) => r.isFirst)
        : Navigator.of(context).pop();
  }
}
