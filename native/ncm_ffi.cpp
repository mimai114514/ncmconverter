/**
 * NCM 解密库 FFI 接口实现
 */

#include "ncm_ffi.h"
#include "ncmlib/ncmdump.h"
#include <cstring>
#include <string>

#define NCM_LIB_VERSION "1.0.0"

extern "C" {

int ncm_decode_file(const char* input_path, const char* output_dir)
{
    if (input_path == nullptr || output_dir == nullptr) {
        return -1;
    }
    
    std::string outputPath;
    return ncm::ncmDump(input_path, output_dir, outputPath);
}

int ncm_decode_file_with_output(
    const char* input_path, 
    const char* output_dir,
    char* output_path_buffer,
    int buffer_size)
{
    if (input_path == nullptr || output_dir == nullptr) {
        return -1;
    }
    
    std::string outputPath;
    int result = ncm::ncmDump(input_path, output_dir, outputPath);
    
    if (result == 0 && output_path_buffer != nullptr && buffer_size > 0) {
        // 复制输出路径到缓冲区
        size_t copyLen = outputPath.length();
        if (copyLen >= (size_t)buffer_size) {
            copyLen = buffer_size - 1;
        }
        memcpy(output_path_buffer, outputPath.c_str(), copyLen);
        output_path_buffer[copyLen] = '\0';
    }
    
    return result;
}

const char* ncm_get_last_error()
{
    return ncm::getLastError();
}

const char* ncm_get_version()
{
    return NCM_LIB_VERSION;
}

} // extern "C"
