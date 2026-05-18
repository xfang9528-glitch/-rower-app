import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 轻量折线 + 渐变面积图(详情配速/心率曲线、趋势曲线复用)。
/// 0 视为缺失点,自动跳过;空数据画一条占位基线。
class LineChart extends StatelessWidget {
  final List<num> data;
  final Color color;
  final double height;
  const LineChart(
      {super.key, required this.data, required this.color, this.height = 110});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _LinePainter(data, color)),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<num> data;
  final Color color;
  _LinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final pts = <Offset>[];
    final valid = data.where((v) => v > 0).toList();
    if (valid.length < 2) {
      final p = Paint()
        ..color = AppColors.line
        ..strokeWidth = 2;
      canvas.drawLine(Offset(0, size.height * 0.6),
          Offset(size.width, size.height * 0.6), p);
      return;
    }
    final lo = valid.reduce((a, b) => a < b ? a : b).toDouble();
    final hi = valid.reduce((a, b) => a > b ? a : b).toDouble();
    final span = (hi - lo).abs() < 1e-6 ? 1.0 : (hi - lo);
    final n = data.length;
    for (var i = 0; i < n; i++) {
      final v = data[i];
      if (v <= 0) continue;
      final x = n == 1 ? 0.0 : i / (n - 1) * size.width;
      final y = size.height - ((v - lo) / span) * (size.height * 0.86) -
          size.height * 0.07;
      pts.add(Offset(x, y));
    }
    if (pts.length < 2) return;

    final line = Paint()
      ..color = color
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final fill = Path.from(path)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.data != data || old.color != color;
}

/// 列表卡片右侧的迷你火花线(无面积、无坐标)。
class Sparkline extends StatelessWidget {
  final List<num> data;
  final Color color;
  const Sparkline({super.key, required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 34,
      child: CustomPaint(painter: _SparkPainter(data, color)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<num> data;
  final Color color;
  _SparkPainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final valid = data.where((v) => v > 0).toList();
    if (valid.length < 2) return;
    final lo = valid.reduce((a, b) => a < b ? a : b).toDouble();
    final hi = valid.reduce((a, b) => a > b ? a : b).toDouble();
    final span = (hi - lo).abs() < 1e-6 ? 1.0 : (hi - lo);
    final pts = <Offset>[];
    final n = data.length;
    for (var i = 0; i < n; i++) {
      final v = data[i];
      if (v <= 0) continue;
      final x = i / (n - 1) * size.width;
      final y = size.height - ((v - lo) / span) * size.height;
      pts.add(Offset(x, y));
    }
    if (pts.length < 2) return;
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.data != data;
}
