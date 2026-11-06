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
     *
     * 入口说明：真正的运行时 bundle 在 dist/main.js（esbuild 产物）。
     * 根目录的 main.js 是这里生成的保护壳：捕获 bundle 的启动异常、
     * 挂住未捕获异常 —— node 一旦 exit()，进程级 stdio mutex 会被销毁，
     * 其它线程（HWUI 等）碰到就 FORTIFY SIGABRT 把整个 App 带崩。
     */
    fun ensureProject(context: Context): File {
        val root = File(context.filesDir, "nodejs-project")
        val stamp = File(root, ".stamp")
        val wanted = "v3"

        if (stamp.exists() && stamp.readText().trim() == wanted &&
            File(root, "dist/main.js").exists() &&
            File(root, "main.js").exists() &&
            File(root, "dist/package.json").exists()
        ) {
            Log.i(TAG, "nodejs-project 已就绪: ${root.absolutePath}")
            return root
        }

        Log.i(TAG, "解压 nodejs-project -> ${root.absolutePath}")
        if (root.exists()) root.deleteRecursively()
        root.mkdirs()

        copyAssetDir(context, "nodejs-project", root)
        writeEntryShim(File(root, "main.js"))
        writeCjsMarker(File(root, "dist/package.json"))
        stamp.writeText(wanted)
        Log.i(TAG, "解压完成，文件数 = ${root.walkTopDown().count { it.isFile }}")
        return root
    }

    /**
     * 根目录 package.json 声明了 "type": "module"（上游 repo 原样），
     * 但 dist/main.js 是 esbuild format=cjs 的产物 —— 不隔离的话
     * node 会把 bundle 按 ESM 解析，直接 ReferenceError: require is not defined。
     * 给 dist 写独立 package.json 锁定 CJS 语义。
     */
    private fun writeCjsMarker(out: File) {
        out.writeText("""{"type":"commonjs"}""")
    }

    /**
     * 根级入口壳（ESM —— 根 package.json type=module，node 按 ESM 解析本文件）：
     * 用 createRequire 拿到 CJS 的 require 加载 dist bundle。
     * 捕获 bundle 启动异常、挂住未捕获异常 —— node 一旦 exit()，
     * 进程级 stdio mutex 被销毁，其它线程（HWUI 等）碰到就
     * FORTIFY SIGABRT 把整个 App 带崩，所以 node 必须永远不退出。
     */
    private fun writeEntryShim(out: File) {
        val shim = """
            import { createRequire } from 'module';
            const require = createRequire(import.meta.url);
            process.on('uncaughtException', function (e) {
                console.error('[shim] uncaughtException: ' + ((e && e.stack) || e));
            });
            process.on('unhandledRejection', function (r) {
                console.error('[shim] unhandledRejection: ' + ((r && r.stack) || r));
            });
            try {
                require('./dist/main.js');
            } catch (e) {
                console.error('[shim] bundle boot failed: ' + ((e && e.stack) || e));
            }
            // 兜底：bundle 没起来或全部退完后保持事件循环活着，node 不退出
            setInterval(function () {}, 1 << 30);
        """.trimIndent()
        out.writeText(shim)
        Log.i(TAG, "写入入口壳 main.js (${out.length()} bytes)")
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
