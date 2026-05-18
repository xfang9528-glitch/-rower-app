import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'connect/connect_screen.dart';
import 'history/history_screen.dart';
import 'profile/profile_screen.dart';

/// 底部 Tab 骨架(训练 / 记录 / 我的)。专注流程(连接中/倒计时/连接
/// 失败)以全屏路由 push 在 Shell 之上,自带无 Tab —— 见后续迭代。
///
/// 迭代 0 先放占位 body,迭代 1/4/5 依次替换为真实屏。
class AppShell extends StatefulWidget {
  final int initialTab;
  const AppShell({super.key, this.initialTab = 0});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: [
            ConnectScreen(onOpenProfile: () => setState(() => _tab = 2)),
            HistoryScreen(onStartTraining: () => setState(() => _tab = 0)),
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: AppTabBar(
        current: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

/// 底部 Tab 栏 —— 终版设计(design-spec §5):高 64,白底,顶部 1px 描边,
/// 当前项主色,其余 ink-3。
class AppTabBar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const AppTabBar({super.key, required this.current, required this.onTap});

  static const _items = [
    (Icons.rowing, '训练'),
    (Icons.view_list_rounded, '记录'),
    (Icons.person_outline_rounded, '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 64 + bottomInset,
      padding: EdgeInsets.only(bottom: 6 + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_items[i].$1,
                        size: 23,
                        color: i == current
                            ? AppColors.accent
                            : AppColors.ink3),
                    const SizedBox(height: 3),
                    Text(_items[i].$2,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: i == current
                                ? AppColors.accent
                                : AppColors.ink3)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

