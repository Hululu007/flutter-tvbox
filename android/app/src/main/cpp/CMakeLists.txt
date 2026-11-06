cmake_minimum_required(VERSION 3.18)
project(nodewrap CXX)

set(CMAKE_CXX_STANDARD 17)

# libnode 由 tools/fetch_libnode.sh 预置到 cpp/libnode/
#   bin/<abi>/libnode.so   预编译共享库
#   include/node/          node.h / v8.h 等头文件
#
# 注意：AGP 会为 flutter 插件声明的每个 ABI 各跑一次 configure。
# 即便 build 时指定了 --target-platform android-arm64，armeabi-v7a
# 那趟也会进来。所以缺某个 ABI 时只能跳过，不能 FATAL_ERROR，
# 否则整个构建直接挂掉。
set(LIBNODE_DIR ${CMAKE_SOURCE_DIR}/libnode)
set(LIBNODE_SO ${LIBNODE_DIR}/bin/${ANDROID_ABI}/libnode.so)

if(NOT EXISTS ${LIBNODE_SO})
    message(WARNING "跳过 ABI=${ANDROID_ABI}：没有 ${LIBNODE_SO}，先跑 ./tools/fetch_libnode.sh")
    return()
endif()

add_library(libnode SHARED IMPORTED)
set_target_properties(libnode PROPERTIES IMPORTED_LOCATION ${LIBNODE_SO})

add_library(nodewrap SHARED node_bridge.cpp)

target_include_directories(nodewrap PRIVATE ${LIBNODE_DIR}/include/node)

# STL 由 AGP 的 -DANDROID_STL=c++_shared 统一指定（libnode 就是用它编的），
# 这里不要再把 c++_shared 当普通库链，会跟 AGP 注入的重复
target_link_libraries(nodewrap
    libnode
    android
    log)
