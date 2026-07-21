/// 设置页面

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _threadCount;
  late int _bufferSizeKB; // 以 KB 为单位
  late int _flushInterval;
  late bool _windowsMusicTagEnabled;
  String? _windowsMusicTagExecutablePath;

  @override
  void initState() {
    super.initState();
    _threadCount = SettingsService.instance.threadCount;
    _bufferSizeKB = SettingsService.instance.bufferSize ~/ 1024;
    _flushInterval = SettingsService.instance.flushInterval;
    _windowsMusicTagEnabled = SettingsService.instance.windowsMusicTagEnabled;
    _windowsMusicTagExecutablePath =
        SettingsService.instance.windowsMusicTagExecutablePath;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          // 性能设置
          const _SectionHeader(title: '性能'),
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('解密线程数'),
            subtitle: Text('当前: $_threadCount 线程'),
            trailing: SizedBox(
              width: 200,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _threadCount > 1
                        ? () => _updateThreadCount(_threadCount - 1)
                        : null,
                  ),
                  Expanded(
                    child: Slider(
                      value: _threadCount.toDouble(),
                      min: 1,
                      max: 32,
                      divisions: 31,
                      label: '$_threadCount',
                      onChanged: (value) => _updateThreadCount(value.round()),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _threadCount < 32
                        ? () => _updateThreadCount(_threadCount + 1)
                        : null,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '更多线程可以加快批量解密速度，但会占用更多系统资源。'
              '默认根据平台与 CPU 核心数选择（当前默认: ${SettingsService.defaultThreadCount}）',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
            ),
          ),
          const SizedBox(height: 16),

          // I/O 设置
          const _SectionHeader(title: 'I/O'),
          ListTile(
            leading: const Icon(Icons.memory),
            title: const Text('缓冲区大小'),
            subtitle: Text('当前: ${_formatBufferSize(_bufferSizeKB)}'),
            trailing: SizedBox(
              width: 200,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _bufferSizeKB > 64
                        ? () => _updateBufferSize(
                            _getPrevBufferSize(_bufferSizeKB),
                          )
                        : null,
                  ),
                  Expanded(
                    child: Slider(
                      value: _bufferSizeToSlider(_bufferSizeKB),
                      min: 0,
                      max: 4,
                      divisions: 4,
                      label: _formatBufferSize(_bufferSizeKB),
                      onChanged: (value) =>
                          _updateBufferSize(_sliderToBufferSize(value.round())),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _bufferSizeKB < 1024
                        ? () => _updateBufferSize(
                            _getNextBufferSize(_bufferSizeKB),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '较大的缓冲区可以减少 I/O 次数，提高解密速度，但会占用更多内存。'
              '低内存设备建议使用 64KB-128KB，高性能设备可使用 512KB-1MB。',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('写入批次'),
            subtitle: Text('每批 $_flushInterval 块'),
            trailing: SizedBox(
              width: 200,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _flushInterval > 1
                        ? () => _updateFlushInterval(_flushInterval - 1)
                        : null,
                  ),
                  Expanded(
                    child: Slider(
                      value: _flushInterval.toDouble(),
                      min: 1,
                      max: 32,
                      divisions: 31,
                      label: '$_flushInterval',
                      onChanged: (value) => _updateFlushInterval(value.round()),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _flushInterval < 32
                        ? () => _updateFlushInterval(_flushInterval + 1)
                        : null,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '控制每次流式写入包含的缓冲块数量。默认 4 块，'
              '更大的批次可以减少流切换次数。',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
            ),
          ),
          const SizedBox(height: 16),

          if (Platform.isWindows) ...[
            const _SectionHeader(title: '音乐标签'),
            SwitchListTile(
              secondary: const Icon(Icons.music_note),
              title: const Text('转换完成后打开音乐标签'),
              subtitle: const Text('在完成弹窗中显示“打开音乐标签”操作'),
              value: _windowsMusicTagEnabled,
              onChanged: _updateWindowsMusicTagEnabled,
            ),
            ListTile(
              enabled: _windowsMusicTagEnabled,
              leading: const Icon(Icons.app_registration),
              title: const Text('音乐标签程序'),
              subtitle: Text(
                _windowsMusicTagExecutablePath ?? '启用后选择音乐标签的 .exe 文件',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_windowsMusicTagExecutablePath != null)
                    IconButton(
                      tooltip: '清除程序路径',
                      icon: const Icon(Icons.clear),
                      onPressed: _windowsMusicTagEnabled
                          ? _clearWindowsMusicTagExecutablePath
                          : null,
                    ),
                  IconButton(
                    tooltip: '选择程序路径',
                    icon: const Icon(Icons.folder_open),
                    onPressed: _windowsMusicTagEnabled
                        ? _selectWindowsMusicTagExecutable
                        : null,
                  ),
                ],
              ),
              onTap: _windowsMusicTagEnabled
                  ? _selectWindowsMusicTagExecutable
                  : null,
            ),
            const SizedBox(height: 16),
          ],

          // 关于部分
          const _SectionHeader(title: '关于'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于本应用'),
            subtitle: const Text('查看版本信息和版权声明'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }

  void _updateThreadCount(int count) {
    final clampedCount = count.clamp(1, SettingsService.maxThreadCount);
    setState(() {
      _threadCount = clampedCount;
    });
    SettingsService.instance.setThreadCount(clampedCount);
  }

  void _updateBufferSize(int sizeKB) {
    final clampedSize = sizeKB.clamp(64, 1024);
    setState(() {
      _bufferSizeKB = clampedSize;
    });
    SettingsService.instance.setBufferSize(clampedSize * 1024);
  }

  void _updateFlushInterval(int interval) {
    final clampedInterval = interval.clamp(1, 32);
    setState(() {
      _flushInterval = clampedInterval;
    });
    SettingsService.instance.setFlushInterval(clampedInterval);
  }

  void _updateWindowsMusicTagEnabled(bool enabled) {
    setState(() {
      _windowsMusicTagEnabled = enabled;
    });
    SettingsService.instance.setWindowsMusicTagEnabled(enabled);
  }

  Future<void> _selectWindowsMusicTagExecutable() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择音乐标签程序',
      type: FileType.custom,
      allowedExtensions: const ['exe'],
    );
    final path = result?.files.single.path;
    if (path == null) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _windowsMusicTagExecutablePath = path;
    });
    await SettingsService.instance.setWindowsMusicTagExecutablePath(path);
  }

  Future<void> _clearWindowsMusicTagExecutablePath() async {
    setState(() {
      _windowsMusicTagExecutablePath = null;
    });
    await SettingsService.instance.clearWindowsMusicTagExecutablePath();
  }

  /// 格式化缓冲区大小显示
  String _formatBufferSize(int sizeKB) {
    if (sizeKB >= 1024) {
      return '${sizeKB ~/ 1024}MB';
    }
    return '${sizeKB}KB';
  }

  /// 缓冲区大小转换为滑块值（使用预设档位：64, 128, 256, 512, 1024）
  double _bufferSizeToSlider(int sizeKB) {
    if (sizeKB <= 64) return 0;
    if (sizeKB <= 128) return 1;
    if (sizeKB <= 256) return 2;
    if (sizeKB <= 512) return 3;
    return 4;
  }

  /// 滑块值转换为缓冲区大小
  int _sliderToBufferSize(int sliderValue) {
    const sizes = [64, 128, 256, 512, 1024];
    return sizes[sliderValue.clamp(0, 4)];
  }

  /// 获取下一个档位的缓冲区大小
  int _getNextBufferSize(int currentKB) {
    const sizes = [64, 128, 256, 512, 1024];
    for (final size in sizes) {
      if (size > currentKB) return size;
    }
    return 1024;
  }

  /// 获取上一个档位的缓冲区大小
  int _getPrevBufferSize(int currentKB) {
    const sizes = [64, 128, 256, 512, 1024];
    for (var i = sizes.length - 1; i >= 0; i--) {
      if (sizes[i] < currentKB) return sizes[i];
    }
    return 64;
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            // 应用图标
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/icon-ncmconverter-v1.png',
                width: 80,
                height: 80,
              ),
            ),
            const SizedBox(height: 16),
            // 应用名
            const Text(
              'NCM Converter',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            // 应用包名
            Text(
              'io.github.mimai114514.ncmconverter',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            // 版本信息
            Text(
              'v1.0.0',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            //开发者信息
            Text('Developed by Infinity.', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            // Github 链接
            InkWell(
              onTap: () async {
                final url = Uri.parse(
                  'https://github.com/mimai114514/ncmconverter',
                );
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.code,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '在 GitHub 上查看',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }
}

/// 设置页面的分区标题组件
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
