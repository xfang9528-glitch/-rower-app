import 'package:flutter/foundation.dart';
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

  /// 多 worktree 并行调试时区分窗口:`flutter run --dart-define=ISSUE_TAG=#4`
  /// 注入。release 编译模式硬关(不论 dart-define 传没传,树摇消干净),
  /// 同时空字符串也不渲染——双保险,正式版绝无徽章。
  static const _issueTag = String.fromEnvironment('ISSUE_TAG');
  static const _badgeEnabled = !kReleaseMode && _issueTag != '';

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
        Widget body;
        if (w <= 460 || child == null) {
          body = child ?? const SizedBox();
        } else {
          body = ColoredBox(
            color: AppColors.pageOuter,
            child: Center(
              child: ClipRect(
                child: SizedBox(width: 440, child: child),
              ),
            ),
          );
        }
        if (!_badgeEnabled) return body;
        return Stack(
          children: [
            body,
            Positioned(top: 6, right: 8, child: _IssueTagBadge(_issueTag)),
          ],
        );
      },
      home: const _Bootstrap(),
    );
  }
}

/// 右上角的 ISSUE 徽章。点一下展开成卡片显示「该 issue 怎么测」步骤,
/// 多 worktree 并行调试时房总不用记现在测的是哪条线。
class _IssueTagBadge extends StatefulWidget {
  final String tag;
  const _IssueTagBadge(this.tag);

  @override
  State<_IssueTagBadge> createState() => _IssueTagBadgeState();
}

class _IssueTagBadgeState extends State<_IssueTagBadge> {
  bool _expanded = false;

  // 各 issue 的测试步骤;新增 issue 时在这里加一条即可,跟着 dart-define 走。
  static const Map<String, String> _steps = {
    '#4': '''记录详情页配速/心率曲线

1. 连接划船机,做一次训练(轻划/短划均可,≥30s/≥3 桨/≥20m 才存)
2. 训练结束 → 自动进「单次记录详情」(或在记录列表里点开)
3. 检查两张图:
   • 配速曲线 /500m:必出,应为连续青色折线 + 浅色渐变面积
   • 心率曲线 bpm:连了心率才出,样式同上(红色)
4. 不应是空白 / 一条灰色占位基线

历史数据有 paceSeries 也能验证,不一定要新训练。''',
  };

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => setState(() => _expanded = true),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.shade600,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              widget.tag,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }
    final steps = _steps[widget.tag] ?? '本 issue 暂无测试步骤说明。';
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(10),
      color: const Color(0xFFFFF7ED),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade600,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.tag,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '测试步骤',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9A6700),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _expanded = false),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close,
                          size: 16, color: Color(0xFF9A6700)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                steps,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Color(0xFF7A4F00),
                ),
              ),
            ],
          ),
        ),
      ),
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
