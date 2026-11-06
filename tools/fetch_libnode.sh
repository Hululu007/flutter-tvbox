#!/usr/bin/env bash
# ============================================================================
# 拉取 Android 用的 libnode（nodejs-mobile 预编译产物）
#
#   npm 包 nodejs-mobile-react-native 里自带
#     android/libnode/bin/<abi>/libnode.so   预编译共享库（每个 ABI 55-60MB）
#     android/libnode/include/node/           头文件（node.h / v8.h 等）
#
#   仓库里不放这个二进制（太大），CI 和本地都在构建前跑一次这个脚本。
#
# 用法：
#   ./tools/fetch_libnode.sh              # 只留 arm64-v8a（推荐，APK 小一半）
#   ./tools/fetch_libnode.sh --all-abi    # 三个 ABI 全留
# ============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HERE/android/app/src/main/cpp/libnode"
VER="18.20.4"
URL="https://registry.npmmirror.com/nodejs-mobile-react-native/-/nodejs-mobile-react-native-${VER}.tgz"

ALL_ABI=false
for a in "$@"; do
    case "$a" in
        --all-abi) ALL_ABI=true ;;
        *) echo "未知参数: $a"; exit 1 ;;
    esac
done

if [ -f "$DEST/bin/arm64-v8a/libnode.so" ] && \
   [ -f "$DEST/bin/x86_64/libnode.so" ] && \
   [ -d "$DEST/include/node" ]; then
    echo "✓ libnode 已存在：$DEST"
    du -sh "$DEST"
    exit 0
fi

echo "▶ 下载 nodejs-mobile-react-native@$VER（约 100 MB）…"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fL --retry 3 --retry-delay 4 --max-time 900 -o "$TMP/njm.tgz" "$URL"
echo "  下载完成：$(du -h "$TMP/njm.tgz" | awk '{print $1}')"

echo "▶ 解包 …"
# 必须 cd 进去再解：Windows 的 bsdtar 会把 -C 后面的 "C:/..." 当成
# 远程主机名（host:path 语法），报 "Cannot connect to C: resolve failed"
(
    cd "$TMP"
    tar -xzf njm.tgz
)

SRC="$TMP/package/android/libnode"
if [ ! -d "$SRC" ]; then
    echo "✗ 包里没找到 android/libnode"
    ls -R "$TMP/package/android" | head -30
    exit 1
fi

echo "▶ 复制到 $DEST …"
rm -rf "$DEST"
mkdir -p "$DEST/bin"
cp -R "$SRC/include" "$DEST/include"

# jniLibs 是 AGP 真正打进 APK 的目录。
# CMake 里的 IMPORTED SHARED 库只负责链接，不会自动进 APK —— 两边都要放。
JNI="$HERE/android/app/src/main/jniLibs"
mkdir -p "$JNI"

if [ "$ALL_ABI" = "true" ]; then
    cp -R "$SRC/bin/." "$DEST/bin/"
    for abi in arm64-v8a armeabi-v7a x86_64; do
        if [ -f "$SRC/bin/$abi/libnode.so" ]; then
            mkdir -p "$JNI/$abi"
            cp "$SRC/bin/$abi/libnode.so" "$JNI/$abi/"
        fi
    done
else
    # 默认拉三个 ABI（配合 CI 的 --split-per-abi 按 ABI 拆 APK）：
    #   arm64-v8a / armeabi-v7a —— 真机
    #   x86_64                  —— MuMu/雷电等模拟器。它们的 ARM 转译层
    #     （libhoudini / NdkTranslation）跑不动 libnode 这种带完整 V8 的
    #     大 so，加载即 SIGSEGV，必须给原生 x86_64 版。
    # 为什么 arm 的两个都要放：AGP 的 externalNativeBuild 会为
    # jniLibs/插件声明的每个 ABI 各跑一次 configure，缺哪个就在
    # configure 阶段报错（CMake 侧已改成 WARNING+return 兜底）。
    for abi in arm64-v8a armeabi-v7a x86_64; do
        if [ ! -f "$SRC/bin/$abi/libnode.so" ]; then
            echo "⚠ 包里没有 $abi 的 libnode.so，跳过"
            continue
        fi
        mkdir -p "$DEST/bin/$abi" "$JNI/$abi"
        cp "$SRC/bin/$abi/libnode.so" "$DEST/bin/$abi/"
        cp "$SRC/bin/$abi/libnode.so" "$JNI/$abi/"
    done
fi

echo ""
echo "✅ libnode 就位"
du -sh "$DEST"
echo "--- ABI ---"
ls "$DEST/bin"
echo "--- 头文件 ---"
ls "$DEST/include/node" | head -8
