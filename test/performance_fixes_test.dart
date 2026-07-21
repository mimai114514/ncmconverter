import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ncmpp_flutter/src/core/ncm_dump.dart';
import 'package:ncmpp_flutter/src/core/ncm_performance_defaults.dart';
import 'package:ncmpp_flutter/src/services/isolate_pool.dart';
import 'package:ncmpp_flutter/src/services/settings_service.dart';
import 'package:pointycastle/pointycastle.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ncmconverter-test-');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('流式解密在复用缓冲区时保持输出完整', () async {
    final (inputFile, expectedAudio) = await _createNcmFixture(
      tempDir,
      audioSize: 128 * 1024 + 37,
    );

    final result = await NcmDump().decodeStreaming(
      inputFile.path,
      tempDir.path,
      bufferSize: 257,
      flushInterval: 3,
    );

    expect(result.$1, isTrue, reason: result.$3);
    final outputBytes = await File(result.$2).readAsBytes();
    expect(outputBytes, orderedEquals(expectedAudio));
  });

  test('并发首次提交任务不会突破 Isolate 池容量', () async {
    final pool = IsolatePool(maxSize: 2);
    try {
      final results = await Future.wait(
        List.generate(
          20,
          (index) => pool.runDecode(
            DecodeTask(
              '${tempDir.path}${Platform.pathSeparator}missing-$index.ncm',
              tempDir.path,
            ),
          ),
        ),
      );

      expect(
        results,
        everyElement(
          isA<DecodeTaskResult>().having(
            (result) => result.success,
            'success',
            isFalse,
          ),
        ),
      );
      expect(pool.size, lessThanOrEqualTo(2));
    } finally {
      await pool.dispose();
    }
  });

  test('销毁 Isolate 池会结束已经获取实例的未决任务', () async {
    final pool = IsolatePool(maxSize: 1);
    await pool.warmUp(1);

    final pending = pool.runDecode(
      DecodeTask(
        '${tempDir.path}${Platform.pathSeparator}pending.ncm',
        tempDir.path,
      ),
    );
    await pool.dispose();

    await expectLater(pending, throwsA(isA<StateError>()));
  });

  test('性能默认值使用基准测试选出的跨平台配置', () {
    final concurrencyLimit = Platform.isWindows ? 16 : 8;

    expect(NcmPerformanceDefaults.bufferSize, 512 * 1024);
    expect(NcmPerformanceDefaults.flushInterval, 4);
    expect(NcmPerformanceDefaults.concurrencyLimit, concurrencyLimit);
    expect(
      SettingsService.defaultThreadCount,
      Platform.numberOfProcessors.clamp(1, concurrencyLimit),
    );
  });
}

Future<(File, Uint8List)> _createNcmFixture(
  Directory directory, {
  required int audioSize,
}) async {
  final coreKey = _hexToBytes('687A4852416D736F356B496E62617857');
  final metaKey = _hexToBytes('2331346C6A6B5F215C5D2630553C2728');
  final audioKey = Uint8List.fromList(List.generate(32, (index) => index + 1));

  final keyPlaintext = Uint8List.fromList([
    ...utf8.encode('neteasecloudmusic'),
    ...audioKey,
  ]);
  final keyData = _aesEncrypt(_pkcs7Pad(keyPlaintext), coreKey);
  _xorInPlace(keyData, 0x64);

  final metaPlaintext = Uint8List.fromList(
    utf8.encode('music:{"format":"mp3"}'),
  );
  final encryptedMeta = _aesEncrypt(_pkcs7Pad(metaPlaintext), metaKey);
  final metaData = Uint8List.fromList([
    ...utf8.encode("163 key(Don't modify):"),
    ...utf8.encode(base64.encode(encryptedMeta)),
  ]);
  _xorInPlace(metaData, 0x63);

  final expectedAudio = Uint8List.fromList(
    List.generate(audioSize, (index) => (index * 31) & 0xff),
  );
  final encryptedAudio = Uint8List.fromList(expectedAudio);
  final box = _buildKeyBox(audioKey);
  for (var i = 0; i < encryptedAudio.length; i++) {
    final j = (i + 1) & 0xff;
    encryptedAudio[i] ^= box[(box[j] + box[(box[j] + j) & 0xff]) & 0xff];
  }

  final contents = <int>[...utf8.encode('CTENFDAM'), 0, 0];
  _addLittleEndianUint32(contents, keyData.length);
  contents.addAll(keyData);
  _addLittleEndianUint32(contents, metaData.length);
  contents.addAll(metaData);
  contents.addAll(List.filled(9, 0));
  _addLittleEndianUint32(contents, 0);
  contents.addAll(encryptedAudio);

  final file = File('${directory.path}${Platform.pathSeparator}fixture.ncm');
  await file.writeAsBytes(contents);
  return (file, expectedAudio);
}

Uint8List _aesEncrypt(Uint8List data, Uint8List key) {
  final cipher = BlockCipher('AES/ECB')..init(true, KeyParameter(key));
  final result = Uint8List(data.length);
  for (var offset = 0; offset < data.length; offset += 16) {
    cipher.processBlock(data, offset, result, offset);
  }
  return result;
}

Uint8List _pkcs7Pad(Uint8List data) {
  final paddingLength = 16 - data.length % 16;
  return Uint8List.fromList([
    ...data,
    ...List.filled(paddingLength, paddingLength),
  ]);
}

Uint8List _buildKeyBox(Uint8List key) {
  final box = Uint8List.fromList(List.generate(256, (index) => index));
  var c = 0;
  var lastByte = 0;
  var keyOffset = 0;

  for (var i = 0; i < 256; i++) {
    final swap = box[i];
    c = (swap + lastByte + key[keyOffset]) & 0xff;
    keyOffset = (keyOffset + 1) % key.length;
    box[i] = box[c];
    box[c] = swap;
    lastByte = c;
  }

  return box;
}

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < result.length; i++) {
    result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}

void _xorInPlace(Uint8List data, int value) {
  for (var i = 0; i < data.length; i++) {
    data[i] ^= value;
  }
}

void _addLittleEndianUint32(List<int> output, int value) {
  output.addAll([
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ]);
}
