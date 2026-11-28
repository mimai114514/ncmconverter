import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ncmpp_flutter/src/services/telemetry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'NCM Converter',
      packageName: 'io.github.mimai114514.ncmconverter',
      version: '1.2.3',
      buildNumber: '4',
      buildSignature: '',
    );
  });

  tearDown(() async {
    await TelemetryService.instance.shutdown();
  });

  Future<List<Map<String, dynamic>>> initWithSender() async {
    final payloads = <Map<String, dynamic>>[];
    await TelemetryService.instance.init(
      enabledOverride: true,
      sender: (uri, body) async {
        payloads.add(jsonDecode(body) as Map<String, dynamic>);
        return 204;
      },
    );
    return payloads;
  }

  test('sends a heartbeat and a convert event', () async {
    final payloads = await initWithSender();
    TelemetryService.instance.track('convert.run', durationMs: 42, ok: true);
    await TelemetryService.instance.flush();

    expect(payloads, isNotEmpty);
    final payload = payloads.last;
    expect(payload['app'], 'ncmconverter');

    final events = (payload['events'] as List).cast<Map<String, dynamic>>();
    final heartbeat = events.firstWhere(
      (event) => event['event'] == 'heartbeat',
    );
    final run = events.firstWhere((event) => event['event'] == 'convert.run');

    expect(heartbeat['installId'], hasLength(32));
    expect(heartbeat['os'], isNotEmpty);
    expect(heartbeat['count'], 1);
    expect(run['durationMs'], 42);
    expect(run['ok'], 1);
    expect(run['count'], 1);
    expect(run['failed'], 0);
    expect(run['version'], '1.2.3');
    expect(run['channel'], 'github');
  });

  test('carries file counts for conversion runs', () async {
    final payloads = await initWithSender();
    TelemetryService.instance.track(
      'convert.run',
      durationMs: 500,
      ok: false,
      errorCode: 'partial_failure',
      count: 12,
      failed: 3,
    );
    await TelemetryService.instance.flush();

    final events = (payloads.last['events'] as List)
        .cast<Map<String, dynamic>>();
    final run = events.firstWhere((event) => event['event'] == 'convert.run');
    expect(run['count'], 12);
    expect(run['failed'], 3);
    expect(run['ok'], 0);
    expect(run['errorCode'], 'partial_failure');
  });

  test('sends at most one heartbeat per day', () async {
    final first = await initWithSender();
    await TelemetryService.instance.flush();
    expect(_count(first, 'heartbeat'), 1);

    final second = await initWithSender();
    await TelemetryService.instance.flush();
    expect(_count(second, 'heartbeat'), 0);
  });

  test('sends nothing when disabled', () async {
    final payloads = <Map<String, dynamic>>[];
    await TelemetryService.instance.init(
      enabledOverride: false,
      sender: (uri, body) async {
        payloads.add(jsonDecode(body) as Map<String, dynamic>);
        return 204;
      },
    );

    TelemetryService.instance.track('convert.run');
    await TelemetryService.instance.flush();

    expect(payloads, isEmpty);
  });

  test('requeues the batch on server errors', () async {
    final payloads = <String>[];
    var status = 500;

    await TelemetryService.instance.init(
      enabledOverride: true,
      sender: (uri, body) async {
        payloads.add(body);
        return status;
      },
    );

    TelemetryService.instance.track('convert.run');
    await TelemetryService.instance.flush();
    expect(payloads, hasLength(1));

    status = 204;
    await TelemetryService.instance.flush();
    expect(payloads, hasLength(2));
    expect(payloads[0], payloads[1]);
  });

  test('does not send paths or file names', () async {
    final payloads = await initWithSender();
    TelemetryService.instance.track('convert.run', durationMs: 7, ok: false);
    await TelemetryService.instance.flush();

    final body = jsonEncode(payloads.last);
    expect(body.contains('/'), isFalse);
    expect(body.contains(r'\'), isFalse);
  });
}

int _count(List<Map<String, dynamic>> payloads, String event) {
  var count = 0;
  for (final payload in payloads) {
    final events = (payload['events'] as List).cast<Map<String, dynamic>>();
    count += events.where((entry) => entry['event'] == event).length;
  }
  return count;
}
