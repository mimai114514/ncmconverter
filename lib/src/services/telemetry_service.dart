import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef TallySender = Future<int> Function(Uri uri, String body);

class TelemetryService {
  TelemetryService._() {
    _httpClient.connectionTimeout = const Duration(seconds: 4);
  }

  static final TelemetryService instance = TelemetryService._();

  static const String endpoint = 'https://tally.spaceofinfinity.top';
  static const String _app = 'ncmconverter';
  static const String _channel = String.fromEnvironment(
    'TALLY_CHANNEL',
    defaultValue: 'github',
  );
  static const String _installIdKey = 'tally_install_id';
  static const String _heartbeatDayKey = 'tally_heartbeat_day';
  static const int _flushIntervalSeconds = 15;
  static const int _maxBatch = 50;
  static const int _maxQueue = 200;

  final HttpClient _httpClient = HttpClient();
  final List<Map<String, Object>> _queue = [];

  Timer? _timer;
  TallySender? _sender;
  String _installId = '';
  String _version = '0.0.0';
  String _os = '';
  String _arch = '';
  bool _enabled = false;
  bool _inFlight = false;

  bool get enabled => _enabled;

  Future<void> init({TallySender? sender, bool? enabledOverride}) async {
    _timer?.cancel();
    _timer = null;
    _queue.clear();
    _inFlight = false;
    _enabled = false;
    _sender = sender;

    if (enabledOverride == false) return;
    if (enabledOverride == null && !_shouldEnable()) return;

    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.version;
      _os = _platformName();
      _arch = _abiName();

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_installIdKey);
      _installId = stored != null && stored.length >= 8
          ? stored
          : _newInstallId();
      if (stored != _installId) {
        await prefs.setString(_installIdKey, _installId);
      }

      _enabled = true;
      _timer = Timer.periodic(
        const Duration(seconds: _flushIntervalSeconds),
        (_) => flush(),
      );
      _heartbeat(prefs);
    } catch (error) {
      debugPrint('[Tally] 初始化失败: $error');
      _enabled = false;
    }
  }

  void track(
    String event, {
    int? durationMs,
    bool ok = true,
    String errorCode = '',
    int? count,
    int? failed,
  }) {
    if (!enabled) return;

    final name = event.trim();
    if (name.isEmpty) return;

    final total = (count ?? 1).clamp(0, 1000000).toInt();
    final failures = (failed ?? (ok ? 0 : 1)).clamp(0, total).toInt();

    _queue.add({
      'installId': _installId,
      'event': name.length > 64 ? name.substring(0, 64) : name,
      'version': _version,
      'os': _os,
      'arch': _arch,
      'channel': _channel,
      'durationMs': (durationMs ?? 0).clamp(0, 86400000).toInt(),
      'count': total,
      'failed': failures,
      'ok': ok ? 1 : 0,
      'errorCode': errorCode.length > 64
          ? errorCode.substring(0, 64)
          : errorCode,
    });

    if (_queue.length > _maxQueue) {
      _queue.removeRange(0, _queue.length - _maxQueue);
    }
    if (_queue.length >= _maxBatch) {
      unawaited(flush());
    }
  }

  Future<void> flush() async {
    if (!enabled || _inFlight || _queue.isEmpty) return;

    _inFlight = true;
    final batch = _queue.take(_maxBatch).toList(growable: false);
    _queue.removeRange(0, batch.length);

    try {
      final body = jsonEncode({'app': _app, 'events': batch});
      final result = await (_sender ?? _post)(
        Uri.parse('$endpoint/v1/events'),
        body,
      );
      if (result == 0 || result == 429 || result >= 500) {
        _queue.insertAll(0, batch);
        if (_queue.length > _maxQueue) {
          _queue.removeRange(_maxQueue, _queue.length);
        }
      }
    } catch (error) {
      debugPrint('[Tally] 上报失败: $error');
      _queue.insertAll(0, batch);
    } finally {
      _inFlight = false;
    }
  }

  Future<void> shutdown() async {
    _timer?.cancel();
    _timer = null;
    await flush();
  }

  Future<int> _post(Uri uri, String body) async {
    try {
      final request = await _httpClient
          .postUrl(uri)
          .timeout(const Duration(seconds: 4));
      request.headers.contentType = ContentType.json;
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'tally-ncmconverter/$_version',
      );
      request.write(body);
      final response = await request.close().timeout(
        const Duration(seconds: 4),
      );
      await response.drain<void>();
      return response.statusCode;
    } catch (_) {
      return 0;
    }
  }

  void _heartbeat(SharedPreferences prefs) {
    final day = _utcDay(DateTime.now());
    if (prefs.getString(_heartbeatDayKey) == day) return;
    unawaited(prefs.setString(_heartbeatDayKey, day));
    track('heartbeat');
  }

  bool _shouldEnable() {
    final env = Platform.environment;
    if (_truthy(env['DO_NOT_TRACK']) ||
        _truthy(env['TALLY_DISABLED']) ||
        _truthy(env['TALLY_OPTOUT']) ||
        _truthy(const String.fromEnvironment('DO_NOT_TRACK')) ||
        _truthy(const String.fromEnvironment('TALLY_DISABLED')) ||
        _truthy(const String.fromEnvironment('TALLY_OPTOUT'))) {
      return false;
    }

    final force =
        _truthy(env['TALLY_FORCE']) ||
        _truthy(const String.fromEnvironment('TALLY_FORCE'));
    if (force) return true;
    if (!kReleaseMode) return false;

    final ci = env['CI'];
    if (ci != null && ci.isNotEmpty && ci != 'false' && ci != '0') {
      return false;
    }
    return true;
  }

  static bool _truthy(String? value) {
    if (value == null) return false;
    final normalized = value.toLowerCase();
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'on';
  }

  static String _platformName() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isAndroid) return 'android';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isIOS) return 'ios';
    return Platform.operatingSystem;
  }

  static String _abiName() {
    try {
      final abi = Abi.current();
      if (abi == Abi.windowsX64 ||
          abi == Abi.linuxX64 ||
          abi == Abi.androidX64 ||
          abi == Abi.macosX64) {
        return 'x64';
      }
      if (abi == Abi.windowsArm64 ||
          abi == Abi.linuxArm64 ||
          abi == Abi.androidArm64 ||
          abi == Abi.macosArm64) {
        return 'arm64';
      }
      if (abi == Abi.androidArm) return 'arm';
      if (abi == Abi.androidIA32) return 'ia32';
      return '';
    } catch (_) {
      return '';
    }
  }

  static String _newInstallId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  static String _utcDay(DateTime time) {
    final utc = time.toUtc();
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    return '${utc.year}-$month-$day';
  }
}
