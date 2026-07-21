import 'package:flutter_test/flutter_test.dart';
import 'package:ncmpp_flutter/src/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Windows 输入和输出目录记忆相互独立且跨初始化保留', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService.instance;
    await settings.init();

    await settings.setLastInputDirectory(r'C:\input');
    await settings.setLastOutputDirectory(r'D:\output');

    expect(settings.lastInputDirectory, r'C:\input');
    expect(settings.lastOutputDirectory, r'D:\output');

    await settings.setLastInputDirectory(r'E:\new-input');
    expect(settings.lastInputDirectory, r'E:\new-input');
    expect(settings.lastOutputDirectory, r'D:\output');

    await settings.setLastOutputDirectory(r'F:\new-output');
    expect(settings.lastInputDirectory, r'E:\new-input');
    expect(settings.lastOutputDirectory, r'F:\new-output');

    await settings.init();
    expect(settings.lastInputDirectory, r'E:\new-input');
    expect(settings.lastOutputDirectory, r'F:\new-output');
  });

  test('Windows 音乐标签设置可独立持久化', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService.instance;
    await settings.init();

    expect(settings.windowsMusicTagEnabled, isFalse);
    expect(settings.windowsMusicTagExecutablePath, isNull);

    await settings.setWindowsMusicTagEnabled(true);
    await settings.setWindowsMusicTagExecutablePath(
      r'C:\MusicTag\MusicTag.exe',
    );

    expect(settings.windowsMusicTagEnabled, isTrue);
    expect(settings.windowsMusicTagExecutablePath, r'C:\MusicTag\MusicTag.exe');

    await settings.clearWindowsMusicTagExecutablePath();
    expect(settings.windowsMusicTagExecutablePath, isNull);
    expect(settings.windowsMusicTagEnabled, isTrue);
  });

  test('同时复制非加密音频设置默认关闭并可持久化', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService.instance;
    await settings.init();

    expect(settings.copyUnencryptedAudio, isFalse);

    await settings.setCopyUnencryptedAudio(true);
    expect(settings.copyUnencryptedAudio, isTrue);

    await settings.init();
    expect(settings.copyUnencryptedAudio, isTrue);
  });
}
