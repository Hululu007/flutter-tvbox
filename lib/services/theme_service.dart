import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../common/theme.dart';

/// 主题模式：跟随系统 / 浅色 / 深色
///
/// 为什么不用 `Theme.of(context)` 来判断深浅：
///   项目里有 200 多处直接引用 `AppTheme.textPrimary` 这类静态色，
///   它们拿不到 context。所以走"全局开关"路线——[AppTheme.setDark]
///   由这里统一写入，UI 重建时读到新值。
class ThemeService extends GetxController {
  static ThemeService get instance => Get.find<ThemeService>();

  static const String _prefKey = 'theme_mode_v1';

  /// 用户选择（system / light / dark）
  final Rx<ThemeMode> mode = ThemeMode.system.obs;

  /// 当前实际是否深色。system 模式下随系统变。
  final RxBool isDark = true.obs;

  @override
  void onInit() {
    super.onInit();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      mode.value = _parse(p.getString(_prefKey));
    } catch (_) {
      mode.value = ThemeMode.system;
    }
    _apply(systemBrightness: _platformBrightness());
  }

  Future<void> setMode(ThemeMode m) async {
    mode.value = m;
    _apply(systemBrightness: _platformBrightness());
    // 让 GetMaterialApp 重建（AppTheme 是静态色，重建后才会读到新值）
    if (Get.context != null) {
      Get.changeThemeMode(m);
    }
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefKey, m.name);
    } catch (_) {}
  }

  /// 系统深浅色变化时调用（由 App 的 WidgetsBindingObserver 转发）
  void onSystemBrightnessChanged(Brightness b) {
    if (mode.value != ThemeMode.system) return;
    _apply(systemBrightness: b);
  }

  /// 把选择折算成实际深浅，写进 AppTheme 并通知 UI 重建
  void _apply({required Brightness systemBrightness}) {
    final dark = switch (mode.value) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => systemBrightness == Brightness.dark,
    };
    final changed = isDark.value != dark || AppTheme.isDark != dark;
    isDark.value = dark;
    AppTheme.setDark(dark);
    if (changed) {
      // 数值没变但 AppTheme 变了（冷启动首帧）也要刷一次
      refresh();
    }
  }

  Brightness _platformBrightness() {
    final d = WidgetsBinding.instance.platformDispatcher;
    return d.platformBrightness;
  }

  ThemeMode _parse(String? s) => switch (s) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  /// 给设置页用的显示名
  static String labelOf(ThemeMode m) => switch (m) {
        ThemeMode.system => '跟随系统',
        ThemeMode.light => '浅色',
        ThemeMode.dark => '深色',
      };
}
