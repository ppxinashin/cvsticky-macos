# CVSticky macOS 安装与运行

本文适用于当前独立原生 macOS 仓库：`cvsticky-macos`。

## 支持范围

- 系统：macOS 12 Monterey 及以上。
- 芯片：Apple Silicon，覆盖 M1 及之后的 M 系列芯片。
- macOS 26 及以上：使用系统原生 Liquid Glass。
- macOS 12-15：自动降级到 `NSVisualEffectView` 半透明材质。

当前仓库不构建 Windows 版本，不发布 Linux CLI，也不使用 Tauri。

## 从 Release 安装

正式安装包应从项目 GitHub Releases 下载。

当前 macOS 发布产物为：

```text
CVSticky-macOS-arm64.dmg
CVSticky-macOS-arm64.zip
```

推荐普通用户下载 DMG：

1. 打开 DMG。
2. 将 `CVSticky.app` 拖入 `Applications`。
3. 从 Launchpad 或访达的“应用程序”目录启动。

如果 macOS 提示应用来自未识别开发者，请按发布说明中的签名/公证状态处理。开发验收包可能使用 ad-hoc 签名；正式面向普通用户分发时，应使用 Developer ID Application 签名并完成 Apple 公证。

## 从源码运行

需要包含 macOS 26 SDK 的完整 Xcode。

```bash
swift build
swift test
swift run CVSticky
```

## 构建可分发 App

```bash
scripts/build-app.sh
```

构建产物位于：

```text
dist/CVSticky.app
dist/CVSticky-macOS-arm64.dmg
dist/CVSticky-macOS-arm64.zip
```

如果需要 Developer ID 签名，可通过构建脚本支持的签名环境变量配置；未提供证书时继续生成适合开发验收的临时签名构建。

## 数据位置

便签默认保存在：

```text
~/.cvsticky/
├── <note-id>/
│   ├── note.md
│   └── img/
└── trash/
```

剪贴板历史与临时图片保存在：

```text
~/Library/Application Support/CVSticky/
```

API Key 保存在 macOS 钥匙串，不写入仓库或普通配置文件。
