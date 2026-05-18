import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../app_state.dart';
import '../../ble/rower_connection.dart';
import '../../models/training_goal.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import 'bt_off_screen.dart';
import 'conn_fail_screen.dart';
import 'ready_screen.dart';

/// ①b 自动连接中:零点击,文案随真实事件流转;仅「取消」可中断。
/// 手动选设备时传入 [manualDevice],跳过扫描直连它。[goal] 随流程串到仪表盘。
class ConnectingScreen extends StatefulWidget {
  final BleDevice? manualDevice;
  final TrainingGoal goal;
  const ConnectingScreen({
    super.key,
    this.manualDevice,
    this.goal = const TrainingGoal.free(),
  });

  @override
  State<ConnectingScreen> createState() => _ConnectingScreenState();
}

class _ConnectingScreenState extends State<ConnectingScreen> {
  final _conn = RowerConnection.instance;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _conn.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.manualDevice != null) {
        _conn.connectTo(widget.manualDevice!);
      } else {
        _conn.startAuto(rememberedId: appState.settings.rower?.id);
      }
    });
  }

  @override
  void dispose() {
    _conn.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (_navigated || !mounted) return;
    switch (_conn.state) {
      case RowerConnState.btOff:
        _navigated = true;
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => const BtOffScreen()));
        break;
      case RowerConnState.connected:
        _navigated = true;
        appState.settings.rememberRower(
            _conn.device!.deviceId,
            _conn.device!.name ?? _conn.device!.rawName ?? kAutoConnectName);
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => ReadyScreen(goal: widget.goal)));
        break;
      case RowerConnState.failed:
        _navigated = true;
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => const ConnFailScreen()));
        break;
      default:
        setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const PulseRings(
                core: Icon(Icons.rowing, size: 46, color: Colors.white),
              ),
              const SizedBox(height: 34),
              const Text('正在连接划船机',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              SizedBox(
                height: 21,
                child: Text(
                  _conn.statusMessage.isEmpty ? '正在扫描划船机…' : _conn.statusMessage,
                  style: const TextStyle(
                      color: AppColors.ink2, fontSize: 14),
                ),
              ),
              const SizedBox(height: 26),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  '🤚 拉一下划船机手柄唤醒它\n开机后自动连接,中途无需任何点击',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Color(0xFFC2630A),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.7),
                ),
              ),
              const SizedBox(height: 30),
              AppLink('取消', onTap: () {
                _conn.cancel();
                Navigator.of(context).pop();
              }),
            ],
          ),
        ),
      ),
    );
  }
}
