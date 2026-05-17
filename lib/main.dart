import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'screens/app_shell.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // design-spec §1:App 全屏铺满,边到边。
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const RowerApp());
}

class RowerApp extends StatelessWidget {
  const RowerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '小莫划船机',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // design-spec §1/§8:手机基准逻辑宽 412,全屏铺满;桌面/平板等宽屏
      // 时限宽居中(≈ 原型 width:min(440,100vw)),两侧留 pageOuter。
      builder: (context, child) {
        final w = MediaQuery.of(context).size.width;
        if (w <= 460 || child == null) return child ?? const SizedBox();
        return ColoredBox(
          color: AppColors.pageOuter,
          child: Center(
            child: ClipRect(
              child: SizedBox(width: 440, child: child),
            ),
          ),
        );
      },
      home: const _Bootstrap(),
    );
  }
}

/// 启动即载入本地数据(用户/设置/记录),就绪后进 AppShell。
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late final Future<void> _init = appState.init();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _init,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.bg,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const AppShell();
      },
    );
  }
}
