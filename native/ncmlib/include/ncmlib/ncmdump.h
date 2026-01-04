#pragma once

#include <string>

namespace ncm
{
    /**
     * 解密 NCM 文件
     * @param inputPath 输入 NCM 文件路径
     * @param outputDir 输出目录
     * @param outputPath 输出参数，解密后的文件完整路径
     * @return 0 表示成功，负数表示错误码
     *         -1: 无法打开输入文件
     *         -2: 文件太小
     *         -3: 无效的 NCM 格式
     *         -4: AES 密钥设置失败
     *         -5: 元数据解析失败
     *         -6: 无法创建输出文件
     *         -100: 未知异常
     */
    int ncmDump(const std::string& inputPath, const std::string& outputDir, std::string& outputPath);
    
    /**
     * 获取最后一次错误信息
     */
    const char* getLastError();
    
    /**
     * 清除错误信息
     */
    void clearError();
}
