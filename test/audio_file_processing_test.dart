import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ncmpp_flutter/src/services/ncm_decoder.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ncm-audio-test-');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('关闭功能时仅扫描当前目录的 NCM 文件', () async {
    final cloudMusic = await Directory(
      '${tempDir.path}${Platform.pathSeparator}CloudMusic',
    ).create();
    await File(
      '${cloudMusic.path}${Platform.pathSeparator}song.ncm',
    ).writeAsBytes([1]);
    await File(
      '${cloudMusic.path}${Platform.pathSeparator}song.mp3',
    ).writeAsBytes([2]);

    final files = await NcmDecoder.instance.scanFiles(cloudMusic.path);

    expect(files, hasLength(1));
    expect(files.single.toLowerCase(), endsWith('song.ncm'));
  });

  test('CloudMusic 会同时扫描 VipSongsDownload 中的音频文件', () async {
    final cloudMusic = await Directory(
      '${tempDir.path}${Platform.pathSeparator}CloudMusic',
    ).create();
    final vipSongs = await Directory(
      '${cloudMusic.path}${Platform.pathSeparator}VipSongsDownload',
    ).create();
    await File(
      '${cloudMusic.path}${Platform.pathSeparator}root.ncm',
    ).writeAsBytes([1]);
    await File(
      '${cloudMusic.path}${Platform.pathSeparator}root.mp3',
    ).writeAsBytes([2]);
    await File(
      '${vipSongs.path}${Platform.pathSeparator}vip.FLAC',
    ).writeAsBytes([3]);

    final files = await NcmDecoder.instance.scanFiles(
      cloudMusic.path,
      includeUnencryptedAudio: true,
    );

    expect(files, hasLength(3));
    expect(
      files.any((path) => path.toLowerCase().endsWith('root.ncm')),
      isTrue,
    );
    expect(
      files.any((path) => path.toLowerCase().endsWith('root.mp3')),
      isTrue,
    );
    expect(
      files.any((path) => path.toLowerCase().endsWith('vip.flac')),
      isTrue,
    );
  });

  test('VipSongsDownload 会同时扫描父目录的文件', () async {
    final vipSongs = await Directory(
      '${tempDir.path}${Platform.pathSeparator}VipSongsDownload',
    ).create();
    await File(
      '${tempDir.path}${Platform.pathSeparator}parent.mp3',
    ).writeAsBytes([1]);
    await File(
      '${vipSongs.path}${Platform.pathSeparator}vip.ncm',
    ).writeAsBytes([2]);

    final files = await NcmDecoder.instance.scanFiles(
      vipSongs.path,
      includeUnencryptedAudio: true,
    );

    expect(files, hasLength(2));
    expect(
      files.any((path) => path.toLowerCase().endsWith('parent.mp3')),
      isTrue,
    );
    expect(files.any((path) => path.toLowerCase().endsWith('vip.ncm')), isTrue);
  });

  test('普通音频文件会原样复制并报告处理成功', () async {
    final input = File('${tempDir.path}${Platform.pathSeparator}input.mp3');
    final output = await Directory(
      '${tempDir.path}${Platform.pathSeparator}output',
    ).create();
    const bytes = [1, 3, 5, 7, 9];
    await input.writeAsBytes(bytes);
    DecodeResult? result;

    final progress = await NcmDecoder.instance
        .processFiles(
          inputFiles: [input.path],
          outputDir: output.path,
          onFileComplete: (value) => result = value,
        )
        .toList();

    expect(result?.success, isTrue);
    expect(progress.last.completed, 1);
    expect(progress.last.failed, 0);
    final copied = File('${output.path}${Platform.pathSeparator}input.mp3');
    expect(await copied.readAsBytes(), bytes);
  });
}
