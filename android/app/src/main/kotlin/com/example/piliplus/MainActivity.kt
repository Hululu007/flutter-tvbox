package com.example.piliplus

import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.WindowManager.LayoutParams
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 主 Activity。
 *
 * 原件继承的是 `com.ryanheise.audioservice.AudioServiceActivity`，但 pubspec 里
 * 并没有 `audio_service` / `just_audio` 这两个依赖（作者是从 PiliPlus 抄过来忘改了），
 * 导致 Android 端 `:app:compileReleaseKotlin` 直接报
 * `Unresolved reference 'ryanheise'`，整个 APK 编不出来。
 *
 * 这里换回 Flutter 官方的 FlutterActivity。播放用它自己的原生实现
 * （media_kit / libmpv），不依赖 audio_service 的前台 Service。
 * 原来 onDestroy 里那句 stopService(AudioService) 也一并去掉。
 */
class MainActivity : FlutterActivity() {

    private var nodeChannel: MethodChannel? = null

    /**
     * Node.js 通道。Dart 侧 MethodChannel('app.boxclone/nodejs')。
     *
     * 只做四件事：解压 js 工程、报日志路径、查 so 是否加载、启动 node 线程。
     * node 起来之后的所有通信走 HTTP（127.0.0.1），不走 channel。
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        nodeChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.boxclone/nodejs"
        ).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "prepareProject" -> {
                        try {
                            val dir = NodeBridge.ensureProject(applicationContext)
                            result.success(dir.absolutePath)
                        } catch (t: Throwable) {
                            Log.e("NodeBridge", "prepareProject 失败", t)
                            result.error("PREPARE_FAILED", t.message, null)
                        }
                    }

                    "projectDir" -> {
                        result.success(
                            File(applicationContext.filesDir, "nodejs-project").absolutePath
                        )
                    }

                    "nodeLogPath" -> {
                        val f = File(applicationContext.filesDir, "node.log")
                        result.success(f.absolutePath)
                    }

                    "isLibReady" -> result.success(NodeBridge.load())

                    "start" -> {
                        val workDir = call.argument<String>("workDir")
                        val nativePort = call.argument<Int>("nativePort") ?: 0
                        val logPath = call.argument<String>("logPath")
                        if (workDir.isNullOrEmpty()) {
                            result.error("BAD_ARGS", "workDir 为空", null)
                        } else {
                            NodeBridge.onExit = { code ->
                                Handler(Looper.getMainLooper()).post {
                                    nodeChannel?.invokeMethod("onNodeExit", code)
                                }
                            }
                            val ok = NodeBridge.start(workDir, nativePort, logPath)
                            result.success(ok)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        nodeChannel?.setMethodCallHandler(null)
        nodeChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (AndroidHelper.isFoldable) {
            AndroidHelper.ToDart.onConfigurationChanged?.run()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 刘海屏铺满：播放页要贴到屏幕四边
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        AndroidHelper.ToDart.onUserLeaveHint?.run()
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration?
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        AndroidHelper.isPipMode = isInPictureInPictureMode
    }
}
