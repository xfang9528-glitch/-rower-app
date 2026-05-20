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
    // CustomPaint 套 sized child:painter 跟随子尺寸,无需 size:。
    return CustomPaint(
      painter: _LinePainter(data, color),
      child: SizedBox(width: double.infinity, height: height),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<num> data;
  final Color color;
  _LinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // #4 真根因:caller 传的 data 运行时常是 List<int>(Workout.paceSeries
    // 字段类型),`List<int>.reduce` 期待 (int, int) => int combine,而
    // 下面 lambda 在静态 List<num> 上下文被推断成 (num, num) => num,
    // 返回类型不是 int 子类型,运行时 throw,被 Flutter 渲染层吞掉 →
    // painter 啥都没画 → 卡片空白。先 .toDouble() 锁定 List<double>,稳。
    final valid =
        data.where((v) => v > 0).map((v) => v.toDouble()).toList();
    if (valid.length < 2) {
      final p = Paint()
        ..color = AppColors.line
        ..strokeWidth = 2;
      canvas.drawLine(Offset(0, size.height * 0.6),
          Offset(size.width, size.height * 0.6), p);
      return;
    }
    final lo = valid.reduce((a, b) => a < b ? a : b);
    final hi = valid.reduce((a, b) => a > b ? a : b);
    final span = (hi - lo).abs() < 1e-6 ? 1.0 : (hi - lo);
    final n = data.length;
    final pts = <Offset>[];
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
    return CustomPaint(
      painter: _SparkPainter(data, color),
      child: const SizedBox(width: 64, height: 34),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<num> data;
  final Color color;
  _SparkPainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // 同 _LinePainter:toDouble 锁定 List<double>,避免 List<int>.reduce
    // 的 combine 类型在运行时不匹配抛异常(#4 同源 bug)。
    final valid =
        data.where((v) => v > 0).map((v) => v.toDouble()).toList();
    if (valid.length < 2) return;
    final lo = valid.reduce((a, b) => a < b ? a : b);
    final hi = valid.reduce((a, b) => a > b ? a : b);
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
