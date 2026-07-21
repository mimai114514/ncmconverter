import 'dart:io';

/// NCM 解密的跨平台保守默认值。
abstract final class NcmPerformanceDefaults {
  static const int windowsConcurrencyLimit = 16;
  static const int otherPlatformConcurrencyLimit = 8;
  static const int bufferSize = 512 * 1024;
  static const int flushInterval = 4;

  static int get concurrencyLimit => Platform.isWindows
      ? windowsConcurrencyLimit
      : otherPlatformConcurrencyLimit;
}
