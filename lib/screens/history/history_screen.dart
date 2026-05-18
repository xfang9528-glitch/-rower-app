import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../models/workout.dart';
import '../../theme/app_theme.dart';
import '../../util/fmt.dart';
import '../../util/workout_stats.dart';
import '../../widgets/line_chart.dart';
import '../../widgets/ui.dart';
import 'detail_screen.dart';

/// ④/⑥ 训练记录:列表(按日分组+本周汇总+迷你曲线)与 趋势&最佳 分段切换。
/// 无记录 → 空状态引导。数据来自当前用户(切用户自动刷新)。
class HistoryScreen extends StatefulWidget {
  final VoidCallback? onStartTraining;
  const HistoryScreen({super.key, this.onStartTraining});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _seg = 0; // 0 列表, 1 趋势

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final items = appState.workouts.items;
        return Column(
          children: [
            const SizedBox(
              height: 50,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('训练记录', style: AppText.title),
                ),
              ),
            ),
            if (items.isEmpty)
              Expanded(child: _empty())
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.screen),
                  children: [
                    _segControl(),
                    if (_seg == 0)
                      ..._listBody(items)
                    else
                      ..._trendsBody(items),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 44),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
                color: AppColors.accentSoft, shape: BoxShape.circle),
            child: const Icon(Icons.rowing, size: 44, color: AppColors.accent),
          ),
          const SizedBox(height: 16),
          const Text('还没有训练记录',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          const Text(
            '连接划船机,拉第一桨就开始自动记录。\n每次训练的配速、距离、卡路里都会存在这里。',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.ink2, fontSize: 13, height: 1.7),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: AppButton('开始第一次训练',
                lg: true, onTap: widget.onStartTraining),
          ),
        ],
      ),
    );
  }

  Widget _segControl() {
    Widget seg(String t, int i) => Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _seg = i),
            child: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: _seg == i ? AppColors.card : null,
                borderRadius: BorderRadius.circular(10),
                boxShadow: _seg == i ? AppShadows.card : null,
              ),
              child: Text(t,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color:
                          _seg == i ? AppColors.accent : AppColors.ink2)),
            ),
          ),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EBF2),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(children: [seg('列表', 0), seg('趋势 & 最佳', 1)]),
    );
  }

  // ---------------- 列表 ----------------
  List<Widget> _listBody(List<Workout> items) {
    final st = WorkoutStats(items);
    final ws = st.weekSummary;
    final groups = st.groupedByDay();
    return [
      _weekSummary('本周次数', '${ws.count}', '本周距离',
          (ws.distM / 1000).toStringAsFixed(1), 'km', '本周时长',
          '${(ws.durSec / 60).round()}', 'min'),
      for (final g in groups) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 9),
          child: Text(Fmt.dayLabel(g.day),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink3)),
        ),
        for (final w in g.items) _recCard(w),
      ],
    ];
  }

  Widget _weekSummary(String l1, String v1, String l2, String v2, String u2,
      String l3, String v3, String u3) {
    Widget col(String v, String u, String l) => Expanded(
          child: Column(
            children: [
              RichText(
                text: TextSpan(
                  text: v,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink),
                  children: [
                    if (u.isNotEmpty)
                      TextSpan(
                          text: u,
                          style: const TextStyle(
                              fontSize: 12,
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
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          col(v1, '', l1),
          _vDiv(),
          col(v2, u2, l2),
          _vDiv(),
          col(v3, u3, l3),
        ],
      ),
    );
  }

  Widget _vDiv() =>
      Container(width: 1, height: 38, color: AppColors.line);

  Widget _recCard(Workout w) {
    final pace = w.avgPace500;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DetailScreen(workout: w))),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.card),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Column(
                children: [
                  Text(Fmt.hm(w.startTime),
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent)),
                  const Text('开始',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.ink3)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${Fmt.dist(w.distanceM)} m',
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    children: [
                      _meta('⏱ ${Fmt.dur(w.durationSec)}'),
                      _meta(
                          '⚡ ${pace == null ? "—" : Fmt.dur(pace.inSeconds)}/500m'),
                      _meta('🔥 ${w.calories.round()} kcal'),
                    ],
                  ),
                ],
              ),
            ),
            Sparkline(
                data: w.paceSeries.isEmpty ? const [1, 1] : w.paceSeries,
                color: AppColors.accent),
          ],
        ),
      ),
    );
  }

  Widget _meta(String t) => Text(t,
      style: const TextStyle(fontSize: 12, color: AppColors.ink2));

  // ---------------- 趋势 & 最佳 ----------------
  List<Widget> _trendsBody(List<Workout> items) {
    final st = WorkoutStats(items);
    final wk = st.weeklyDistance();
    final maxKm =
        wk.map((e) => e.km).fold(0.0, (a, b) => a > b ? a : b);
    final streak = st.streak;
    final ld = st.longestDistance;
    final lt = st.longestDuration;
    return [
      _weekSummary('训练次数', '${st.count}', '总距离',
          (st.totalDistanceM / 1000).toStringAsFixed(1), 'km', '总时长',
          (st.totalDurationSec / 3600).toStringAsFixed(1), 'h'),
      _card('每周距离 (km)', AppColors.accent, _bars(wk, maxKm)),
      _card('平均配速趋势  (越低越快 ↓)', AppColors.pace,
          LineChart(data: st.weeklyAvgPace(), color: AppColors.pace,
              height: 90)),
      Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
            '🔥 连续打卡 ${streak.current} 天 · 历史最长 ${streak.longest} 天',
            style: const TextStyle(
                color: Color(0xFFC2630A),
                fontSize: 12.5,
                fontWeight: FontWeight.w700)),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 2, 4, 9),
        child: Text('个人最佳 (PR)',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.ink3)),
      ),
      Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            _prRow('500 m', st.prFor(500)),
            _prRow('1000 m', st.prFor(1000)),
            _prRow('2000 m', st.prFor(2000)),
            _prRow('5000 m', st.prFor(5000)),
            _prRow('最长单次距离', ld.value),
            _prRow('最长单次时长', lt.value, last: true),
          ],
        ),
      ),
    ];
  }

  Widget _card(String title, Color dot, Widget child) {
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
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _bars(List<({String label, double km})> wk, double maxKm) {
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final b in wk)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(b.km == 0 ? '' : b.km.toStringAsFixed(0),
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.ink3)),
                    const SizedBox(height: 2),
                    Container(
                      height: maxKm <= 0
                          ? 4
                          : (b.km / maxKm * 86).clamp(4, 86),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF6E97FF), Color(0xFF2F6BFF)],
                        ),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(b.label,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.ink3)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _prRow(String label, String value, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600))),
          Text(value,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
        ],
      ),
    );
  }
}
