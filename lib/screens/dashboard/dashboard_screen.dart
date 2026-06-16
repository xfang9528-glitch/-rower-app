import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../app_state.dart';
import '../../ble/rower_connection.dart';
import '../../ble/rowing_metrics.dart';
import '../../models/training_goal.dart';
import '../../models/workout.dart';
import '../../session/workout_recorder.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hr_connect_sheet.dart';
import '../../widgets/ui.dart';
import '../history/detail_screen.dart';
import 'raw_debug_screen.dart';

/// ④ 实时训练仪表盘:hero 配速 + 心率带 + 6 指标 tile + 每500m分段表。
/// WorkoutRecorder 实时收敛,停桨 90s 或目标达成自动收尾落盘。
class DashboardScreen extends StatefulWidget {
  final TrainingGoal goal;
  const DashboardScreen({super.key, this.goal = const TrainingGoal.free()});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WindowListener {
  // #8 浮层小窗目前只实现 + 实测了 Windows(macOS/Linux 的 window_manager
  // 同样可用,但本仓未验证,故先不开;要开把这里放宽即可)。
  static final bool _overlaySupported = !kIsWeb && Platform.isWindows;

  final _conn = RowerConnection.instance;
  late final WorkoutRecorder _rec;
  bool _completing = false;

  // 浮层小窗模式。窗口尺寸/置顶的切换由 _syncWindow 串行收敛(防 blur/focus
  // 快速来回时的竞态:旧实现 _overlayMode 在 await 后才置位,会导致
  // ① 已聚焦却卡小窗 ② getSize 读到未还原的小尺寸污染 _normalSize)。
  bool _overlayMode = false;
  Size _normalSize = const Size(1280, 720); // main.cpp 初始尺寸
  bool? _desiredOverlay; // 最新意图;null = 无待处理
  Future<void>? _syncFuture; // 收敛中的 in-flight future,兼作串行闸

  @override
  void initState() {
    super.initState();
    final s = appState.settings;
    _rec = WorkoutRecorder(
      goal: widget.goal,
      conn: _conn,
      tuning: RowingTuning(
        metersPerPulse: s.metersPerPulse,
        powerK: s.powerK,
        catchHighMs: s.catchHighMs,
        catchLowMs: s.catchLowMs,
      ),
    );
    _rec.start();
    _rec.addListener(_onRec);
    _conn.addListener(_onConn);
    // 已记住的心率设备 → 后台静默按名字前缀自动重连(无需用户操作;
    // 小米表 RPA 地址轮换,不能只靠 id)。命中不了就退回手动 ❤。
    final hr = s.hrDevice;
    if (hr != null && !_conn.hrConnected) {
      _conn.autoConnectRememberedHr(hr.id, hr.name);
    }
    if (_overlaySupported) windowManager.addListener(this);
  }

  @override
  void dispose() {
    if (_overlaySupported) {
      windowManager.removeListener(this);
      // 训练结束导航离开时确保窗口状态已还原(正常路径在 _complete 里 await 还原,
      // 这里作为安全兜底:dispose 不能 await,fire-and-forget)。
      if (_overlayMode) {
        windowManager.setAlwaysOnTop(false);
        windowManager.setSize(_normalSize);
      }
    }
    _rec.removeListener(_onRec);
    _conn.removeListener(_onConn);
    _rec.dispose();
    super.dispose();
  }

  // ── 浮层小窗(WindowListener) ──────────────────────────────────────────

  @override
  void onWindowBlur() {
    if (_rec.finished || !mounted) return;
    // 仅当仪表盘是栈顶路由才进浮层:用户若开着子页(调试页/详情页)再切出,
    // 浮层会被子页盖住、只剩被压扁的子页,所以这种情况不缩窗。
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    _requestOverlay(true);
  }

  @override
  void onWindowFocus() {
    if (mounted) _requestOverlay(false);
  }

  /// 记下最新意图并驱动收敛。blur/focus 快速来回时,中间态被折叠,
  /// 最终只落到与焦点一致的状态。`??=` 保证同一时刻只有一条收敛在跑,
  /// 已在跑时仅更新 _desiredOverlay,由那条的 while 循环捡起。
  void _requestOverlay(bool want) {
    _desiredOverlay = want;
    _syncFuture ??= _syncWindow();
  }

  /// 串行收敛窗口状态到 [_desiredOverlay]。同一时刻只有一条在跑
  /// (由 [_requestOverlay] 的 `??=` 保证)—— 这是竞态/污染的根因:
  /// 因为只有在 `_overlayMode == false`(窗口确在常规尺寸)时才会读
  /// getSize() 存入 _normalSize,小窗尺寸绝不会污染 _normalSize。
  Future<void> _syncWindow() async {
    try {
      while (mounted &&
          _desiredOverlay != null &&
          _desiredOverlay != _overlayMode) {
        final want = _desiredOverlay!;
        _desiredOverlay = null;
        if (want) {
          // 此刻 _overlayMode==false ⇒ 窗口为常规尺寸,读到的才是真·原尺寸。
          _normalSize = await windowManager.getSize();
          await windowManager.setAlwaysOnTop(true);
          await windowManager.setSize(const Size(260, 110));
        } else {
          await windowManager.setAlwaysOnTop(false);
          await windowManager.setSize(_normalSize);
        }
        if (mounted) setState(() => _overlayMode = want);
      }
    } finally {
      _syncFuture = null;
    }
  }

  /// 训练收尾前同步还原窗口(直接 await 在跑的收敛),保证导航离开时窗口干净。
  Future<void> _restoreWindow() async {
    _requestOverlay(false);
    await _syncFuture;
  }

  void _onConn() {
    if (mounted) setState(() {});
  }

  void _onRec() {
    if (!mounted) return;
    // 收尾统一走这一条路:手动按钮和停桨/达成自动收尾都先 finalizeAndStop()
    // (同步 notifyListeners)→ 这里检测 finished → _complete()(自带重入守卫)。
    if (_rec.finished) {
      _complete();
      return;
    }
    setState(() {});
  }

  void _finishTap() => _rec.finalizeAndStop();

  Future<void> _complete() async {
    if (_completing) return;
    _completing = true;
    if (_overlaySupported) await _restoreWindow(); // 训练结束,先还原窗口再导航
    final Workout? w = _rec.result;
    await _conn.disconnectDevice();
    if (!mounted) return;
    if (w == null) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('训练太短,未保存')),
      );
      return;
    }
    final saved = await appState.saveWorkout(w);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => DetailScreen(workout: saved, fromSession: true)));
  }

  String _fmtPace(Duration? d) => d == null
      ? '—'
      : '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  String _fmtDur(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_overlayMode && _overlaySupported) return _buildOverlay();
    final m = _rec.metrics;
    final moving = _conn.lastSample?.moving ?? false;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              _header(),
              _statusStrip(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.screen),
                  children: [
                    _hero(m, moving),
                    const SizedBox(height: 13),
                    _hrBand(),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.75,
                      mainAxisSpacing: 11,
                      crossAxisSpacing: 11,
                      children: [
                        _tile('桨频 SPM',
                            m.spm == 0 ? '—' : m.spm.round().toString(),
                            AppColors.spm),
                        _tile('实时功率',
                            m.powerW == 0 ? '—' : m.powerW.round().toString(),
                            AppColors.power,
                            unit: 'W'),
                        _tile('距离', m.distanceM.toStringAsFixed(0),
                            AppColors.distance,
                            unit: 'm'),
                        _tile('桨数', m.strokeCount.toString(), AppColors.ink),
                        _tile('时间', _fmtDur(_rec.elapsed), AppColors.ink),
                        _tile('卡路里', _rec.calories.round().toString(),
                            AppColors.calories,
                            unit: 'kcal'),
                      ],
                    ),
                    const SizedBox(height: 13),
                    _splitsCard(m),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        moving
                            ? '运动中 · 脉冲 ${m.sessionPulses} · 间隔 ${_conn.lastSample?.intervalMs ?? "-"} ms'
                            : '静止 · 拉动手柄开始 · 累计脉冲 ${_conn.lastSample?.totalPulses ?? 0}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.ink3, fontSize: 12),
                      ),
                    ),
                    AppButton('结束训练并保存',
                        icon: Icons.stop_rounded,
                        kind: AppBtnKind.danger,
                        onTap: _finishTap),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final name = _conn.device?.name ?? kAutoConnectName;
    return SizedBox(
      height: 50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            IconButton(
                icon: const Icon(Icons.chevron_left), onPressed: _finishTap),
            Expanded(child: Text(name, style: AppText.title)),
            _circle(Icons.favorite_border,
                color: _conn.hrConnected ? AppColors.red : AppColors.ink2,
                onTap: () => showHrConnectSheet(context)),
            const SizedBox(width: 8),
            _circle(Icons.bug_report_outlined,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const RawDebugScreen()))),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  Widget _circle(IconData icon, {Color? color, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
            color: AppColors.card,
            shape: BoxShape.circle,
            boxShadow: AppShadows.card),
        child: Icon(icon, size: 17, color: color ?? AppColors.ink2),
      ),
    );
  }

  Widget _statusStrip() {
    final disconnected = _conn.state == RowerConnState.disconnected;
    return Container(
      width: double.infinity,
      color: disconnected ? const Color(0xFFFDEBEC) : const Color(0xFFE9F8EF),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          Icon(disconnected ? Icons.bluetooth_disabled : Icons.bolt,
              size: 14,
              color: disconnected ? AppColors.red : AppColors.ok),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              disconnected
                  ? _conn.statusMessage
                  : '已连接 · ${widget.goal.mode.title}'
                      '${widget.goal.targetLabel != null ? " ${widget.goal.targetLabel}" : ""}',
              style: TextStyle(
                  color: disconnected ? AppColors.red : AppColors.ok,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const Text('📝 自动记录中',
              style: TextStyle(fontSize: 11, color: AppColors.ink3)),
        ],
      ),
    );
  }

  Widget _hero(RowingMetrics m, bool moving) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2F6BFF), Color(0xFF5B8CFF)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.cardLg),
        boxShadow: const [
          BoxShadow(
              color: Color(0x4D2F6BFF),
              blurRadius: 26,
              offset: Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('配速 · 每 500m',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(_fmtPace(m.split500),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 54,
                      fontWeight: FontWeight.w800,
                      height: 1.05)),
              const Text(' /500m',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('状态 · ${moving ? "运动中" : "静止"}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12.5)),
              Text('均功率 ${m.avgPowerW.round()} W',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hrBand() {
    if (!_conn.hrConnected) {
      return GestureDetector(
        onTap: () => showHrConnectSheet(context),
        child: Container(
          margin: const EdgeInsets.only(bottom: 13),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F7),
            borderRadius: BorderRadius.circular(AppRadius.tile),
          ),
          child: Row(
            children: const [
              Icon(Icons.favorite_border, color: AppColors.ink3),
              SizedBox(width: 12),
              Expanded(
                child: Text('连接心率设备(可选) — 点此扫描',
                    style: TextStyle(
                        color: AppColors.ink2,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.chevron_right, color: AppColors.ink3),
            ],
          ),
        ),
      );
    }
    final weak = _conn.hrSignalWeak;
    final bpm = _conn.hrBpm;
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: weak ? const Color(0xFFF1F3F7) : const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: weak ? const Color(0xFFE2E6EC) : const Color(0xFFFFE0E3),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.favorite,
                color: weak ? AppColors.ink3 : AppColors.red, size: 22),
          ),
          const SizedBox(width: 14),
          Text(weak ? '--' : '$bpm',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: weak ? AppColors.ink3 : AppColors.red)),
          const SizedBox(width: 4),
          Text('bpm',
              style: TextStyle(
                  fontSize: 13,
                  color: weak ? AppColors.ink3 : AppColors.red)),
          const Spacer(),
          Flexible(
            child: Text(
              weak
                  ? '⚠ 心率信号弱\n>5s 无数据,检查手表广播'
                  : '${appState.settings.hrDevice?.name ?? "心率设备"}\n实时心率',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 11.5,
                  height: 1.5,
                  color: weak ? AppColors.red : AppColors.ink2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(String label, String value, Color color, {String? unit}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: color)),
              if (unit != null)
                Text(' $unit',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color)),
            ],
          ),
          const SizedBox(height: 6),
          Text(label, style: AppText.label),
        ],
      ),
    );
  }

  Widget _splitsCard(RowingMetrics m) {
    final splits = _rec.splits;
    final curDist = m.distanceM - splits.length * 500;
    final bestIdx = _bestSplitIndex();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('分段 · 每 500m',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              Text(
                  widget.goal.targetLabel != null
                      ? '目标 ${widget.goal.targetLabel}'
                      : '第 ${splits.length + 1} 段',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.ink3)),
            ],
          ),
          const SizedBox(height: 8),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.4),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
            },
            children: [
              _splitHeader(),
              for (var i = 0; i < splits.length; i++)
                _splitRow(
                  '${i + 1} · 500m',
                  _fmtPace(splits[i].pace500),
                  splits[i].avgSpm.round().toString(),
                  splits[i].avgPower.round().toString(),
                  highlight: i == bestIdx
                      ? AppColors.ok
                      : null,
                ),
              if (curDist > 1)
                _splitRow(
                  '${splits.length + 1} · ${curDist.toStringAsFixed(0)}m ▸',
                  _fmtPace(m.split500),
                  m.spm == 0 ? '—' : m.spm.round().toString(),
                  m.powerW == 0 ? '—' : m.powerW.round().toString(),
                  highlight: AppColors.accent,
                ),
            ],
          ),
        ],
      ),
    );
  }

  int _bestSplitIndex() {
    final s = _rec.splits;
    if (s.isEmpty) return -1;
    var best = 0;
    for (var i = 1; i < s.length; i++) {
      if (s[i].pace500 < s[best].pace500) best = i;
    }
    return best;
  }

  TableRow _splitHeader() {
    TextStyle st = const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.ink3);
    return TableRow(
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line))),
      children: [
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Text('段', style: st)),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Text('配速', style: st, textAlign: TextAlign.right)),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Text('桨频', style: st, textAlign: TextAlign.right)),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Text('功率', style: st, textAlign: TextAlign.right)),
      ],
    );
  }

  TableRow _splitRow(String seg, String pace, String spm, String pow,
      {Color? highlight}) {
    final c = highlight ?? AppColors.ink;
    final segC = highlight ?? AppColors.ink2;
    return TableRow(
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line))),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(seg,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: segC)),
        ),
        _cell(pace, c),
        _cell(spm, c),
        _cell(pow, c),
      ],
    );
  }

  Widget _cell(String t, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(t,
            textAlign: TextAlign.right,
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: c)),
      );

  // ── 浮层小窗内容(Windows 失焦时替换整个 build) ─────────────────────────
  Widget _buildOverlay() {
    final m = _rec.metrics;
    final spm = m.spm == 0 ? '—' : m.spm.round().toString();
    final bpmStr = (_conn.hrConnected && !_conn.hrSignalWeak)
        ? (_conn.hrBpm?.toString() ?? '—')
        : '—';
    final el = _rec.elapsed;
    final timeStr =
        '${el.inMinutes}:${(el.inSeconds % 60).toString().padLeft(2, '0')}';

    return GestureDetector(
      // 点浮层 → 把窗口拉回前台并还原(还原本身也由失焦/获焦收敛兜底)。
      onTap: () {
        windowManager.focus();
        _requestOverlay(false);
      },
      child: Container(
        color: const Color(0xFF101828),
        child: Row(
          children: [
            _overlayMetric('⚡', spm, 'spm'),
            _overlayDivider(),
            _overlayMetric('♥', bpmStr, 'bpm'),
            _overlayDivider(),
            _overlayMetric('⏱', timeStr, '时间'),
          ],
        ),
      ),
    );
  }

  Widget _overlayMetric(String icon, String value, String unit) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 每列约 86px,长时长(100:00 三位分钟)会横向溢出 → scaleDown 自适应。
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('$icon $value',
                  maxLines: 1,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 2),
            Text(unit,
                style:
                    const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _overlayDivider() =>
      Container(width: 1, height: 38, color: Colors.white24);
}
