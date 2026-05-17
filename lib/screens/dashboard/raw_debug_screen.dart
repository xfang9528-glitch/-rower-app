import 'dart:async';

import 'package:flutter/material.dart';

import '../../ble/known_uuids.dart';
import '../../ble/rower_connection.dart';
import '../../ble/session_log.dart';
import '../../theme/app_theme.dart';

/// ③b 原始调试视图:GATT 服务树 + 实时 13 字节帧日志(手机单栏可滚)。
class RawDebugScreen extends StatefulWidget {
  const RawDebugScreen({super.key});

  @override
  State<RawDebugScreen> createState() => _RawDebugScreenState();
}

class _RawDebugScreenState extends State<RawDebugScreen> {
  final _conn = RowerConnection.instance;
  final List<RawFrame> _log = [];
  StreamSubscription<RawFrame>? _sub;
  final _scroll = ScrollController();
  static const _max = 400;

  @override
  void initState() {
    super.initState();
    _sub = _conn.rawFrames.listen((f) {
      setState(() {
        _log.add(f);
        if (_log.length > _max) _log.removeRange(0, _log.length - _max);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  static String _hex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join(' ');
  static String _ts(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}.'
      '${t.millisecond.toString().padLeft(3, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('原始调试视图', style: AppText.title),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.card),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GATT · ${_conn.services.length} 个服务',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  for (final s in _conn.services) ...[
                    Text(
                      '${shortUuid(s.uuid)}'
                      '${describeUuid(s.uuid) != null ? "  ·  ${describeUuid(s.uuid)}" : ""}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent),
                    ),
                    for (final c in s.characteristics)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 2),
                        child: Text(
                          '${shortUuid(c.uuid)} '
                          '[${c.properties.map((p) => p.name).join(",")}]',
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.ink2),
                        ),
                      ),
                    const SizedBox(height: 6),
                  ],
                  if (SessionLog.started)
                    Text('📝 ${SessionLog.path}',
                        style: const TextStyle(
                            fontSize: 10.5, color: AppColors.ink3)),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 9),
              child: Text('数据日志 · 自动滚动',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink3)),
            ),
            Container(
              height: 360,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1726),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListView.builder(
                controller: _scroll,
                itemCount: _log.length,
                itemBuilder: (_, i) {
                  final e = _log[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_ts(e.t)}  ${shortUuid(e.charUuid)}  '
                          'd=${e.deltaMs ?? "-"}ms len=${e.value.length}',
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontFamily: 'monospace',
                              color: Color(0xFF5FB8FF)),
                        ),
                        Text(_hex(e.value),
                            style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: Color(0xFF7CF3C0))),
                        if (e.parsed != null)
                          Text('⇒ ${e.parsed}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: Color(0xFFFFCB6B))),
                      ],
                    ),
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
