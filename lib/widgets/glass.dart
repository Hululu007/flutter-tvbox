import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../common/theme.dart';

/// 毛玻璃容器
///
/// 几个必须注意的点：
///   1. `BackdropFilter` **必须** 被 `ClipRRect` 包住，否则模糊区域会溢出到
///      父级整块画布，表现为"整个屏幕糊了"。
///   2. 玻璃要透出后面的东西才有质感，所以底色只能用低透明度；
///      真正撑起对比的是那圈 0.8px 的高光描边。
///   3. 浅色模式下白底叠白玻璃会糊成一片，底色要提到 55-65% 白，
///      描边改成纯白才立得住。
class Glass extends StatelessWidget {
  final Widget child;
  final double blur;
  final double radius;

  /// 自定义底色（不传则按深浅色走默认）
  final Color? tint;

  /// 描边透明度系数
  final double borderAlpha;

  /// 是否显示描边
  final bool border;

  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const Glass({
    super.key,
    required this.child,
    this.blur = 18,
    this.radius = 16,
    this.tint,
    this.borderAlpha = 1.0,
    this.border = true,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    final base = tint ??
        (dark
            ? Colors.white.withValues(alpha: 0.075)
            : Colors.white.withValues(alpha: 0.62));
    final line = (dark
            ? Colors.white.withValues(alpha: 0.13)
            : Colors.white.withValues(alpha: 0.85))
        .withValues(alpha: (dark ? 0.13 : 0.85) * borderAlpha);

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(radius),
              border: border
                  ? Border.all(color: line, width: 0.8)
                  : null,
              // 极淡的顶部高光，模拟玻璃边缘的反光
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: dark ? 0.05 : 0.25),
                  Colors.transparent,
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 带品牌色调的毛玻璃按钮 —— 主 CTA 用
///
/// 纯透明玻璃做不出"可点"的暗示，所以这里在玻璃层下面垫一层蓝紫渐变，
/// 透明度压到 55-70%，既保留玻璃透光感，又有明确的视觉重心。
class GlassAccentButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double height;
  final double radius;

  const GlassAccentButton({
    super.key,
    required this.child,
    this.onTap,
    this.height = 46,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 底部品牌渐变
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xCC3E63FF), Color(0xCC8A5CFF)],
                  ),
                ),
              ),
              // 上面压一层玻璃：模糊掉后面的内容，同时给一层高光
              BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                      width: 0.8,
                    ),
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
              ),
              Center(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
