/// NCM 文件模型

class NcmFile {
  final String path;
  final String name;
  NcmFileStatus status;
  String? outputPath;
  String? errorMessage;

  NcmFile({
    required this.path,
    required this.name,
    this.status = NcmFileStatus.pending,
    this.outputPath,
    this.errorMessage,
  });

  /// 从文件路径创建
  factory NcmFile.fromPath(String path) {
    final parts = path.split(RegExp(r'[/\\]'));
    final name = parts.isNotEmpty ? parts.last : path;
    return NcmFile(path: path, name: name);
  }
}

/// NCM 文件状态
enum NcmFileStatus {
  pending, // 等待处理
  processing, // 正在处理
  success, // 处理成功
  failed, // 处理失败
}
