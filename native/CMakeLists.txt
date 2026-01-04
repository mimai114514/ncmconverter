# NCM 解密库 Android NDK 构建配置
cmake_minimum_required(VERSION 3.18)
project(ncmlib_android)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 设置 OpenSSL 路径
# 预编译的 OpenSSL 库路径（需要根据实际情况修改）
set(OPENSSL_ROOT_DIR ${CMAKE_SOURCE_DIR}/../openssl-android/${ANDROID_ABI})
set(OPENSSL_INCLUDE_DIR ${OPENSSL_ROOT_DIR}/include)
set(OPENSSL_CRYPTO_LIBRARY ${OPENSSL_ROOT_DIR}/lib/libcrypto.a)

# 检查 OpenSSL 是否存在
if(NOT EXISTS ${OPENSSL_INCLUDE_DIR})
    message(FATAL_ERROR "OpenSSL include directory not found: ${OPENSSL_INCLUDE_DIR}")
endif()

if(NOT EXISTS ${OPENSSL_CRYPTO_LIBRARY})
    message(FATAL_ERROR "OpenSSL crypto library not found: ${OPENSSL_CRYPTO_LIBRARY}")
endif()

# 源文件列表
set(NCMLIB_SOURCES
    ncmlib/src/ncmdump.cpp
    ncmlib/src/base64.cpp
    ncmlib/src/pkcs7.cpp
    ncm_ffi.cpp
)

# 头文件目录
include_directories(
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/ncmlib/include
    ${CMAKE_SOURCE_DIR}/ncmlib/src
    ${OPENSSL_INCLUDE_DIR}
)

# 创建共享库
add_library(ncmlib SHARED ${NCMLIB_SOURCES})

# 设置符号可见性
set_target_properties(ncmlib PROPERTIES
    CXX_VISIBILITY_PRESET hidden
    C_VISIBILITY_PRESET hidden
)

# 链接库
target_link_libraries(ncmlib
    ${OPENSSL_CRYPTO_LIBRARY}
    log  # Android 日志库
)

# 输出库信息
message(STATUS "Building ncmlib for ABI: ${ANDROID_ABI}")
message(STATUS "OpenSSL include: ${OPENSSL_INCLUDE_DIR}")
message(STATUS "OpenSSL crypto: ${OPENSSL_CRYPTO_LIBRARY}")
