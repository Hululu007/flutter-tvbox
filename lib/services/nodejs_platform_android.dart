// lib/services/nodejs_platform_android.dart
//
// Android 端 Node.js 实现 —— libnode.so + JNI
// -----------------------------------------------------------------------------
// 跟 iOS 的 NodeMobile 是同一个 nodejs-mobile 产物的两种封装：
//   · iOS     NodeMobile.xcframework，Swift 调 node_start()
//   · Android libnode.so（预编译），Kotlin/JNI 调 node::Start()
//
// 启动链路（跟 iOS 完全一致，只是底层不同）：
//   1. 解压 assets/nodejs-project 到 <filesDir>/nodejs-project
//   2. node::Start 跑 main.js --native-port <dartPort>
//   3. main.js 起两个 server：
//        mgmtServer  -> 随机端口，GET /onCatPawOpenPort?type=management 回传
//        spiderServer -> 由 spider bundle 自己 listen，GET ...type=spider 回传
//   4. Dart 拿到 managementPort 后，下载源 index.js 到本地，
//      POST http://127.0.0.1:{mgmt}/source/loadPath 让 node 加载
//   5. 加载成功后 spiderServer 起来，回传 spiderPort
//
// 限制：node::Start 死循环 + V8 单例，没法优雅停，重启要重开 App（iOS 一样）。

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app_log.dart';
import 'nodejs_platform.dart';

class AndroidNodeJSPlatform implements NodeJSPlatform {
  static const MethodChannel _ch = MethodChannel('app.boxclone/nodejs');

  AndroidNodeJSPlatform({
    required this.onNodeReadyChanged,
    required this.onManagementPortChanged,
    required this.onSpiderPortChanged,
  }) {
    _ch.setMethodCallHandler(_handleNativeCall);
  }

  final ValueNotifier<bool> onNodeReadyChanged;
  final ValueNotifier<int> onManagementPortChanged;
  final ValueNotifier<int> onSpiderPortChanged;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
  ));

  bool _running = false;
  int _spiderPort = 0;
  int _managementPort = 0;
  int _nativePort = 0;

  @override
  bool get isRunning => _running;

  @override
  bool get isNodeReady => _running && _managementPort > 0;

  @override
  int get nativeServerPort => _nativePort;

  @override
  int get managementPort => _managementPort;

  @override
  int get spiderPort => _spiderPort;

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onNodeExit':
        final code = call.arguments is int ? call.arguments as int : -1;
        AppLog.instance.log('Android node 退出 code=$code');
        _running = false;
        _spiderPort = 0;
        _managementPort = 0;
        onNodeReadyChanged.value = false;
        onSpiderPortChanged.value = 0;
        onManagementPortChanged.value = 0;
        break;
      default:
        break;
    }
    return null;
  }

  // ---------------------------------------------------------------
  // 启动 / 停止
  // ---------------------------------------------------------------

  @override
  Future<bool> startNodeJS() async {
    if (_running) {
      AppLog.instance.log('Android node 已在运行，跳过');
      return true;
    }
    try {
      final workDir = await _ch.invokeMethod<String>('prepareProject');
      if (workDir == null || workDir.isEmpty) {
        AppLog.instance.log('Android node: prepareProject 返回空');
        return false;
      }

      String? logPath;
      try {
        logPath = await _ch.invokeMethod<String>('nodeLogPath');
      } catch (_) {}

      final ok = await _ch.invokeMethod<bool>('start', {
        'workDir': workDir,
        'nativePort': _nativePort,
        'logPath': logPath,
      });
      if (ok != true) {
        AppLog.instance.log('Android node: native start 返回 false');
        return false;
      }
      _running = true;
      AppLog.instance.log('Android node 线程已起，等 management 端口回传');

      // main.js 起来后先回传 management 端口（通常 1-2 秒）
      return await waitForNodeReady();
    } catch (e, st) {
      AppLog.instance.log('Android node 启动异常: $e\n$st');
      return false;
    }
  }

  @override
  void stopNodeJS() {
    _running = false;
    _spiderPort = 0;
    _managementPort = 0;
    onNodeReadyChanged.value = false;
    onSpiderPortChanged.value = 0;
    onManagementPortChanged.value = 0;
  }

  @override
  void forceResetRunningState() => stopNodeJS();

  @override
  Future<bool> waitForNodeReady() async {
    if (isNodeReady) return true;
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (DateTime.now().isBefore(deadline)) {
      if (isNodeReady) return true;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    AppLog.instance.log('Android node 等待 management 端口超时（60s）');
    return isNodeReady;
  }

  @override
  Future<bool> waitForSpiderPort() async {
    if (_spiderPort > 0) return true;
    // 这个 bundle 的 start() 要 await 网盘模块，实测约 10 秒；
    // 弱网 / 低端机更慢，给到 90 秒
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (DateTime.now().isBefore(deadline)) {
      if (_spiderPort > 0) return true;
      await Future.delayed(const Duration(milliseconds: 250));
    }
    AppLog.instance.log('Android node 等待 spider 端口超时（90s）');
    return _spiderPort > 0;
  }

  // ---------------------------------------------------------------
  // 源加载
  // ---------------------------------------------------------------

  @override
  Future<(bool success, String? message)> loadSource(String urlString) async {
    if (urlString.isEmpty) return (false, 'URL 为空');
    if (_managementPort <= 0) {
      return (false, 'Management 端口未就绪，先启动 Node.js');
    }

    var normalized = urlString;
    if (normalized.endsWith('.js.md5')) {
      normalized = normalized.substring(0, normalized.length - 4);
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null) return (false, '无效的 URL');

    final dir = await getDocumentsSourcePath();
    if (dir.isEmpty) return (false, '拿不到源目录');

    final jsPath = '$dir/index.js';
    final md5Path = '$dir/index.js.md5';

    try {
      // 1) 先看缓存：远程 md5 跟本地一致就不重复下 9MB
      final jsFile = File(jsPath);
      final md5File = File(md5Path);
      if (await jsFile.exists() && await md5File.exists()) {
        String? remoteMd5;
        try {
          final r = await _dio.get<String>('$normalized.md5',
              options: Options(responseType: ResponseType.plain));
          if (r.statusCode == 200 && r.data != null) {
            remoteMd5 = r.data!.trim();
          }
        } catch (_) {}
        final localMd5 = (await md5File.readAsString()).trim();
        if (remoteMd5 != null && remoteMd5.isNotEmpty && remoteMd5 == localMd5) {
          AppLog.instance.log('Android 源命中缓存（md5 一致），跳过下载');
          return await _sendLoadCommand(dir);
        }
      }

      // 2) 下载 index.js
      AppLog.instance.log('Android 下载源: $normalized');
      final jsResp = await _dio.get<List<int>>(normalized,
          options: Options(responseType: ResponseType.bytes));
      if (jsResp.statusCode != 200 || jsResp.data == null) {
        return (false, '源下载失败: HTTP ${jsResp.statusCode}');
      }
      final bytes = jsResp.data!;
      await jsFile.writeAsBytes(bytes, flush: true);
      AppLog.instance.log('Android 源已保存 ${bytes.length} 字节');

      // 3) 下载 md5
      try {
        final m = await _dio.get<String>('$normalized.md5',
            options: Options(responseType: ResponseType.plain));
        if (m.statusCode == 200 && m.data != null) {
          await md5File.writeAsString(m.data!.trim(), flush: true);
        }
      } catch (e) {
        AppLog.instance.log('Android md5 下载失败（不影响加载）: $e');
      }

      // 4) 让 node 加载
      return await _sendLoadCommand(dir);
    } catch (e) {
      return (false, '源加载异常: $e');
    }
  }

  Future<(bool, String?)> _sendLoadCommand(String path) async {
    try {
      final r = await _dio.post(
        'http://127.0.0.1:$_managementPort/source/loadPath',
        data: {'path': path},
        options: Options(
          contentType: 'application/json',
          receiveTimeout: const Duration(seconds: 90),
        ),
      );
      if (r.statusCode != null && r.statusCode! >= 400) {
        return (false, '加载失败: HTTP ${r.statusCode}');
      }
      AppLog.instance.log('Android 源加载指令已发送，等 spider 端口');
      return (true, null);
    } on DioException catch (e) {
      // 这个 bundle 的 start() 要跑约 10 秒，客户端容易先超时；
      // 请求可能已经在服务端跑起来了，所以超时不当失败处理，
      // 交给后面的 waitForSpiderPort 判定。
      AppLog.instance.log('loadPath 请求异常（可能只是超时）: ${e.type}');
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        return (true, null);
      }
      return (false, '加载请求失败: ${e.message}');
    }
  }

  @override
  Future<bool> deleteSource() async {
    try {
      final dir = await getDocumentsSourcePath();
      if (dir.isEmpty) return false;
      final d = Directory(dir);
      if (await d.exists()) await d.delete(recursive: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> getDocumentsSourcePath() async {
    // 放在 nodejs-project 外面：ensureProject 每次会清空自己的工作目录，
    // 源文件要是放里面会被一起删掉
    final base = await getApplicationSupportDirectory();
    final p = '${base.path}/node-source';
    final d = Directory(p);
    if (!await d.exists()) await d.create(recursive: true);
    return p;
  }

  @override
  Future<bool> isNodeRuntimeInstalled() async {
    try {
      return await _ch.invokeMethod<bool>('isLibReady') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  void setNativeServerPort(int port) => _nativePort = port;

  @override
  void onPortReceived(int port, String type) {
    AppLog.instance.log('Android 端口回传: $port ($type)');
    if (type == 'management') {
      _managementPort = port;
      onManagementPortChanged.value = port;
      onNodeReadyChanged.value = true;
      _running = true;
    } else if (type == 'spider' || type.isEmpty) {
      _spiderPort = port;
      onSpiderPortChanged.value = port;
      onNodeReadyChanged.value = true;
      _running = true;
    }
  }

  @override
  void onMessage(String message) {
    // node 主动推的消息，目前没有要处理的
  }

  @override
  Future<void> downloadAndExtractNodeRuntime(
    NodeDownloadConfig cfg, {
    void Function(double progress)? onProgress,
  }) async {
    // Android 不用下载运行时，libnode.so 已在 APK 里
  }
}
