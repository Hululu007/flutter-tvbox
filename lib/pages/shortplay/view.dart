import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../common/theme.dart';
import '../../models/movie.dart';
import '../../models/movie_sort.dart';
import '../../services/api_config.dart';
import '../../services/source_service.dart';
import '../../widgets/backdrop_wrap.dart';
import '../../widgets/glass.dart';
import '../../widgets/vod_card.dart';
import '../detail/view.dart';

/// 短剧页
///
/// 数据源不单独配置 —— 从当前主页源的分类表里挑名字带「短剧」的那个，
/// 找不到就回落到第一个分类。这样换源之后不用另外维护一套映射。
class ShortPlayPage extends StatefulWidget {
  const ShortPlayPage({super.key});

  @override
  State<ShortPlayPage> createState() => _ShortPlayPageState();
}

class _ShortPlayPageState extends State<ShortPlayPage> {
  final _svc = SourceService.instance;
  final _scroll = ScrollController();

  final _list = <Video>[];
  var _loading = true;
  var _loadingMore = false;
  var _err = '';
  var _page = 1;
  var _pageCount = 1;
  SortData? _sort;
  int _reqId = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >
          _scroll.position.maxScrollExtent - 400) {
        _loadMore();
      }
    });
    _boot();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final req = ++_reqId;
    final source = ApiConfig.instance.homeSourceBean.value;
    if (source == null) {
      setState(() {
        _loading = false;
        _err = '还没选数据源，去「我的 → 设置」里填接口地址';
      });
      return;
    }

    setState(() {
      _loading = true;
      _err = '';
      _list.clear();
      _page = 1;
    });

    try {
      final (sorts, _) = await _svc.getSort(source);
      if (!mounted || req != _reqId) return;

      // 优先精确命中「短剧」，其次模糊，最后回落第一个分类
      SortData? pick;
      for (final s in sorts) {
        if (s.name.contains('短剧')) {
          pick = s;
          break;
        }
      }
      pick ??= sorts.isNotEmpty ? sorts.first : null;
      _sort = pick;

      if (pick == null) {
        setState(() {
          _loading = false;
          _err = '当前源没有可用分类';
        });
        return;
      }

      final items = await _svc.getList(source, pick, page: 1);
      if (!mounted || req != _reqId) return;
      setState(() {
        _list
          ..clear()
          ..addAll(items);
        _loading = false;
        _page = 1;
      });
    } catch (e) {
      if (!mounted || req != _reqId) return;
      setState(() {
        _loading = false;
        _err = '$e';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _err.isNotEmpty) return;
    if (_page >= _pageCount) return;
    final source = ApiConfig.instance.homeSourceBean.value;
    final sort = _sort;
    if (source == null || sort == null) return;

    setState(() => _loadingMore = true);
    final req = _reqId;
    try {
      final items = await _svc.getList(source, sort, page: _page + 1);
      if (!mounted || req != _reqId) return;
      setState(() {
        // 去重：不同页偶尔会重叠
        final seen = _list.map((v) => v.id).toSet();
        _list.addAll(items.where((v) => !seen.contains(v.id)));
        _page += 1;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.spacingLG, AppTheme.spacingSM, AppTheme.spacingLG, 10),
      child: Row(
        children: [
          Text(
            '短剧',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: AppTheme.fontTitle2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          if (_sort != null)
            Glass(
              radius: 10,
              blur: 12,
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              child: Text(
                _sort!.name,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: AppTheme.fontCaption,
                ),
              ),
            ),
          const Spacer(),
          GestureDetector(
            onTap: _boot,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.refresh,
                  size: 19, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
              strokeWidth: 2.2, color: AppTheme.accentColor),
        ),
      );
    }

    if (_err.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.movie_filter_outlined,
                  size: 40, color: AppTheme.textTertiary),
              const SizedBox(height: 14),
              Text(
                _err,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: AppTheme.fontSubhead,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _boot,
                child: Text('重试',
                    style: TextStyle(color: AppTheme.accentColor)),
              ),
            ],
          ),
        ),
      );
    }

    if (_list.isEmpty) {
      return Center(
        child: Text(
          '这个分类下暂时没有内容',
          style: TextStyle(
              color: AppTheme.textTertiary, fontSize: AppTheme.fontSubhead),
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.accentColor,
      backgroundColor: AppTheme.backgroundSecondary,
      onRefresh: _boot,
      child: LayoutBuilder(
        builder: (context, c) {
          const gap = AppTheme.cardSpacing;
          final cols =
              (c.maxWidth / (120 + gap)).floor().clamp(2, 6);
          final w = (c.maxWidth - gap * (cols - 1)) / cols;

          return GridView.builder(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingLG, 2, AppTheme.spacingLG, 116),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              childAspectRatio: w / (w * AppTheme.posterRatio + 40),
              crossAxisSpacing: gap,
              mainAxisSpacing: gap + 6,
            ),
            itemCount: _list.length + (_loadingMore ? 1 : 0),
            itemBuilder: (context, i) {
              if (i >= _list.length) {
                return const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.accentColor),
                  ),
                );
              }
              final v = _list[i];
              return VodCard(
                video: v,
                onTap: () => Get.toNamed('/detail', arguments: v),
              );
            },
          );
        },
      ),
    );
  }
}
