// ============================================================================
// Android 端 Node.js 启动桥
//
// 只做三件事：
//   1. 把 Java 传来的参数转成 char*[]，chdir 到工程目录，调 node::Start()
//   2. 把 node 的 stdout/stderr 重定向到 logcat（否则出错完全没线索）
//   3. 把退出码回传给 Java
//
// node::Start 是阻塞调用，Java 侧必须在独立线程里调它。
// ============================================================================
#include <jni.h>

#include <android/log.h>
#include <unistd.h>

#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

#include "node.h"

#define LOG_TAG "NodeBridge"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace {

// 把 node 的 fd 1/2 接到 logcat。
// 用 pipe + 读线程的方式比 setvbuf 靠谱：node 内部大量用 write(2) 直接写 fd，
// 换掉 FILE* 拦不住。
int g_log_pipe[2] = {-1, -1};
pthread_t g_log_thread{};
volatile bool g_log_running = false;

void* log_pump(void*) {
    char buf[1024];
    std::string line;
    while (g_log_running) {
        ssize_t n = read(g_log_pipe[0], buf, sizeof(buf) - 1);
        if (n <= 0) break;
        buf[n] = '\0';
        line += buf;
        size_t pos;
        while ((pos = line.find('\n')) != std::string::npos) {
            std::string one = line.substr(0, pos);
            line.erase(0, pos + 1);
            if (!one.empty()) {
                LOGI("%s", one.c_str());
            }
        }
        if (line.size() > 4096) {  // 防止没有换行的超长输出把内存吃爆
            LOGI("%s", line.c_str());
            line.clear();
        }
    }
    return nullptr;
}

void redirectStdioToLogcat() {
    if (pipe(g_log_pipe) != 0) {
        LOGE("pipe() 失败");
        return;
    }
    dup2(g_log_pipe[1], STDOUT_FILENO);
    dup2(g_log_pipe[1], STDERR_FILENO);
    g_log_running = true;
    pthread_create(&g_log_thread, nullptr, log_pump, nullptr);
}

}  // namespace

extern "C" JNIEXPORT jint JNICALL
Java_com_example_piliplus_NodeBridge_nativeStart(
        JNIEnv* env, jobject /* thiz */,
        jstring workDir, jobjectArray args) {

    // 工作目录必须是 js 工程根：bundle 里大量 require('./spider/xxx')
    const char* dir = env->GetStringUTFChars(workDir, nullptr);
    if (dir == nullptr) {
        LOGE("workDir 为空");
        return -1;
    }
    if (chdir(dir) != 0) {
        LOGE("chdir 失败: %s", dir);
        env->ReleaseStringUTFChars(workDir, dir);
        return -2;
    }
    LOGI("工作目录 = %s", dir);
    env->ReleaseStringUTFChars(workDir, dir);

    redirectStdioToLogcat();

    const jsize argc = env->GetArrayLength(args);
    std::vector<std::string> store;
    store.reserve(argc);
    for (jsize i = 0; i < argc; ++i) {
        auto js = static_cast<jstring>(env->GetObjectArrayElement(args, i));
        const char* c = env->GetStringUTFChars(js, nullptr);
        store.emplace_back(c ? c : "");
        env->ReleaseStringUTFChars(js, c);
        env->DeleteLocalRef(js);
    }

    std::vector<char*> argv;
    argv.reserve(argc + 1);
    for (auto& s : store) {
        argv.push_back(const_cast<char*>(s.c_str()));
    }
    argv.push_back(nullptr);   // node::Start 期望 argv[argc] == nullptr

    LOGI("node::Start argc=%d argv0=%s argv1=%s", argc,
         argc > 0 ? argv[0] : "-", argc > 1 ? argv[1] : "-");

    const int code = node::Start(static_cast<int>(argc), argv.data());

    LOGE("node::Start 退出，code=%d", code);
    g_log_running = false;
    return code;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_piliplus_NodeBridge_nativeVersion(
        JNIEnv* env, jobject /* thiz */) {
    // 编译期常量，用来确认 so 和头文件版本对得上
    return env->NewStringUTF(NODE_VERSION_STRING);
}
