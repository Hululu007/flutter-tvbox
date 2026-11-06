package com.example.piliplus

import android.content.Context
import android.util.Log
import java.io.File

/**
 * Android 端 Node.js 运行时封装
 *
 * 跟 iOS 的 NodeMobile 是同一个东西的不同形态：
 *   · iOS：NodeMobile.xcframework，Swift 直接调 node_start()
 *   · Android：libnode.so（nodejs-mobile 预编译），JNI 调 node::Start()
 *
 * 用法：
 *   NodeBridge.ensureProject(context)   // 把 assets 里的 js 工程解到私有目录（幂等）
 *   NodeBridge.start(projectDir, port)  // 起独立线程跑 node，阻塞在里面
 *   NodeBridge.stop()                   // 没法优雅停，只能杀进程；实际靠重启 App
 *
 * 注意：node::Start 跑起来后不能正常 shutdown（V8 单例），这点跟 iOS 一样。
 */
object NodeBridge {
    private const val TAG = "NodeBridge"

    private var libReady = false
    private var thread: Thread? = null

    @Volatile
    var isLoaded = false
        private set

    @Volatile
    var isRunning = false
        private set

    /** node 退出时回调，参数是退出码 */
    @Volatile
    var onExit: ((Int) -> Unit)? = null

    // ---- native ----
    @JvmStatic
    private external fun nativeStart(workDir: String, args: Array<String>): Int

    @JvmStatic
    private external fun nativeVersion(): String

    fun load(): Boolean {
        if (libReady) return true
        return try {
            System.loadLibrary("nodewrap")
            libReady = true
            Log.i(TAG, "libnodewrap 已加载，内置 node 版本 = ${runCatching { nativeVersion() }.getOrElse { "?" }}")
            true
        } catch (t: Throwable) {
            Log.e(TAG, "加载 libnodewrap 失败: ${t.message}", t)
            false
        }
    }

    /**
     * 把 assets/nodejs-project 解到 filesDir/nodejs-project。
     * 每次启动都覆盖写一遍：bundle 更新后旧文件不会残留。
     */
    fun ensureProject(context: Context): File {
        val root = File(context.filesDir, "nodejs-project")
        val stamp = File(root, ".stamp")
        val wanted = "v1"

        if (stamp.exists() && stamp.readText().trim() == wanted &&
            File(root, "main.js").exists()
        ) {
            Log.i(TAG, "nodejs-project 已就绪: ${root.absolutePath}")
            return root
        }

        Log.i(TAG, "解压 nodejs-project -> ${root.absolutePath}")
        if (root.exists()) root.deleteRecursively()
        root.mkdirs()

        copyAssetDir(context, "nodejs-project", root)
        stamp.writeText(wanted)
        Log.i(TAG, "解压完成，文件数 = ${root.walkTopDown().count { it.isFile }}")
        return root
    }

    private fun copyAssetDir(context: Context, assetPath: String, dest: File) {
        val am = context.assets
        val children = am.list(assetPath) ?: return
        if (children.isEmpty()) {
            // 是文件
            dest.parentFile?.mkdirs()
            am.open(assetPath).use { input ->
                dest.outputStream().use { output -> input.copyTo(output) }
            }
            return
        }
        dest.mkdirs()
        for (name in children) {
            copyAssetDir(context, "$assetPath/$name", File(dest, name))
        }
    }

    /**
     * 启动 node。内部起独立线程，函数立即返回。
     *
     * @param workDir  js 工程根目录（main.js 所在目录）
     * @param nativePort Dart 侧 HTTP 端口，node 启动后 GET /onCatPawOpenPort 把 spider 端口回传
     * @param logPath 可选的 node 日志文件路径
     */
    @Synchronized
    fun start(workDir: String, nativePort: Int, logPath: String? = null): Boolean {
        if (isRunning) {
            Log.w(TAG, "node 已在运行，忽略重复启动")
            return false
        }
        if (!load()) return false

        val args = mutableListOf(
            "node",
            File(workDir, "main.js").absolutePath,
            "--native-port",
            nativePort.toString()
        )
        if (!logPath.isNullOrBlank()) {
            args += "--node-log-path"
            args += logPath
        }

        thread = Thread({
            isRunning = true
            isLoaded = true
            val code = try {
                nativeStart(workDir, args.toTypedArray())
            } catch (t: Throwable) {
                Log.e(TAG, "nativeStart 抛出: ${t.message}", t)
                -99
            }
            isRunning = false
            Log.w(TAG, "node 线程结束，code=$code")
            onExit?.invoke(code)
        }, "node-js-main").also { it.start() }

        return true
    }

    /**
     * 没法真正停 —— node::Start 内部是死循环，V8 也是单例。
     * 这里只把状态标掉，实际要重启整个进程才干净。
     */
    fun stop() {
        Log.w(TAG, "Android 端不支持优雅停止 node，需要重启 App")
        isRunning = false
    }
}
