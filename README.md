# SimpleLaunchPadRestore
One-key restore LaunchPad.

# SimpleLaunchPadRestore - macOS启动台恢复工具

![License](https://img.shields.io/badge/license-GPLv3-blue.svg)
![macOS](https://img.shields.io/badge/macOS-26+-black.svg)
![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)
![Version](https://img.shields.io/badge/version-1.0.0-orange.svg)
![GitHub Stars](https://img.shields.io/github/stars/laobamac/SimpleLaunchPadRestore?style=social)
![GitHub Forks](https://img.shields.io/github/forks/laobamac/SimpleLaunchPadRestore?style=social)

一个可以让你在macOS上恢复旧版启动台风格的实用工具，同时也能随时恢复新版SpotlightPlus功能。

## ✨ 功能特性

- 🔄 一键切换新旧版启动台界面
- ⏳ 恢复经典macOS启动台体验
- 🔍 保留/恢复SpotlightPlus功能
- 📦 自动备份系统原始文件
- ⚠️ 安全提示和错误处理
- 📝 详细日志记录

## 🚀 快速开始

### 安装要求

- macOS Tahoe 26.0 B4 或更高版本
- 已禁用SIP (系统完整性保护) `csr-active-config 设置为 03080000或更高`
- sudo权限

### 使用方法

1. 下载最新RELEASE
2. 运行SimpleLaunchPadRestore.app
3. 按照屏幕提示操作

## ⚠️ 重要警告

- 使用前请确保已禁用SIP
- 建议先备份重要数据
- 操作有风险，请谨慎使用
- 本工具会修改系统文件

## 🔧 工作原理

工具通过替换以下系统应用实现功能：
- `/System/Applications/Apps.app`
- `/System/Library/CoreServices/Dock.app`
- `/System/Library/CoreServices/Spotlight.app`

## 📜 许可证

本项目采用 GPLv3 许可证 - 详情见 [LICENSE](LICENSE) 文件

## 💖 致谢

感谢所有测试人员和贡献者！

## ☕ 支持作者

<div align="center">
<h3>如果这个项目帮到了你，可以给我买杯咖啡：</h3>
<img width="287"alt="84f6564a9497f5b4c3e1f952f7c57ca8" src="https://github.com/user-attachments/assets/6f4e7b2a-f7d4-4a98-8469-fc8fa6f9c18d" /><img width="256"alt="84f6564a9497f5b4c3e1f952f7c57ca8" src="https://github.com/user-attachments/assets/68dc88a5-c852-423c-b80f-42e275429f32" />
</div>
