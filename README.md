# 剪贴笺 CVSticky for macOS

CVSticky 的原生 macOS 版本，使用 SwiftUI、AppKit、WebKit 和 Swift 6 构建，只面向 Apple Silicon Mac。

## 系统要求与视觉

- 最低系统：macOS 12 Monterey。
- 芯片：Apple Silicon，覆盖 M1 及之后所有 M 系列芯片。
- macOS 26 及更高版本：使用系统原生 Liquid Glass。
- macOS 12–15：自动降级到 `NSVisualEffectView` 原生半透明材质，功能保持一致。

## 功能

- 文本、富文本、图片和文件剪贴板历史，普通记录保留最近 100 条。
- `Option+V` 全局快捷浮窗，支持搜索、键盘选择、复制、删除和多显示器定位。
- 原文固定为便签，以及 OpenAI Chat Completions 兼容接口的流式 AI 整理方案。
- Markdown 文件型便签，兼容 `~/.cvsticky/<便签>/note.md` 与 `for-cvsticky`/`for-clipboard` 元数据。
- Markdown 编辑工具栏：标题、粗体、斜体、下划线、删除线、列表、任务、引用、链接、图片、表格、LaTeX 和 Mermaid。
- GFM、任务列表回写、代码高亮、本地图片、KaTeX 与 Mermaid 原生预览。
- 搜索、标签/颜色筛选、列表/网格视图、自定义右键菜单。
- 最近删除、恢复、彻底删除、ZIP 导入导出。
- 浅色、深色、跟随系统、主题色、快捷键和 AI 设置。
- `Command+?` 应用内图文帮助手册，并提供主窗口、剪贴板和编辑器操作说明。
- API Key 保存在 macOS 钥匙串。
- 原生菜单栏入口，关闭主窗口后继续监控剪贴板。

## 开发

更多使用、安装、发布和开发规范见 [文档索引](docs/Home.md)，图文操作指南见 [帮助手册](docs/Help.md)。本项目的阶段性实现、技术决策和验证记录见 [开发日志](docs/DEVELOPMENT_LOG.md)。

所有代码开发必须在 `dev` 分支或从 `dev` 派生的功能分支进行；进入 `dev` 必须经过作者 PR 审核，`main` 只允许作者本人在验证通过后手动合并。详见 [分支开发、PR 审核与 main 分支保护规范](docs/BRANCH_POLICY.md)。

需要包含 macOS 26 SDK 的完整 Xcode：

```bash
swift build
swift test
swift run CVSticky
```

构建可分发的 Apple Silicon App：

```bash
scripts/build-app.sh
```

产物位于：

```text
dist/CVSticky.app
dist/CVSticky-macOS-arm64.zip
```

## 数据目录

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
