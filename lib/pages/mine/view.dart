import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../common/theme.dart';
import '../../models/cache_store.dart';
import '../../widgets/backdrop_wrap.dart';
import '../../widgets/glass.dart';
import '../favorites/view.dart';
import '../history/view.dart';
import '../settings/view.dart';

/// 「我的」页
///
/// 参考稿里底部只留 4 个 tab（首页 / 短剧 / 直播 / 我的），
/// 原来的历史、收藏、设置全部收进这里，二级页面 push 出去。
class MinePage extends StatelessWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppTheme.spacingLG, AppTheme.spacingMD, AppTheme.spacingLG, 120),
          children: [
            _buildProfile(),
            const SizedBox(height: 18),
            _buildGroup([
              _Row(
                icon: Icons.history,
                title: '观看历史',
                subtitle: '继续上次没看完的',
                onTap: () =>
                    Get.to(() => const BackdropWrap(child: HistoryPage())),
              ),
              _Row(
                icon: Icons.favorite_border,
                title: '我的收藏',
                subtitle: '追的剧都在这儿',
                onTap: () => Get.to(
                    () => const BackdropWrap(child: FavoritesPage())),
              ),
              _Row(
                icon: Icons.play_circle_outline,
                title: '播放记录',
                subtitle: '播放进度与线路记忆',
                onTap: () =>
                    Get.to(() => const BackdropWrap(child: HistoryPage())),
              ),
            ]),
            const SizedBox(height: 14),
            _buildGroup([
              _Row(
                icon: Icons.settings_outlined,
                title: '设置',
                subtitle: '接口、播放器、主题',
                onTap: () =>
                    Get.to(() => const BackdropWrap(child: SettingsPage())),
              ),
              _Row(
                icon: Icons.info_outline,
                title: '关于',
                subtitle: '版本与开源说明',
                onTap: () => _showAbout(context),
              ),
            ]),
            const SizedBox(height: 22),
            Center(
              child: Text(
                'v1.0.0',
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: AppTheme.fontCaption,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfile() {
    return Obx(() {
      final n = CacheStore.instance.records.length;
      final f = CacheStore.instance.favorites.length;
      return Glass(
        radius: AppTheme.radiusLG,
        blur: 20,
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                gradient: AppTheme.accentGradientV,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.person, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '本机用户',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: AppTheme.fontHeadline,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$n 条观看 · $f 部收藏',
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: AppTheme.fontCaption,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildGroup(List<_Row> rows) {
    return Glass(
      radius: AppTheme.radiusLG,
      blur: 20,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(color: AppTheme.borderLight, height: 1, indent: 52),
            rows[i],
          ],
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        title: Text('关于', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Flutter 双端影视客户端\n\n'
          '界面基于 NewTv 改造，爬虫层沿用 CatVod / 猫爪协议。\n'
          '本软件不含任何视频内容，所有数据来自用户自行配置的接口。',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: AppTheme.fontSubhead,
            height: 1.7,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('知道了',
                style: TextStyle(color: AppTheme.accentColor)),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.accentColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: AppTheme.fontBody,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: AppTheme.fontCaption,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 18, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}
