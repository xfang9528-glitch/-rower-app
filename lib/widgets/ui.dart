import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppBtnKind { primary, ghost, danger, disabled }

/// 主按钮 —— design-spec §5。primary 主色实底白字;ghost 白底主色;
/// danger 白底红字;disabled 灰底不可点。`lg` 放大档。
class AppButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final AppBtnKind kind;
  final bool lg;
  const AppButton(
    this.label, {
    super.key,
    this.icon,
    this.onTap,
    this.kind = AppBtnKind.primary,
    this.lg = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = kind == AppBtnKind.disabled || onTap == null;
    Color bg, fg;
    List<BoxShadow> shadow;
    switch (kind) {
      case AppBtnKind.primary:
        bg = AppColors.accent;
        fg = Colors.white;
        shadow = AppShadows.button;
        break;
      case AppBtnKind.ghost:
        bg = AppColors.card;
        fg = AppColors.accent;
        shadow = AppShadows.card;
        break;
      case AppBtnKind.danger:
        bg = AppColors.card;
        fg = AppColors.red;
        shadow = AppShadows.card;
        break;
      case AppBtnKind.disabled:
        bg = const Color(0xFFC7D0DE);
        fg = Colors.white;
        shadow = const [];
        break;
    }
    if (disabled && kind != AppBtnKind.disabled) {
      shadow = const [];
      bg = const Color(0xFFC7D0DE);
      fg = Colors.white;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(
            lg ? AppRadius.buttonLg : AppRadius.button),
        splashColor: Colors.transparent,
        highlightColor: Colors.black.withValues(alpha: 0.04),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(
                lg ? AppRadius.buttonLg : AppRadius.button),
            boxShadow: shadow,
          ),
          padding: EdgeInsets.symmetric(vertical: lg ? 19 : 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: lg ? 22 : 19, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: fg,
                        fontSize: lg ? 18 : 16,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 文字链接(居中,主色 13/600)。
class AppLink extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final Color? color;
  const AppLink(this.text, {super.key, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: color ?? AppColors.accent,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// 通用白卡。
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.screen),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: AppSpacing.card),
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}

/// 顶部全宽警示 banner(蓝牙未开启等)。
class AppBanner extends StatelessWidget {
  final String text;
  const AppBanner(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.bannerBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: AppColors.bannerInk),
          const SizedBox(width: 8),
          Flexible(
            child: Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.bannerInk,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// 蓝色圆角划船机徽标(连接相关页)。
class RowerBadge extends StatelessWidget {
  final double size;
  final bool muted;
  const RowerBadge({super.key, this.size = 118, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: muted
              ? const [Color(0xFFAEB7C7), Color(0xFF9AA4B6)]
              : const [Color(0xFF3D7BFF), Color(0xFF2F6BFF)],
        ),
        borderRadius: BorderRadius.circular(size * 0.29),
        boxShadow: muted
            ? null
            : const [
                BoxShadow(
                    color: Color(0x572F6BFF),
                    blurRadius: 30,
                    offset: Offset(0, 16)),
              ],
      ),
      child: Icon(Icons.rowing, size: size * 0.52, color: Colors.white),
    );
  }
}

/// 自动连接中的脉冲光环(prototype `.pulse` / @keyframes pl)。
class PulseRings extends StatefulWidget {
  final Widget core;
  const PulseRings({super.key, required this.core});

  @override
  State<PulseRings> createState() => _PulseRingsState();
}

class _PulseRingsState extends State<PulseRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2100))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      height: 170,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          Widget ring(double phase) {
            final v = (_c.value + phase) % 1.0;
            final scale = 0.55 + v * 0.95; // .55 → 1.5
            final opacity = (0.85 * (1 - v)).clamp(0.0, 0.85);
            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x292F6BFF),
                  ),
                ),
              ),
            );
          }

          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(child: ring(0)),
              Positioned.fill(child: ring(0.5)),
              Container(
                width: 104,
                height: 104,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3D7BFF), Color(0xFF2F6BFF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Color(0x6B2F6BFF),
                        blurRadius: 28,
                        offset: Offset(0, 14)),
                  ],
                ),
                child: widget.core,
              ),
            ],
          );
        },
      ),
    );
  }
}
