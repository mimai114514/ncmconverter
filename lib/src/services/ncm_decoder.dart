/// NCM 解密器服务
/// 提供高层封装，支持 Isolate 池后台解密

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../core/ncm_dump.dart';
import '../core/ncm_performance_defaults.dart';
import 'isolate_pool.dart';
import 'settings_service.dart';

/// 解密结果
class DecodeResult {
  final String inputPath;
  final String outputPath;
  final bool success;
  final String? errorMessage;

  DecodeResult({
    required this.inputPath,
    required this.outputPath,
    required this.success,
    this.errorMessage,
  });

  /// 从 DecodeTaskResult 转换
  factory DecodeResult.fromTaskResult(DecodeTaskResult result) {
    return DecodeResult(
      inputPath: result.inputPath,
      outputPath: result.outputPath,
      success: result.success,
      errorMessage: result.errorMessage,
    );
  }

  @override
  String toString() {
    if (success) {
      return 'DecodeResult(success: $inputPath -> $outputPath)';
    } else {
      return 'DecodeResult(failed: $inputPath, error: $errorMessage)';
    }
  }
}

/// 批量解密进度
class BatchDecodeProgress {
  final int total;
  final int completed;
  final int failed;
  final String? currentFile;
  final String? currentFilePath;

  BatchDecodeProgress({
    required this.total,
    required this.completed,
    required this.failed,
    this.currentFile,
    this.currentFilePath,
  });

  double get progress => total > 0 ? (completed + failed) / total : 0;
  bool get isComplete => completed + failed >= total;
}

/// NCM 解密器
class NcmDecoder {
  static final NcmDecoder _instance = NcmDecoder._();
  static NcmDecoder get instance => _instance;

  IsolatePool? _pool;
  bool _usePool = true; // 是否使用 Isolate 池

  NcmDecoder._();

  /// 预热 Isolate 池
  /// 建议在应用空闲时调用，避免阻塞启动关键路径
  Future<void> warmUp([int? count]) async {
    if (!_usePool) return;

    _pool ??= IsolatePool(maxSize: 32);
    await _pool!.warmUp(count);
  }

  /// 销毁 Isolate 池
  Future<void> dispose() async {
    await _pool?.dispose();
    _pool = null;
  }

  /// 解密单个文件（在后台 Isolate 执行）
  /// [useStreaming] 是否使用流式解密，默认 true（减少内存占用）
  /// [bufferSize] 缓冲区大小（字节），默认从设置读取
  /// [flushInterval] 每个写入批次的块数，默认从设置读取
  Future<DecodeResult> decodeFile(
    String inputPath,
    String outputDir, {
    bool useStreaming = true,
    int? bufferSize,
    int? flushInterval,
  }) async {
    // 从设置服务读取默认值
    final effectiveBufferSize = bufferSize ?? NcmPerformanceDefaults.bufferSize;
    final effectiveFlushInterval =
        flushInterval ?? NcmPerformanceDefaults.flushInterval;

    if (_usePool) {
      // 使用 Isolate 池
      _pool ??= IsolatePool(maxSize: 32);
      final result = await _pool!.runDecode(
        DecodeTask(
          inputPath,
          outputDir,
          useStreaming: useStreaming,
          bufferSize: effectiveBufferSize,
          flushInterval: effectiveFlushInterval,
        ),
      );
      return DecodeResult.fromTaskResult(result);
    } else {
      // 回退到 compute
      final result = await compute(_decodeInIsolate, [
        inputPath,
        outputDir,
        useStreaming.toString(),
        effectiveBufferSize.toString(),
        effectiveFlushInterval.toString(),
      ]);
      return result;
    }
  }

  /// 扫描目录中的待处理文件
  ///
  /// 开启 [includeUnencryptedAudio] 后，同时扫描 MP3/FLAC。电脑端会识别
  /// 网易云音乐的 CloudMusic 和 VipSongsDownload 目录结构。
  Future<List<String>> scanFiles(
    String directoryPath, {
    bool includeUnencryptedAudio = false,
  }) async {
    final directories = <Directory>[Directory(directoryPath)];
    if (includeUnencryptedAudio && !Platform.isAndroid) {
      final selected = Directory(directoryPath);
      final directoryName = _pathName(selected.path).toLowerCase();
      if (directoryName == 'vipsongsdownload') {
        directories.add(selected.parent);
      } else if (directoryName == 'cloudmusic') {
        directories.add(
          Directory(
            '${selected.path}${Platform.pathSeparator}VipSongsDownload',
          ),
        );
      }
    }

    final files = <String>[];
    final seenPaths = <String>{};
    for (final directory in directories) {
      final scanned = await _scanDirectory(
        directory,
        includeUnencryptedAudio: includeUnencryptedAudio,
      );
      for (final path in scanned) {
        final comparisonPath = Platform.isWindows ? path.toLowerCase() : path;
        if (seenPaths.add(comparisonPath)) {
          files.add(path);
        }
      }
    }

    files.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    debugPrint('[文件扫描] 总共找到 ${files.length} 个待处理文件');
    return files;
  }

  /// 扫描目录中的所有 NCM 文件，保留原有接口和行为。
  Future<List<String>> scanNcmFiles(String directoryPath) {
    return scanFiles(directoryPath);
  }

  Future<List<String>> _scanDirectory(
    Directory dir, {
    required bool includeUnencryptedAudio,
  }) async {
    final directoryPath = dir.path;

    // 检查目录是否存在
    bool exists;
    try {
      exists = await dir.exists();
      debugPrint('[NCM扫描] 目录存在检查: $directoryPath -> $exists');
    } catch (e) {
      debugPrint('[NCM扫描] 检查目录存在时出错: $e');
      return [];
    }

    if (!exists) {
      debugPrint('[NCM扫描] 目录不存在: $directoryPath');
      return [];
    }

    final files = <String>[];
    try {
      // 使用 listSync 同步列出文件，在某些情况下更稳定
      final entities = dir.listSync(recursive: false);
      debugPrint('[NCM扫描] 找到 ${entities.length} 个文件/文件夹');

      for (final entity in entities) {
        debugPrint('[NCM扫描] 检查: ${entity.path}');
        if (entity is File) {
          final path = entity.path.toLowerCase();
          if (_isSupportedFile(path, includeUnencryptedAudio)) {
            files.add(entity.path);
            debugPrint('[文件扫描] 添加文件: ${entity.path}');
          }
        }
      }
    } catch (e) {
      debugPrint('[NCM扫描] 列出目录内容时出错: $e');

      // 尝试使用异步方法作为备选
      try {
        await for (final entity in dir.list(recursive: false)) {
          if (entity is File) {
            final path = entity.path.toLowerCase();
            if (_isSupportedFile(path, includeUnencryptedAudio)) {
              files.add(entity.path);
            }
          }
        }
      } catch (e2) {
        debugPrint('[NCM扫描] 异步列出也失败: $e2');
      }
    }

    return files;
  }

  bool _isSupportedFile(String lowerCasePath, bool includeUnencryptedAudio) {
    return lowerCasePath.endsWith('.ncm') ||
        (includeUnencryptedAudio &&
            (lowerCasePath.endsWith('.mp3') ||
                lowerCasePath.endsWith('.flac')));
  }

  String _pathName(String path) {
    final normalized = path.replaceAll(RegExp(r'[/\\]+$'), '');
    final parts = normalized.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? normalized : parts.last;
  }

  /// 批量解密目录中的所有 NCM 文件
  /// 返回一个 Stream，可以监听进度和结果
  /// [concurrency] 参数指定并行解密的数量，默认为1（顺序执行）
  /// [bufferSize] 缓冲区大小（字节），默认从设置读取
  /// [flushInterval] 每个写入批次的块数，默认从设置读取
  Stream<BatchDecodeProgress> decodeDirectory({
    required String inputDir,
    required String outputDir,
    int concurrency = 1,
    int? bufferSize,
    int? flushInterval,
    void Function(DecodeResult)? onFileComplete,
  }) async* {
    // 扫描所有 NCM 文件
    final files = await scanNcmFiles(inputDir);
    yield* processFiles(
      inputFiles: files,
      outputDir: outputDir,
      concurrency: concurrency,
      bufferSize: bufferSize,
      flushInterval: flushInterval,
      onFileComplete: onFileComplete,
    );
  }

  /// 处理指定文件列表：NCM 文件解密，MP3/FLAC 文件原样复制。
  Stream<BatchDecodeProgress> processFiles({
    required List<String> inputFiles,
    required String outputDir,
    int concurrency = 1,
    int? bufferSize,
    int? flushInterval,
    void Function(DecodeResult)? onFileComplete,
  }) async* {
    final files = List<String>.from(inputFiles);
    final total = files.length;
    var completed = 0;
    var failed = 0;

    if (total == 0) {
      yield BatchDecodeProgress(total: 0, completed: 0, failed: 0);
      return;
    }

    // 确保输出目录存在
    final outDir = Directory(outputDir);
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    // 限制并发数在合理范围内
    final effectiveConcurrency = concurrency.clamp(1, math.min(total, 32));
    debugPrint('[解密服务] 使用 $effectiveConcurrency 个并行任务');

    // 从设置服务读取缓冲区参数
    final effectiveBufferSize =
        bufferSize ?? SettingsService.instance.bufferSize;
    final effectiveFlushInterval =
        flushInterval ?? SettingsService.instance.flushInterval;
    debugPrint(
      '[解密服务] 缓冲区: ${effectiveBufferSize ~/ 1024}KB, 写入批次: 每批 $effectiveFlushInterval 块',
    );

    // 使用 StreamController 来汇报进度
    final progressController = StreamController<BatchDecodeProgress>();

    // 当前正在处理的文件名
    String? currentFileName;

    // 并行处理逻辑
    () async {
      // 创建任务队列
      final futures = <Future<void>>[];
      var fileIndex = 0;

      // 处理单个文件的函数
      Future<void> processOne() async {
        while (fileIndex < files.length) {
          final idx = fileIndex++;
          final filePath = files[idx];
          final fileName = filePath.split(Platform.pathSeparator).last;

          currentFileName = fileName;
          progressController.add(
            BatchDecodeProgress(
              total: total,
              completed: completed,
              failed: failed,
              currentFile: currentFileName,
              currentFilePath: filePath,
            ),
          );

          try {
            final result = _isUnencryptedAudio(filePath)
                ? await _copyAudioFile(filePath, outputDir)
                : await decodeFile(
                    filePath,
                    outputDir,
                    bufferSize: effectiveBufferSize,
                    flushInterval: effectiveFlushInterval,
                  );
            if (result.success) {
              completed++;
            } else {
              failed++;
            }
            onFileComplete?.call(result);
          } catch (e) {
            failed++;
            onFileComplete?.call(
              DecodeResult(
                inputPath: filePath,
                outputPath: '',
                success: false,
                errorMessage: e.toString(),
              ),
            );
          }
        }
      }

      // 启动并发worker
      for (var i = 0; i < effectiveConcurrency; i++) {
        futures.add(processOne());
      }

      // 等待所有worker完成
      await Future.wait(futures);

      // 发送最终进度
      progressController.add(
        BatchDecodeProgress(total: total, completed: completed, failed: failed),
      );

      await progressController.close();
    }();

    // 转发进度事件
    await for (final progress in progressController.stream) {
      yield progress;
    }
  }

  bool _isUnencryptedAudio(String path) {
    final lowerCasePath = path.toLowerCase();
    return lowerCasePath.endsWith('.mp3') || lowerCasePath.endsWith('.flac');
  }

  Future<DecodeResult> _copyAudioFile(
    String inputPath,
    String outputDir,
  ) async {
    final outputPath =
        '$outputDir${Platform.pathSeparator}${_pathName(inputPath)}';
    try {
      final sourcePath = File(inputPath).absolute.path;
      final destinationPath = File(outputPath).absolute.path;
      final isSamePath = Platform.isWindows
          ? sourcePath.toLowerCase() == destinationPath.toLowerCase()
          : sourcePath == destinationPath;
      if (!isSamePath) {
        await File(inputPath).copy(outputPath);
      }
      return DecodeResult(
        inputPath: inputPath,
        outputPath: outputPath,
        success: true,
      );
    } catch (e) {
      return DecodeResult(
        inputPath: inputPath,
        outputPath: outputPath,
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// 获取版本
  String getVersion() => '1.1.0';
}

/// Isolate 中执行的解密函数（用于回退模式）
Future<DecodeResult> _decodeInIsolate(List<String> args) async {
  final inputPath = args[0];
  final outputDir = args[1];
  final useStreaming = args.length > 2 ? args[2] == 'true' : true;
  final bufferSize = args.length > 3
      ? int.tryParse(args[3]) ?? NcmPerformanceDefaults.bufferSize
      : NcmPerformanceDefaults.bufferSize;
  final flushInterval = args.length > 4
      ? int.tryParse(args[4]) ?? NcmPerformanceDefaults.flushInterval
      : NcmPerformanceDefaults.flushInterval;

  final ncmDump = NcmDump();
  final (success, outputPath, errorMessage) = useStreaming
      ? await ncmDump.decodeStreaming(
          inputPath,
          outputDir,
          bufferSize: bufferSize,
          flushInterval: flushInterval,
        )
      : await ncmDump.decode(inputPath, outputDir);

  return DecodeResult(
    inputPath: inputPath,
    outputPath: outputPath,
    success: success,
    errorMessage: errorMessage,
  );
}
