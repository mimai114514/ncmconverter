# NCM 解密器 Flutter Android 版

一个用于解密网易云音乐 NCM 格式文件的 Android 应用。

## 特性

- ✅ 选择输入文件夹，批量处理所有 NCM 文件
- ✅ 自定义输出目录
- ✅ 实时显示解密进度
- ✅ Material Design 3 界面
- ✅ 支持 Android 7.0+

## 快速开始

```bash
# 获取依赖
flutter pub get

# 连接 Android 设备后运行
flutter run

# 构建 APK
flutter build apk --release
```

## 项目结构

```
lib/
├── main.dart                  # 应用入口
├── src/
│   ├── core/
│   │   └── ncm_dump.dart      # 解密核心（纯 Dart）
│   ├── ffi/
│   │   └── ncm_decoder.dart   # 解密器服务
│   ├── models/
│   │   └── ncm_file.dart      # 数据模型
│   └── screens/
│       └── home_screen.dart   # 主界面
└── widgets/
    └── progress_card.dart     # 进度组件
```

## 技术栈

- **Flutter** - 跨平台 UI 框架
- **pointycastle** - 纯 Dart AES 加密库
- **file_picker** - 文件/目录选择

## 许可证

遵循原 ncmpp 项目许可证。
