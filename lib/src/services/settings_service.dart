/// 设置服务
/// 提供应用设置的持久化存储和读取

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/ncm_performance_defaults.dart';

/// 设置服务单例
class SettingsService {
  static final SettingsService _instance = SettingsService._();
  static SettingsService get instance => _instance;

  SettingsService._();

  SharedPreferences? _prefs;

  /// 设置键名
  static const String _keyThreadCount = 'thread_count';
  static const String _keyBufferSize = 'buffer_size';
  static const String _keyFlushInterval = 'flush_interval';
  static const String _keyLastInputDirectory = 'windows_last_input_directory';
  static const String _keyLastOutputDirectory = 'windows_last_output_directory';

  /// 最大允许线程数
  static const int maxThreadCount = 32;

  /// 缓冲区大小范围（64KB - 1MB）
  static const int minBufferSize = 64 * 1024; // 64KB
  static const int maxBufferSize = 1024 * 1024; // 1MB
  static const int defaultBufferSize = NcmPerformanceDefaults.bufferSize;

  /// 每个写入批次包含的缓冲区块数范围
  static const int minFlushInterval = 1;
  static const int maxFlushInterval = 32;
  static const int defaultFlushInterval = NcmPerformanceDefaults.flushInterval;

  static int get defaultThreadCount {
    final cpuCount = Platform.numberOfProcessors;
    return cpuCount.clamp(1, NcmPerformanceDefaults.concurrencyLimit);
  }

  /// 初始化设置服务
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    debugPrint('[设置服务] 初始化完成');
  }

  /// 获取线程数设置
  int get threadCount {
    return _prefs?.getInt(_keyThreadCount) ?? defaultThreadCount;
  }

  /// 设置线程数
  Future<void> setThreadCount(int count) async {
    final clampedCount = count.clamp(1, maxThreadCount);
    await _prefs?.setInt(_keyThreadCount, clampedCount);
    debugPrint('[设置服务] 线程数已设置为: $clampedCount');
  }

  /// 获取缓冲区大小（字节）
  int get bufferSize {
    return _prefs?.getInt(_keyBufferSize) ?? defaultBufferSize;
  }

  /// 设置缓冲区大小
  Future<void> setBufferSize(int size) async {
    final clampedSize = size.clamp(minBufferSize, maxBufferSize);
    await _prefs?.setInt(_keyBufferSize, clampedSize);
    debugPrint('[设置服务] 缓冲区大小已设置为: ${clampedSize ~/ 1024}KB');
  }

  /// 获取每个写入批次的块数
  int get flushInterval {
    return _prefs?.getInt(_keyFlushInterval) ?? defaultFlushInterval;
  }

  /// 设置每个写入批次的块数
  Future<void> setFlushInterval(int interval) async {
    final clampedInterval = interval.clamp(minFlushInterval, maxFlushInterval);
    await _prefs?.setInt(_keyFlushInterval, clampedInterval);
    debugPrint('[设置服务] 写入批次已设置为: 每批 $clampedInterval 块');
  }

  /// 获取 Windows 最近使用的输入目录
  String? get lastInputDirectory {
    return _prefs?.getString(_keyLastInputDirectory);
  }

  /// 记录 Windows 最近使用的输入目录
  Future<void> setLastInputDirectory(String path) async {
    await _prefs?.setString(_keyLastInputDirectory, path);
    debugPrint('[设置服务] 已记录 Windows 输入目录: $path');
  }

  /// 获取 Windows 最近使用的输出目录
  String? get lastOutputDirectory {
    return _prefs?.getString(_keyLastOutputDirectory);
  }

  /// 记录 Windows 最近使用的输出目录
  Future<void> setLastOutputDirectory(String path) async {
    await _prefs?.setString(_keyLastOutputDirectory, path);
    debugPrint('[设置服务] 已记录 Windows 输出目录: $path');
  }

  /// 获取格式化的缓冲区大小显示文本
  String get bufferSizeText {
    final sizeKB = bufferSize ~/ 1024;
    if (sizeKB >= 1024) {
      return '${sizeKB ~/ 1024}MB';
    }
    return '${sizeKB}KB';
  }
}
