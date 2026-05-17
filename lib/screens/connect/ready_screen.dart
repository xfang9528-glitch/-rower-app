import 'dart:async';

import 'package:flutter/material.dart';

import '../../ble/rower_connection.dart';
import '../../models/training_goal.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../dashboard/dashboard_screen.dart';

/// ①c 连接成功 → 3-2-1 倒计时 → 进仪表盘。计时计数连接成功后从 0 起
/// (由 WorkoutRecorder 在进入仪表盘时开始)。
class ReadyScreen extends StatefulWidget {
  final TrainingGoal goal;
  const ReadyScreen({super.key, this.goal = const TrainingGoal.free()});

  @override
  State<ReadyScreen> createState() => _ReadyScreenState();
}

class _ReadyScreenState extends State<ReadyScreen> {
  int _n = 3;
  String _label = '3';
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 800), (_) {
      _n--;
      if (_n > 0) {
        setState(() => _label = '$_n');
      } else if (_n == 0) {
        setState(() => _label = 'GO');
      } else {
        _t?.cancel();
        _go();
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _go() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => DashboardScreen(goal: widget.goal)));
  }

  @override
  Widget build(BuildContext context) {
    final name = RowerConnection.instance.device?.name ?? kAutoConnectName;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: Color(0xFFE9F8EF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    size: 38, color: AppColors.ok),
              ),
              const SizedBox(height: 18),
              Text('已连接 $name',
                  style: const TextStyle(
                      fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              const Text('从 0 开始计时计数,准备好就划!',
                  style: TextStyle(color: AppColors.ink2, fontSize: 14)),
              const SizedBox(height: 6),
              Text(_label,
                  style: AppText.countdown
                      .copyWith(color: AppColors.accent)),
              const SizedBox(height: 18),
              AppLink('跳过', onTap: () {
                _t?.cancel();
                _go();
              }),
            ],
          ),
        ),
      ),
    );
  }
}
