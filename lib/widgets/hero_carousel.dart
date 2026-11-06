import 'dart:async';

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../common/theme.dart';
import '../models/movie.dart';

/// 首页顶部主视觉轮播
///
/// 设计取舍：
///   - 采集站的 vod_pic 是竖版海报（2:3），这里按 2:1 横向裁切。
///     裁切会切掉上下，但 cover 保证不留白，比居中 contain 的"左右两条黑边"好看。
///   - 上下各压一层渐变：顶部让状态栏/返回按钮可读，底部托住标题和指示点。
///   - 指示点选中态拉长成 14×5 的胶囊，不用圆点——圆点在深色图上几乎看不见。
///   - 自动轮播 4.5s；用户手动滑动后重置计时，避免刚划完就被抢走。
class HeroCarousel extends StatefulWidget {
  final List<Video> videos;
  final void Function(Video video)? onTap;

  const HeroCarousel({
    super.key,
    required this.videos,
    this.onTap,
  });

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  static const Duration _interval = Duration(milliseconds: 4500);

  final PageController _pc = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant HeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 换源或刷新后列表整体变了，回到第一张
    if (oldWidget.videos.length != widget.videos.length ||
        (oldWidget.videos.isNotEmpty &&
            widget.videos.isNotEmpty &&
            oldWidget.videos.first.id != widget.videos.first.id)) {
      _index = 0;
      if (_pc.hasClients) _pc.jumpToPage(0);
      _restartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.videos.length <= 1) return;
    _timer = Timer.periodic(_interval, (_) {
      if (!mounted || !_pc.hasClients) return;
      final next = (_index + 1) % widget.videos.length;
      _pc.animateToPage(
        next,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.videos;
    if (list.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth - AppTheme.spacingLG * 2;
        final h = w * 0.5;

        return Padding(
          padding: const EdgeInsets.fromLTRB(
              AppTheme.spacingLG, 2, AppTheme.spacingLG, 10),
          child: SizedBox(
            height: h,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 图片层
                  NotificationListener<ScrollNotification>(
                    onNotification: (_) {
                      // 手动滑动后重置自动轮播计时
                      _restartTimer();
                      return false;
                    },
                    child: PageView.builder(
                      controller: _pc,
                      itemCount: list.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (context, i) => _slide(list[i]),
                    ),
                  ),

                  // 底部压暗，托住标题
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: h * 0.62,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.35),
                              Colors.black.withValues(alpha: 0.86),
                            ],
                            stops: const [0, 0.45, 1],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 标题 + 元信息
                  Positioned(
                    left: 14,
                    right: 76,
                    bottom: 12,
                    child: IgnorePointer(child: _caption(list[_index])),
                  ),

                  // 指示点
                  if (list.length > 1)
                    Positioned(
                      right: 14,
                      bottom: 16,
                      child: IgnorePointer(child: _dots(list.length)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _slide(Video v) {
    final url = _posterUrl(v.pic);
    return GestureDetector(
      onTap: () => widget.onTap?.call(v),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url == null)
            ColoredBox(color: AppTheme.backgroundSecondary)
          else
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              // 竖版海报裁成 2:1 时优先保上部（人物头部大多在上半）
              alignment: const Alignment(0, -0.35),
              httpHeaders: {
                'User-Agent': 'Mozilla/5.0',
                'Referer': 'https://${Uri.parse(url).host}/',
              },
              fadeInDuration: const Duration(milliseconds: 220),
              placeholder: (context, u) =>
                  ColoredBox(color: AppTheme.backgroundSecondary),
              errorBuilder: (context, u, e) =>
                  ColoredBox(color: AppTheme.backgroundSecondary),
            ),
          // 图上再盖一层极淡的蓝紫，跟整体色调统一
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.accentColor.withValues(alpha: 0.10),
                  Colors.transparent,
                  AppTheme.accentLightColor.withValues(alpha: 0.08),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _caption(Video v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          v.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            height: 1.2,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            shadows: [
              Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 1)),
            ],
          ),
        ),
        if (_sub(v).isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            _sub(v),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _dots(int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final on = i == _index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.only(left: i == 0 ? 0 : 5),
          width: on ? 14 : 5,
          height: 5,
          decoration: BoxDecoration(
            gradient: on ? AppTheme.accentGradient : null,
            color: on ? null : Colors.white.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  String _sub(Video v) {
    final parts = <String>[];
    if (v.note.isNotEmpty) parts.add(v.note);
    if (v.type.isNotEmpty) parts.add(v.type);
    if (v.year.isNotEmpty) parts.add(v.year);
    return parts.join(' · ');
  }

  String? _posterUrl(String raw) {
    var u = raw.trim();
    if (u.isEmpty) return null;
    if (u.startsWith('//')) u = 'https:$u';
    if (!u.startsWith('http')) return null;
    return u;
  }
}
