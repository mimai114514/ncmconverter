/**
 * NCM 解密库 FFI 接口
 * 提供 C 风格的导出函数供 Dart FFI 调用
 */

#ifndef NCM_FFI_H
#define NCM_FFI_H

// 导出宏定义
#ifdef _WIN32
    #define NCM_EXPORT __declspec(dllexport)
#else
    #define NCM_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

/**
 * 解密单个 NCM 文件
 * @param input_path 输入文件路径 (UTF-8 编码)
 * @param output_dir 输出目录 (UTF-8 编码)
 * @return 0 表示成功，负数表示错误码
 */
NCM_EXPORT int ncm_decode_file(const char* input_path, const char* output_dir);

/**
 * 解密单个 NCM 文件并返回输出路径
 * @param input_path 输入文件路径 (UTF-8 编码)
 * @param output_dir 输出目录 (UTF-8 编码)
 * @param output_path_buffer 输出路径缓冲区
 * @param buffer_size 缓冲区大小
 * @return 0 表示成功，负数表示错误码
 */
NCM_EXPORT int ncm_decode_file_with_output(
    const char* input_path, 
    const char* output_dir,
    char* output_path_buffer,
    int buffer_size
);

/**
 * 获取最后一次错误信息
 * @return 错误信息字符串，如果没有错误则返回空字符串
 */
NCM_EXPORT const char* ncm_get_last_error();

/**
 * 获取库版本号
 * @return 版本字符串
 */
NCM_EXPORT const char* ncm_get_version();

#ifdef __cplusplus
}
#endif

#endif // NCM_FFI_H
