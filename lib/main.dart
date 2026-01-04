import 'package:flutter/material.dart';
import 'src/screens/home_screen.dart';

void main() {
  runApp(const NcmppApp());
}

class NcmppApp extends StatelessWidget {
  const NcmppApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NCM 解密器',
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
