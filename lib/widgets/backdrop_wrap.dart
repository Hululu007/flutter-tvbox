import 'package:flutter/material.dart';

import '../common/theme.dart';
import '../services/background_service.dart';

/// 给二级页面兜一层全局背景
///
/// 历史 / 收藏 / 设置这三个页面原本是 tab 内嵌的，`Scaffold` 背景设成了
/// `Colors.transparent`，靠 `ContentView` 里的 BackgroundService 透上来。
/// 一旦从「我的」push 出去，那层背景就没了 —— 直接变成纯黑。
/// 这个包装器把同样的背景层补上，页面本身一行不用改。
class BackdropWrap extends StatelessWidget {
  final Widget child;

  const BackdropWrap({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: Stack(
        children: [
          Positioned.fill(
            child: BackgroundService.instance
                .buildBackground(overlayAlpha: 0.3),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}
