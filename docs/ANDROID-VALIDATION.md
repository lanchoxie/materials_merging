# Android 预览验证

- 版本：0.21.0-homestead-11；versionCode 23；org.atomatelier.demo。
- 文件：72,873,941 字节；SHA-256 `12697863cc0aa51f49847acbc9cdd48adf584cf9c45c3cac64393bad0bd5771d`。
- APK 签名 v2/v3 通过，证书 SHA-256 `87398a0076a6ab1c9f98c966bed8b42fce10d4d3109788994e2905d63292b2d5`，与前一预览一致。
- ZIP 完整性、当前 JSON 数据比对、编译脚本、中文字体与许可、ARM64/ARMv7、私有文件排除检查通过。
- 实际 APK 解包后的模型45项、原生 OpenGL 界面31项及资源11项检查通过。
- headless 界面运行曾有7项失败，使用真实 OpenGL 渲染与输入路径重跑后31项通过；不以 headless 结果宣称界面验收。
- 未进行 Android 真机测试；Godot 在隔离环境中读取系统证书库有错误日志，以上离线测试完成且通过。

本预览不计作正式功能版本。完整自动检查报告随 Release 附件提供。
