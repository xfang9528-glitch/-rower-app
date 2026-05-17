import 'package:flutter/material.dart';

import '../../models/training_goal.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../connect/connecting_screen.dart';

/// ③ 训练目标设置:6 模式单选 + 参数面板联动 + 收藏训练 + 开始按钮文案联动。
/// 选好目标 →「开始训练」进连接流程,目标随流程串到仪表盘。
class GoalSetupScreen extends StatefulWidget {
  const GoalSetupScreen({super.key});

  @override
  State<GoalSetupScreen> createState() => _GoalSetupScreenState();
}

class _Preset {
  final String label;
  final List<String> chips;
  final int defaultIdx;
  const _Preset(this.label, this.chips, this.defaultIdx);
}

class _GoalSetupScreenState extends State<GoalSetupScreen> {
  // 与 prototype 的 paramCfg 一致。
  static const Map<TrainingMode, _Preset?> _cfg = {
    TrainingMode.free: null,
    TrainingMode.distance:
        _Preset('目标距离', ['500 m', '1000 m', '2000 m', '5000 m', '自定义…'], 2),
    TrainingMode.time:
        _Preset('目标时间', ['5 min', '10 min', '20 min', '30 min', '自定义…'], 2),
    TrainingMode.calorie: _Preset(
        '目标卡路里', ['50 kcal', '100 kcal', '200 kcal', '300 kcal', '自定义…'], 1),
    TrainingMode.interval:
        _Preset('间歇方案', ['4×500m', '5×500m', '6×250m', '8×250m', '自定义…'], 1),
    TrainingMode.pace: _Preset(
        '目标配速 /500m', ['1:50', '1:55', '2:00', '2:05', '自定义…'], 2),
  };

  TrainingMode _mode = TrainingMode.distance;
  int _chipIdx = 2;
  String? _customLabel; // 自定义档位文案

  _Preset? get _preset => _cfg[_mode];

  String? get _selectedChipLabel {
    final p = _preset;
    if (p == null) return null;
    if (_chipIdx == p.chips.length - 1) return _customLabel; // 自定义…
    return p.chips[_chipIdx];
  }

  /// 归一化目标量(米/秒/kcal),用于后续"达成"判定;间歇/配速暂不归一。
  double? _targetValue(String? label) {
    if (label == null) return null;
    final num = RegExp(r'[\d.]+').firstMatch(label)?.group(0);
    if (num == null) return null;
    final v = double.tryParse(num);
    if (v == null) return null;
    return switch (_mode) {
      TrainingMode.distance => v,
      TrainingMode.time => v * 60,
      TrainingMode.calorie => v,
      _ => null,
    };
  }

  TrainingGoal get _goal {
    final label = _selectedChipLabel;
    return TrainingGoal(
      mode: _mode,
      targetLabel: label,
      targetValue: _targetValue(label),
    );
  }

  void _selectMode(TrainingMode m) {
    setState(() {
      _mode = m;
      _chipIdx = _cfg[m]?.defaultIdx ?? 0;
      _customLabel = null;
    });
  }

  Future<void> _tapChip(int i) async {
    final p = _preset!;
    if (i == p.chips.length - 1) {
      // 自定义…:定距/定时/定卡 支持数字输入;间歇/配速 细节延后(PRD §7)。
      if (_mode == TrainingMode.interval || _mode == TrainingMode.pace) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('自定义间歇/配速方案 — 后续迭代')));
        return;
      }
      final v = await _askCustom();
      if (v == null) return;
      setState(() {
        _chipIdx = i;
        _customLabel = v;
      });
    } else {
      setState(() {
        _chipIdx = i;
        _customLabel = null;
      });
    }
  }

  Future<String?> _askCustom() async {
    final ctrl = TextEditingController();
    final (unit, hint) = switch (_mode) {
      TrainingMode.distance => ('m', '如 3000'),
      TrainingMode.time => ('min', '如 45'),
      TrainingMode.calorie => ('kcal', '如 250'),
      _ => ('', ''),
    };
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('自定义${_preset!.label}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: hint, suffixText: unit),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('确定')),
        ],
      ),
    );
    if (v == null || v.isEmpty || double.tryParse(v) == null) return null;
    return switch (_mode) {
      TrainingMode.distance => '$v m',
      TrainingMode.time => '$v min',
      TrainingMode.calorie => '$v kcal',
      _ => v,
    };
  }

  void _loadFavorite(TrainingGoal g, int chipIdx) {
    setState(() {
      _mode = g.mode;
      _chipIdx = chipIdx;
      _customLabel =
          (_cfg[g.mode] != null && chipIdx == _cfg[g.mode]!.chips.length - 1)
              ? g.targetLabel
              : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('选择训练', style: AppText.title),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFE9F8EF),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Text('选个目标开始,也可直接自由划',
                  style: TextStyle(
                      color: AppColors.ok,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 14),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final m in TrainingMode.values) _modeRow(m),
                ],
              ),
            ),
            if (_preset != null) _paramBox(_preset!),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 9),
              child: Text('收藏的训练',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink3)),
            ),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _favRow('2000m 计时赛', '个人最佳 8:24',
                      const TrainingGoal(
                          mode: TrainingMode.distance,
                          targetLabel: '2000 m',
                          targetValue: 2000),
                      2),
                  _favRow('5×500m 间歇', '组间休 1′00″',
                      const TrainingGoal(
                          mode: TrainingMode.interval,
                          targetLabel: '5×500m'),
                      1),
                  _favRow('30 分钟 UT2 有氧', '目标桨频 ≤ 22',
                      const TrainingGoal(
                          mode: TrainingMode.time,
                          targetLabel: '30 min',
                          targetValue: 1800),
                      3,
                      last: true),
                ],
              ),
            ),
            const SizedBox(height: 2),
            AppButton(
              _goal.startButtonLabel,
              icon: Icons.play_arrow_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ConnectingScreen(goal: _goal))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeRow(TrainingMode m) {
    final sel = m == _mode;
    return InkWell(
      onTap: () => _selectMode(m),
      child: Container(
        decoration: BoxDecoration(
          color: sel ? AppColors.accentSoft : null,
          border: const Border(
              bottom: BorderSide(color: AppColors.line, width: 1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(_modeIcon(m), size: 18, color: AppColors.accent),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(m.subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.ink3)),
                ],
              ),
            ),
            Container(
              width: 21,
              height: 21,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: sel ? AppColors.accent : const Color(0xFFCBD3E0),
                    width: 2),
                color: sel ? AppColors.accent : null,
              ),
              child: sel
                  ? const Icon(Icons.circle, size: 7, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  IconData _modeIcon(TrainingMode m) => switch (m) {
        TrainingMode.free => Icons.rowing,
        TrainingMode.distance => Icons.straighten,
        TrainingMode.time => Icons.timer_outlined,
        TrainingMode.calorie => Icons.local_fire_department,
        TrainingMode.interval => Icons.show_chart,
        TrainingMode.pace => Icons.gps_fixed,
      };

  Widget _paramBox(_Preset p) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.card),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F9),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 11),
            child: Text(p.label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink2)),
          ),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              for (var i = 0; i < p.chips.length; i++)
                _chip(
                  i == p.chips.length - 1 && _customLabel != null
                      ? _customLabel!
                      : p.chips[i],
                  on: i == _chipIdx,
                  onTap: () => _tapChip(i),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, {required bool on, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.chip),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: on ? AppColors.accent : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          boxShadow: on
              ? const [
                  BoxShadow(
                      color: Color(0x4D2F6BFF),
                      blurRadius: 14,
                      offset: Offset(0, 6))
                ]
              : AppShadows.card,
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: on ? Colors.white : AppColors.ink)),
      ),
    );
  }

  Widget _favRow(String title, String sub, TrainingGoal g, int chipIdx,
      {bool last = false}) {
    return InkWell(
      onTap: () => _loadFavorite(g, chipIdx),
      child: Container(
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(
                  bottom: BorderSide(color: AppColors.line, width: 1)),
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
              child: const Icon(Icons.star_rounded,
                  size: 18, color: AppColors.accent),
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
            const Icon(Icons.chevron_right, color: AppColors.ink3),
          ],
        ),
      ),
    );
  }
}
