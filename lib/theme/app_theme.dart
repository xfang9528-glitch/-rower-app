import 'package:flutter/material.dart';

/// 设计 token —— 严格对应 `docs/design-spec.md` 与 `prototype/index.html`
/// 的 CSS 变量。Flutter 还原以这里为单一事实源,改配色/间距只动这一处。
class AppColors {
  static const accent = Color(0xFF2F6BFF);
  static const accentSoft = Color(0xFFEAF1FF);
  static const bg = Color(0xFFF4F6FA);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF13223F);
  static const ink2 = Color(0xFF6B7689);
  static const ink3 = Color(0xFF9AA4B6);
  static const line = Color(0xFFECEFF4);

  static const ok = Color(0xFF16A34A);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);
  static const rose = Color(0xFFF43F5E);
  static const cyan = Color(0xFF06B6D4);
  static const amber = Color(0xFFF59E0B);
  static const orange = Color(0xFFF97316);

  // 警示 banner
  static const bannerBg = Color(0xFFFDECC8);
  static const bannerInk = Color(0xFF9A6700);
  // 视口两侧留白(窄于设计宽时)
  static const pageOuter = Color(0xFFDCE2EA);

  /// 指标固定配色(全 App 一致):配速=青、桨频=琥珀、功率=橙、
  /// 距离=绿、桨数/时间=主文字、心率=红、卡路里=玫红。
  static const pace = cyan;
  static const spm = amber;
  static const power = orange;
  static const distance = green;
  static const calories = rose;
  static const heart = red;
}

class AppSpacing {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 11.0;
  static const card = 13.0; // 卡片间距
  static const screen = 16.0; // 屏边距
  static const l = 20.0;
}

class AppRadius {
  static const card = 18.0;
  static const cardLg = 20.0;
  static const button = 15.0;
  static const buttonLg = 18.0;
  static const tile = 16.0;
  static const chip = 12.0;
  static const pill = 999.0;
}

class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x12142040), blurRadius: 22, offset: Offset(0, 6)),
  ];
  static const button = [
    BoxShadow(color: Color(0x472F6BFF), blurRadius: 18, offset: Offset(0, 8)),
  ];
}

/// 字号阶梯(design-spec §3)。
class AppText {
  static const hero = TextStyle(
      fontSize: 54, fontWeight: FontWeight.w800, height: 1.05, letterSpacing: -1);
  static const tileVal = TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1);
  static const detailDist =
      TextStyle(fontSize: 46, fontWeight: FontWeight.w800, letterSpacing: -1);
  static const countdown = TextStyle(
      fontSize: 128, fontWeight: FontWeight.w800, height: 1, letterSpacing: -4);
  static const title = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
  static const titleLg = TextStyle(fontSize: 21, fontWeight: FontWeight.w800);
  static const body = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
  static const label = TextStyle(
      fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink2);
  static const weak = TextStyle(
      fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.ink3);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.accent,
      surface: AppColors.card,
      error: AppColors.red,
    ),
    fontFamily: 'PingFang SC',
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    splashColor: Colors.transparent,
    highlightColor: const Color(0x11142040),
  );
}
