# 剪贴笺 CVSticky for macOS

CVSticky 的原生 macOS 版本。项目使用 Swift 6、SwiftUI 和 AppKit 构建，只面向 macOS。

## 当前基础能力

- 原生 SwiftUI 三栏便签界面
- 监控文本剪贴板并保留最近 100 条记录
- 菜单栏快速查看、复制和固定剪贴内容
- Markdown 文件型便签，兼容 `~/.cvsticky/<便签>/note.md`
- 应用内最近删除、恢复与彻底删除
- 浅色、深色和跟随系统外观

## 开发

当前工程可直接使用 Swift Package Manager 构建：

```bash
swift build
swift run CVSticky
```

完整的签名、沙盒、快捷键、图片剪贴与发行包会在后续原生 macOS 迭代中补齐。桌面发行需要安装完整 Xcode。

## 数据目录

便签继续使用可直接编辑和备份的文件结构：

```text
~/.cvsticky/
├── <note-id>/
│   └── note.md
└── trash/
```

剪贴板历史保存在：

```text
~/Library/Application Support/CVSticky/clipboard-history.json
```
