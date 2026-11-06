import 'package:flutter/material.dart';

/// 主题配置 —— 纯黑/纯白双底 + 蓝紫强调
///
/// **浅色/深色切换的实现方式**：
///   颜色不再是 `static const`，而是 `static get`，读 [_dark] 开关。
///   这样 200 多个 `AppTheme.textPrimary` 引用点一行都不用改，
///   只要 ThemeService 切换时调 [AppTheme.setDark] 再触发一次重建即可。
///
///   代价：`const TextStyle(color: AppTheme.textPrimary)` 这种写法不再合法
///   （常量表达式不能读 getter），全项目只有 9 处，已改掉。
///
/// 强调色（蓝紫渐变）深浅两套共用 —— 换色相会让品牌感断掉，
/// 浅色模式只需要把底和字反过来。
class AppTheme {
  /// 当前是否深色。由 ThemeService 在启动和切换时写入。
  static bool _dark = true;

  static bool get isDark => _dark;

  static void setDark(bool value) {
    _dark = value;
  }

  // ===== 强调色（两套通用）=====
  static const Color accentColor = Color(0xFF3E63FF); // 主蓝
  static const Color accentLightColor = Color(0xFF8A5CFF); // 尾紫
  static const Color accentPurple = Color(0xFF8A5CFF);

  /// 强调渐变：选中态、进度条、徽章、下划线统一用这个
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [accentColor, accentLightColor],
  );

  /// 斜向渐变，用于按钮/强调底
  static const LinearGradient accentGradientV = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentColor, accentLightColor],
  );

  // ===== 背景 =====
  static Color get backgroundPrimary =>
      _dark ? const Color(0xFF000000) : const Color(0xFFF4F5F7);

  static Color get backgroundSecondary =>
      _dark ? const Color(0xFF0D0D0F) : const Color(0xFFFFFFFF);

  /// 深色是白 6%，浅色是黑 4%
  static Color get backgroundTertiary =>
      _dark ? const Color(0x0FFFFFFF) : const Color(0x0A000000);

  /// 深色是白 8%，浅色是黑 6%
  static Color get backgroundElevated =>
      _dark ? const Color(0x14FFFFFF) : const Color(0x0F000000);

  // ===== 卡面（半透明，让背景层透出）=====
  static Color get backgroundCard =>
      _dark ? const Color(0xCC111114) : const Color(0xE6FFFFFF);

  static Color get backgroundCardElevated =>
      _dark ? const Color(0xE6111114) : const Color(0xF2FFFFFF);

  static Color get backgroundNavBar =>
      _dark ? const Color(0xCC121214) : const Color(0xE6FFFFFF);

  // ===== 文字 =====
  static Color get textPrimary =>
      _dark ? const Color(0xFFFFFFFF) : const Color(0xFF111114);

  static Color get textSecondary =>
      _dark ? const Color(0xFFA0A0A8) : const Color(0xFF5C5C66);

  static Color get textTertiary =>
      _dark ? const Color(0xFF6A6A72) : const Color(0xFF9A9AA3);

  // ===== 描边 =====
  static Color get borderLight =>
      _dark ? const Color(0x14FFFFFF) : const Color(0x14000000);

  static Color get borderMedium =>
      _dark ? const Color(0x24FFFFFF) : const Color(0x24000000);

  // ===== 语义色（两套通用，浅色下略压暗保证对比度）=====
  static const Color successColor = Color(0xFF38C172);
  static const Color warningColor = Color(0xFFF2A93B);
  static const Color errorColor = Color(0xFFF05252);
  static const Color goldColor = Color(0xFFF5C451);

  // ===== 间距 =====
  static const double spacingXS = 4;
  static const double spacingSM = 8;
  static const double spacingMD = 12;
  static const double spacingLG = 16;
  static const double spacingXL = 20;
  static const double spacingXXL = 24;

  // ===== 圆角 =====
  static const double radiusSM = 8;
  static const double radiusMD = 10;
  static const double radiusLG = 14;
  static const double radiusXL = 20;

  // ===== 卡片 =====
  static const double cardRadius = 8;
  static const double cardSpacing = 8;
  static const double cardPadding = 0;

  /// 海报宽高比（宽 = 高 / 1.47）
  static const double posterRatio = 1.47;

  // ===== 字号 =====
  static const double fontCaption = 11;
  static const double fontFootnote = 12.5;
  static const double fontSubhead = 13;
  static const double fontBody = 14;
  static const double fontHeadline = 16;
  static const double fontTitle3 = 18;
  static const double fontTitle2 = 20;

  /// 深色主题
  static ThemeData get darkTheme => _build(dark: true);

  /// 浅色主题
  static ThemeData get lightTheme => _build(dark: false);

  static ThemeData _build({required bool dark}) {
    final bg = dark ? const Color(0xFF000000) : const Color(0xFFF4F5F7);
    final surface = dark ? const Color(0xFF0D0D0F) : const Color(0xFFFFFFFF);
    final card = dark ? const Color(0xCC111114) : const Color(0xE6FFFFFF);
    final t1 = dark ? const Color(0xFFFFFFFF) : const Color(0xFF111114);
    final t2 = dark ? const Color(0xFFA0A0A8) : const Color(0xFF5C5C66);
    final t3 = dark ? const Color(0xFF6A6A72) : const Color(0xFF9A9AA3);

    return ThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: dark ? Brightness.dark : Brightness.light,
        primary: accentColor,
        onPrimary: Colors.white,
        secondary: accentLightColor,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: t1,
        error: errorColor,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: t1,
          fontSize: fontHeadline,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: t2),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: dark ? const Color(0x0FFFFFFF) : const Color(0x0A000000),
        selectedColor: accentColor.withValues(alpha: 0.18),
        labelStyle: TextStyle(color: t2, fontSize: fontSubhead),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: accentColor,
        unselectedItemColor: t3,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle:
            const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusXL),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: t3, fontSize: fontSubhead),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingLG,
          vertical: spacingMD,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accentColor,
        linearTrackColor: dark ? const Color(0x1FFFFFFF) : const Color(0x1F000000),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accentColor,
        inactiveTrackColor: dark ? const Color(0x33FFFFFF) : const Color(0x33000000),
        thumbColor: Colors.white,
        overlayColor: const Color(0x333E63FF),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
            color: t1, fontSize: 28, fontWeight: FontWeight.w800),
        headlineMedium:
            TextStyle(color: t1, fontSize: fontTitle2, fontWeight: FontWeight.w700),
        headlineSmall:
            TextStyle(color: t1, fontSize: fontTitle3, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: t1, fontSize: fontBody),
        bodyMedium: TextStyle(color: t2, fontSize: fontSubhead),
        bodySmall: TextStyle(color: t3, fontSize: fontFootnote),
        labelLarge:
            TextStyle(color: t1, fontSize: fontBody, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: t2, fontSize: fontSubhead),
        labelSmall: TextStyle(color: t3, fontSize: fontCaption),
      ),
      useMaterial3: true,
    );
  }
}
