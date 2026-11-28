import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'src/screens/home_screen.dart';
import 'src/services/ncm_decoder.dart';
import 'src/services/settings_service.dart';
import 'src/services/telemetry_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.instance.init();
  await TelemetryService.instance.init();
  runApp(const NcmppApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    SchedulerBinding.instance.scheduleTask<void>(
      () async {
        try {
          await NcmDecoder.instance.warmUp(1);
        } catch (error) {
          debugPrint('[NCM解密] 空闲预热 Isolate 失败: $error');
        }
      },
      Priority.idle,
      debugLabel: '预热 NCM 解密 Isolate',
    );
  });
}

class NcmppApp extends StatelessWidget {
  const NcmppApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NCM Converter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlueAccent,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlueAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
