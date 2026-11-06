#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
修 Flutter 插件里跟新版 Gradle/Kotlin 不兼容的写法。

当前处理：
  screen_brightness_android 2.1.5 的 android/build.gradle 顶层写了
      kotlin { compilerOptions { jvmTarget = ... } }
  这个 DSL 要求子项目自己 apply 过 kotlin-android 插件。项目根 build.gradle.kts
  是 AGP 9.0.1 + Kotlin 2.3.20，子项目没这个扩展，于是报：
      Could not find method kotlin() for arguments ... on project ':screen_brightness_android'
  删掉这个块不会丢配置——根 build.gradle.kts 的 subprojects{} 里已经用
  KotlinCompile 统一设了 jvmTarget = 17。

用法：
    python tools/patch_flutter_plugins.py            # 自动找 PUB_CACHE
    PUB_CACHE=/path python tools/patch_flutter_plugins.py
"""
import glob
import os
import re
import sys

TARGETS = ["screen_brightness_android-*"]


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
    """删掉 head 开头的 {...} 块，按大括号配对，不用正则硬啃"""
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
    # 连同前面的空行一起吃掉
    start = src.rfind("\n", 0, idx)
    start = start if start != -1 else idx
    end = i
    while end < len(src) and src[end] in "\r\n":
        end += 1
    return src[:start] + "\n" + src[end:], True


def main():
    cache = pub_cache()
    if not cache:
        print("✗ 找不到 PUB_CACHE，跳过")
        return 0

    hosted = os.path.join(cache, "hosted", "pub.dev")
    if not os.path.isdir(hosted):
        print(f"✗ {hosted} 不存在，跳过")
        return 0

    patched = 0
    for pat in TARGETS:
        for d in glob.glob(os.path.join(hosted, pat)):
            f = os.path.join(d, "android", "build.gradle")
            if not os.path.isfile(f):
                continue
            with open(f, encoding="utf-8") as fh:
                src = fh.read()
            if "\nkotlin {" not in src:
                print(f"  · {os.path.basename(d)} 无需处理")
                continue
            out, ok = drop_block(src, "\nkotlin {")
            if not ok:
                print(f"  ! {os.path.basename(d)} 括号配对失败，跳过")
                continue
            # 兜底：再扫一遍裸的 "kotlin {"
            if "\nkotlin {" in out:
                out2, ok2 = drop_block(out, "\nkotlin {")
                if ok2:
                    out = out2
            with open(f, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(out)
            print(f"  ✓ {os.path.basename(d)} 已移除顶层 kotlin{{}} 块")
            patched += 1

    print(f"完成，处理 {patched} 个插件")
    return 0


if __name__ == "__main__":
    sys.exit(main())
