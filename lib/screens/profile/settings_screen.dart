import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../ble/rower_connection.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hr_connect_sheet.dart';
import '../../widgets/ui.dart';

/// ⑧ 训练标定:米/脉冲、功率系数 k、抓水阈值;心率设备。
/// 保存写入 settings_store,下次训练 WorkoutRecorder 自动用新值。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _mpp;
  late double _k;
  late double _catchHigh;
  late double _catchLow;

  @override
  void initState() {
    super.initState();
    final s = appState.settings;
    _mpp = s.metersPerPulse;
    _k = s.powerK;
    _catchHigh = s.catchHighMs.toDouble();
    _catchLow = s.catchLowMs.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final conn = RowerConnection.instance;
    final hr = appState.settings.hrDevice;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('训练标定', style: AppText.title),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            AppCard(
              child: Column(
                children: [
                  _slider(
                    '米 / 脉冲',
                    '${_mpp.toStringAsFixed(2)} m',
                    _mpp,
                    0.30,
                    0.60,
                    (v) => setState(() => _mpp = v),
                    '划船机无屏幕、无绝对参照,距离 = 飞轮脉冲 × 此系数。'
                        '默认 0.35 ≈ 每桨 8 m(Concept2 室内业余典型),功率会跟着立方变,'
                        '偏高就调小一点,偏低调大一点。',
                  ),
                  const SizedBox(height: 20),
                  _slider(
                    '功率系数 k',
                    _k.toStringAsFixed(2),
                    _k,
                    1.5,
                    4.0,
                    (v) => setState(() => _k = v),
                    'Concept2 模型:功率 = k · 速度³。2.80 为其公开取值。',
                  ),
                  const SizedBox(height: 20),
                  _slider(
                    '抓水高阈 (ms)',
                    '${_catchHigh.round()} ms',
                    _catchHigh,
                    150,
                    400,
                    (v) => setState(() => _catchHigh = v),
                    '回桨间隔升过高阈,随后跌破低阈记一桨,跨多包也能命中。',
                  ),
                  const SizedBox(height: 20),
                  _slider(
                    '抓水低阈 (ms)',
                    '${_catchLow.round()} ms',
                    _catchLow,
                    80,
                    250,
                    (v) => setState(() => _catchLow = v),
                    '低阈应小于高阈;两者间距越大越不易误记桨。',
                  ),
                ],
              ),
            ),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE0E3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.favorite,
                          size: 17, color: AppColors.red),
                    ),
                    title: const Text('心率设备',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      hr != null
                          ? '${hr.name}${conn.hrConnected ? " · 已连接" : " · 已记住"}'
                          : '未连接 · 支持标准 BLE 心率',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.ink3),
                    ),
                    trailing: conn.hrConnected
                        ? const _Pill('已连接', AppColors.ok)
                        : const Icon(Icons.chevron_right,
                            color: AppColors.ink3),
                    onTap: () => showHrConnectSheet(context),
                  ),
                  const Divider(height: 1, color: AppColors.line),
                  ListTile(
                    leading: const Icon(Icons.search, color: AppColors.ink2),
                    title: const Text('重新扫描心率带',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    subtitle: const Text('支持标准 BLE 心率 (Polar / Magene 等)',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.ink3)),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.ink3),
                    onTap: () => showHrConnectSheet(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            AppButton('保存标定', onTap: () async {
              if (_catchLow >= _catchHigh) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('低阈必须小于高阈')));
                return;
              }
              await appState.settings.saveCalibration(
                metersPerPulse: _mpp,
                powerK: _k,
                catchHighMs: _catchHigh.round(),
                catchLowMs: _catchLow.round(),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('标定已保存,下次训练生效')));
              Navigator.of(context).pop();
            }),
          ],
        ),
      ),
    );
  }

  Widget _slider(String label, String val, double v, double min, double max,
      ValueChanged<double> onChanged, String note) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            Text(val,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: AppColors.line,
            thumbColor: Colors.white,
            overlayColor: AppColors.accent.withValues(alpha: 0.12),
            trackHeight: 6,
          ),
          child: Slider(
              value: v.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged),
        ),
        Text(note,
            style: const TextStyle(
                fontSize: 11.5, color: AppColors.ink3, height: 1.6)),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F8EF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
