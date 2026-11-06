import 'package:flutter/material.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import '../common/theme.dart';
import '../models/movie.dart';

/// 视频卡片 —— 纯海报流
///
/// 视觉约定（跟首页网格保持一致）：
///   - 卡片本身不画底板，海报就是卡片，底色交给全局背景层
///   - 海报宽高比走 AppTheme.posterRatio（1.47），圆角 8
///   - note 做成图内右下角的胶囊，深色半透明底，不抢画面
///   - 片名压在下面居中，最多两行，元数据只在有值时才出现
class VodCard extends StatelessWidget {
  final Video video;
  final VoidCallback? onTap;

  const VodCard({super.key, required this.video, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.max,
        children: [
          // 海报区吃掉剩余高度，文字区固定，网格里高度一致
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildPoster(),
                  // 底部压暗，保证浅色海报上的胶囊也读得清
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 46,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (video.note.isNotEmpty)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          video.note,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            video.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: AppTheme.fontFootnote,
              height: 1.25,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (_metaText.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              _metaText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: AppTheme.fontCaption,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  String get _metaText {
    final parts = [video.type, video.year].where((s) => s.isNotEmpty).toList();
    return parts.join(' · ');
  }

  Widget _buildPoster() {
    final picUrl = video.pic.trim();
    if (picUrl.isEmpty || !picUrl.startsWith('http')) {
      return _placeholder();
    }

    var url = picUrl;
    if (url.startsWith('//')) url = 'https:$url';

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      // 采集站的图床基本都校验 Referer，不带就 403
      httpHeaders: {
        'User-Agent': 'Mozilla/5.0',
        'Referer': 'https://${Uri.parse(url).host}/',
      },
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (context, url) => ColoredBox(
        color: AppTheme.backgroundTertiary,
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.accentColor,
            ),
          ),
        ),
      ),
      errorBuilder: (context, url, error) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: AppTheme.backgroundTertiary,
      child: Center(
        child: Icon(Icons.movie_outlined,
            color: AppTheme.textTertiary, size: 22),
      ),
    );
  }
}
