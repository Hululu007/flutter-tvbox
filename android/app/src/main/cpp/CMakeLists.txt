cmake_minimum_required(VERSION 3.18)
project(nodewrap CXX)

set(CMAKE_CXX_STANDARD 17)

# libnode 由 tools/fetch_libnode.sh 预置到 cpp/libnode/
#   bin/<abi>/libnode.so   预编译共享库
#   include/node/          node.h / v8.h 等头文件
set(LIBNODE_DIR ${CMAKE_SOURCE_DIR}/libnode)

if(NOT EXISTS ${LIBNODE_DIR}/bin/${ANDROID_ABI}/libnode.so)
    message(FATAL_ERROR
        "找不到 libnode: ${LIBNODE_DIR}/bin/${ANDROID_ABI}/libnode.so\n"
        "先执行 ./tools/fetch_libnode.sh")
endif()

add_library(libnode SHARED IMPORTED)
set_target_properties(libnode PROPERTIES
    IMPORTED_LOCATION ${LIBNODE_DIR}/bin/${ANDROID_ABI}/libnode.so)

add_library(nodewrap SHARED node_bridge.cpp)

target_include_directories(nodewrap PRIVATE ${LIBNODE_DIR}/include/node)

# libnode 是 c++_shared 编的，STL 由 AGP 的 -DANDROID_STL=c++_shared 统一指定，
# 这里不要再把 c++_shared 当普通库链接，会跟 AGP 注入的重复
target_link_libraries(nodewrap
    libnode
    android
    log)
