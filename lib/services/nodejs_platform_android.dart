// lib/services/nodejs_platform_android.dart
//
// Android 端的 Node.js 落地实现：**安全降级（No-Op）**
// -----------------------------------------------------------------------------
// 背景：
//   Node 通道（nodejs-mobile + libnode.so + JNI）目前只在 iOS 上做完。
//   Android 上如果沿用原来的 UnimplementedError 骨架，App 一启动就会在
//   NodeJSManager 初始化处抛异常，整个界面白屏——连带把本来不需要 Node 的
//   苹果CMS（type=1）源也一起废掉。
//
// 这个类的职责只有一个：**告诉上层"没有 Node"**，让 App 正常跑下去。
//
// 哪些源还能用（不需要 Node）：
//   - type=1  苹果CMS v10 JSON 采集站  → SourceService 里走 Dart 直连（ac=class / ac=detail）
//   - type=0  XML 接口                 → Dart 直连
//   - type=4  远程 JSON 接口            → Dart 直连
//   - 直链 / 推送播放                   → 纯播放器行为
//
// 哪些源不能用：
//   - isSpiderSource（type=3 / type=9，csp_xxx 这类跑在 Node 里的 js 源）
//     这些要靠 libnode.so + JNI，等 Android 侧补完 libnode 之后才能用。
//
// 后续补 Android Node 时，把下面这些方法换成真正的 JNI 调用即可，
// 上层（NodeJSManager / SourceService）一行都不用改。

import 'dart:async';

import 'package:flutter/foundation.dart' show ValueNotifier;

import 'nodejs_platform.dart';

class AndroidNodeJSPlatform implements NodeJSPlatform {
  AndroidNodeJSPlatform({
    required this.onNodeReadyChanged,
    required this.onManagementPortChanged,
    required this.onSpiderPortChanged,
  });

  final ValueNotifier<bool> onNodeReadyChanged;
  final ValueNotifier<int> onManagementPortChanged;
  final ValueNotifier<int> onSpiderPortChanged;

  /// Android 版当前没有内嵌 Node，恒为 false
  @override
  bool get isRunning => false;

  @override
  bool get isNodeReady => false;

  @override
  int get nativeServerPort => 0;

  @override
  int get managementPort => 0;

  @override
  int get spiderPort => 0;

  // ---------------------------------------------------------------
  // 生命周期：全部静默失败，不抛异常
  // ---------------------------------------------------------------

  @override
  Future<bool> startNodeJS() async {
    // 不启动、不报错。上层拿到 false 后按"无 Node"分支处理。
    onNodeReadyChanged.value = false;
    onManagementPortChanged.value = 0;
    onSpiderPortChanged.value = 0;
    return false;
  }

  @override
  void stopNodeJS() {
    onNodeReadyChanged.value = false;
    onManagementPortChanged.value = 0;
    onSpiderPortChanged.value = 0;
  }

  @override
  void forceResetRunningState() {
    onNodeReadyChanged.value = false;
    onManagementPortChanged.value = 0;
    onSpiderPortChanged.value = 0;
  }

  @override
  Future<bool> waitForNodeReady() async => false;

  @override
  Future<bool> waitForSpiderPort() async => false;

  // ---------------------------------------------------------------
  // 源管理
  // ---------------------------------------------------------------

  @override
  Future<(bool success, String? message)> loadSource(String urlString) async {
    return (
      false,
      'Android 版暂不支持 Node 源（csp 类型）。'
          '苹果CMS 采集站不需要 Node，配置里填 type=1 的接口即可。'
    );
  }

  @override
  Future<bool> deleteSource() async => false;

  @override
  Future<String> getDocumentsSourcePath() async => '';

  /// iOS 是"永远 true"（framework 嵌进 bundle）。
  /// Android 返回 false，让 UI 走"未安装运行时"的分支而不是"已就绪"。
  @override
  Future<bool> isNodeRuntimeInstalled() async => false;

  @override
  void setNativeServerPort(int port) {
    // 没有 Node，不需要回传端口
  }

  @override
  void onPortReceived(int port, String type) {
    // 不会收到
  }

  @override
  void onMessage(String message) {
    // 不会收到
  }

  @override
  Future<void> downloadAndExtractNodeRuntime(
    NodeDownloadConfig cfg, {
    void Function(double progress)? onProgress,
  }) async {
    // Android 不走"下载 node 运行时"那套（那是 Windows 的路子）
  }
}
