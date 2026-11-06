#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
修 Flutter 插件在 AGP 9 / Kotlin 2.3 下的不兼容。

问题（screen_brightness_android 2.1.5 的 android/build.gradle）：

    def agpMajor = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.tokenize('.')[0] as int
    if (agpMajor < 9) {
       apply plugin: 'kotlin-android'
    }
    ...
    kotlin {
        compilerOptions { jvmTarget = ... }
    }

这个插件假设"AGP 9 以上 Kotlin 插件会自动挂上"，实际并不会。于是：
  · 不挂插件时，顶层 `kotlin {}` 报 Could not find method kotlin()
  · 只删 kotlin{} 也不够 —— Kotlin 源码根本不编译，
    GeneratedPluginRegistrant 里引用 ScreenBrightnessAndroidPlugin 就报
    "cannot find symbol"

正确处理：
  1. `apply plugin: 'kotlin-android'` 去掉 agpMajor 条件，无条件应用
  2. 删掉顶层 `kotlin {}` 块（jvmTarget 已由项目根 build.gradle.kts 的
     subprojects{} 统一设成 17，这里再设 1.8 反而冲突）

用法：
    python tools/patch_flutter_plugins.py
    PUB_CACHE=/path/to/pubcache python tools/patch_flutter_plugins.py
"""
import glob
import os
import re
import sys

TARGETS = ["screen_brightness_android-*"]

COND_RE = re.compile(
    r"if\s*\(\s*agpMajor\s*<\s*9\s*\)\s*\{\s*apply\s+plugin:\s*'kotlin-android'\s*\}",
    re.S,
)


def pub_cache():
    p = os.environ.get("PUB_CACHE")
    if p:
        return p
    home = os.path.expanduser("~")
    for c in (os.path.join(home, ".pub-cache"),
              os.path.join(home, "AppData", "Local", "Pub", "Cache"),
              os.path.join(home, "Library", "Caches", "Pub")):
        if os.path.isdir(c):
            return c
    return None


def drop_block(src, head):
    """删掉 head 开头的 {...} 块，按大括号配对"""
    idx = src.find(head)
    if idx == -1:
        return src, False
    brace = src.find("{", idx)
    if brace == -1:
        return src, False
    depth, i = 1, brace + 1
    while i < len(src) and depth > 0:
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
        i += 1
    if depth != 0:
        return src, False
    start = src.rfind("\n", 0, idx)
    start = start if start != -1 else idx
    end = i
    while end < len(src) and src[end] in "\r\n":
        end += 1
    return src[:start] + "\n" + src[end:], True


def patch_one(f):
    with open(f, encoding="utf-8") as fh:
        src = orig = fh.read()
    notes = []

    # 1) kotlin 插件无条件应用
    if COND_RE.search(src):
        src = COND_RE.sub("apply plugin: 'kotlin-android'", src)
        notes.append("kotlin-android 插件改为无条件应用")
    elif "apply plugin: 'kotlin-android'" in src:
        notes.append("kotlin-android 已无条件应用")

    # 2) 删顶层 kotlin {}
    if "\nkotlin {" in src:
        src, ok = drop_block(src, "\nkotlin {")
        if ok:
            notes.append("移除顶层 kotlin{} 块")
            while "\nkotlin {" in src:      # 极少数文件会写两次
                src, ok2 = drop_block(src, "\nkotlin {")
                if not ok2:
                    break

    if src == orig:
        return notes or ["无需处理"]

    with open(f, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(src)
    return notes


def main():
    cache = pub_cache()
    if not cache:
        print("✗ 找不到 PUB_CACHE，跳过")
        return 0
    hosted = os.path.join(cache, "hosted", "pub.dev")
    if not os.path.isdir(hosted):
        print(f"✗ {hosted} 不存在，跳过")
        return 0

    n = 0
    for pat in TARGETS:
        for d in glob.glob(os.path.join(hosted, pat)):
            f = os.path.join(d, "android", "build.gradle")
            if not os.path.isfile(f):
                continue
            notes = patch_one(f)
            print(f"  {os.path.basename(d)}: {' / '.join(notes)}")
            n += 1
    print(f"完成，检查 {n} 个插件")
    return 0


if __name__ == "__main__":
    sys.exit(main())
