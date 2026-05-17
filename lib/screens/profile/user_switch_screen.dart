import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../models/user_profile.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';

/// ⑦ 切换 / 添加用户:每人独立训练记录(本地多用户,无账号)。
class UserSwitchScreen extends StatefulWidget {
  const UserSwitchScreen({super.key});

  @override
  State<UserSwitchScreen> createState() => _UserSwitchScreenState();
}

class _UserSwitchScreenState extends State<UserSwitchScreen> {
  Map<String, ({int count, double distM})> _summ = {};

  @override
  void initState() {
    super.initState();
    _loadSummaries();
  }

  Future<void> _loadSummaries() async {
    final m = <String, ({int count, double distM})>{};
    for (final u in appState.users.users) {
      m[u.id] = await appState.workouts.summaryFor(u.id);
    }
    if (mounted) setState(() => _summ = m);
  }

  @override
  Widget build(BuildContext context) {
    final users = appState.users.users;
    final currentId = appState.users.currentId;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('切换用户', style: AppText.title),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
              child: Text('每个用户独立的训练记录与档案,数据保存在本机。',
                  style: TextStyle(
                      fontSize: 12.5, color: AppColors.ink2)),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.card),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < users.length; i++)
                    _userRow(users[i], users[i].id == currentId,
                        last: i == users.length - 1),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppButton('添加新用户',
                icon: Icons.add,
                kind: AppBtnKind.ghost,
                onTap: _addUser),
          ],
        ),
      ),
    );
  }

  Widget _userRow(UserProfile u, bool current, {bool last = false}) {
    final s = _summ[u.id];
    final sub = s == null
        ? '…'
        : '${s.count} 次 · ${(s.distM / 1000).toStringAsFixed(0)} km'
            '${current ? " · 当前使用" : ""}';
    return InkWell(
      onTap: current
          ? null
          : () async {
              await appState.switchUser(u.id);
              if (mounted) Navigator.of(context).pop();
            },
      child: Container(
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppColors.line)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(u.avatarColorA), Color(u.avatarColorB)],
                ),
              ),
              child: Text(u.initial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.ink2)),
                ],
              ),
            ),
            if (current)
              const Icon(Icons.check, color: AppColors.accent)
            else
              const Icon(Icons.chevron_right, color: AppColors.ink3),
          ],
        ),
      ),
    );
  }

  Future<void> _addUser() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加新用户'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '名字,如 夫人 / 小朋友'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('添加')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await appState.addUser(name);
    if (!mounted) return;
    Navigator.of(context).pop(); // 新用户即当前用户,回上一页
  }
}
