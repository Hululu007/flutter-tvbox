import 'package:flutter/material.dart';

/// 主题配置 —— 纯黑底 + 蓝紫强调
///
/// 配色策略：
///   - 背景一律走纯黑 #000，靠 BackgroundService 的渐变层叠出层次，
///     不靠"更亮的灰"来分块，否则在 OLED 上整片发灰、观感发闷。
///   - 强调色只有一组：蓝 #3E63FF → 紫 #8A5CFF，能渐变的地方都走渐变，
///     选中态/进度/下划线/徽章统一色相，避免多色打架。
///   - 文字只用三档灰度，第四档开始就显得脏。
class AppTheme {
  // ===== 强调色 =====
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

  // ===== 背景（纯黑系）=====
  static const Color backgroundPrimary = Color(0xFF000000);
  static const Color backgroundSecondary = Color(0xFF0D0D0F);
  static const Color backgroundTertiary = Color(0x0FFFFFFF); // white 6%
  static const Color backgroundElevated = Color(0x14FFFFFF); // white 8%

  // ===== 半透明卡片色 =====
  // 让 BackgroundService 的全局背景层透出来，否则每张卡片都是一块死黑。
  // 0xCC = 204/255 ≈ 80%，0xE6 = 230/255 ≈ 90%
  static const Color backgroundCard = Color(0xCC111114);
  static const Color backgroundCardElevated = Color(0xE6111114);
  static const Color backgroundNavBar = Color(0xCC121214);

  // ===== 文字 =====
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0A0A8);
  static const Color textTertiary = Color(0xFF6A6A72);

  // ===== 描边 =====
  static const Color borderLight = Color(0x14FFFFFF); // white 8%
  static const Color borderMedium = Color(0x24FFFFFF); // white 14%

  // ===== 语义色 =====
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

  /// 海报宽高比。电影/剧集海报标准约 2:3，这里取 1.47（宽 = 高 / 1.47），
  /// 跟主流影视 App 的视觉密度一致，比 2:3 少留白。
  static const double posterRatio = 1.47;

  // ===== 字号 =====
  static const double fontCaption = 11;
  static const double fontFootnote = 12.5;
  static const double fontSubhead = 13;
  static const double fontBody = 14;
  static const double fontHeadline = 16;
  static const double fontTitle3 = 18;
  static const double fontTitle2 = 20;

  /// 暗色主题
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundPrimary,
      colorScheme: const ColorScheme.dark(
        primary: accentColor,
        secondary: accentLightColor,
        surface: backgroundSecondary,
        error: errorColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: fontHeadline,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: textSecondary),
      ),
      cardTheme: CardThemeData(
        color: backgroundCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: backgroundTertiary,
        selectedColor: accentColor.withValues(alpha: 0.18),
        labelStyle: const TextStyle(color: textSecondary, fontSize: fontSubhead),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: accentColor,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 10),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusXL),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: textTertiary, fontSize: fontSubhead),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingLG,
          vertical: spacingMD,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accentColor,
        linearTrackColor: Color(0x1FFFFFFF),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: accentColor,
        inactiveTrackColor: Color(0x33FFFFFF),
        thumbColor: Colors.white,
        overlayColor: Color(0x333E63FF),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            color: textPrimary, fontSize: 28, fontWeight: FontWeight.w800),
        headlineMedium: TextStyle(
            color: textPrimary,
            fontSize: fontTitle2,
            fontWeight: FontWeight.w700),
        headlineSmall: TextStyle(
            color: textPrimary,
            fontSize: fontTitle3,
            fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: textPrimary, fontSize: fontBody),
        bodyMedium: TextStyle(color: textSecondary, fontSize: fontSubhead),
        bodySmall: TextStyle(color: textTertiary, fontSize: fontFootnote),
        labelLarge: TextStyle(
            color: textPrimary, fontSize: fontBody, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: textSecondary, fontSize: fontSubhead),
        labelSmall: TextStyle(color: textTertiary, fontSize: fontCaption),
      ),
      useMaterial3: true,
    );
  }
}
