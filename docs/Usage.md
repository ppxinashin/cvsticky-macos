# 剪贴笺 CVSticky macOS 使用说明

本文按当前原生 macOS 版本维护。旧 `paste_notes` 仓库中的 Windows、Linux CLI、Tauri 和 CodeMirror 说明不适用于本仓库。

## 安装与运行

普通用户请从项目 GitHub Releases 下载 macOS Apple Silicon 安装包。安装与源码运行方式见 [macOS 安装与运行](MacOS-Install.md)。

开发模式：

```bash
swift build
swift test
swift run CVSticky
```

构建可分发 App：

```bash
scripts/build-app.sh
```

## 主界面

左侧是导航栏：

- `新建便签`：创建一条空白便签，并默认进入编辑状态。
- `全部便签`：查看当前有效便签。
- `最近删除`：查看已移入应用内回收站的便签。
- `标签`：按便签标签筛选。
- `便签颜色`：按便签颜色筛选。
- `设置`：打开设置。

中间是便签列表：

- 支持搜索标题、正文和标签。
- 支持列表视图和网格视图切换。
- 普通便签右键菜单包含打开、复制、删除等操作。
- 最近删除里的便签支持恢复和彻底删除。

右侧是便签编辑与预览区。当前版本使用单区所见即所得 Markdown 编辑体验，并保持内容以纯 Markdown 文件保存。

## 剪贴浮窗

默认使用 `Option+V` 调出剪贴浮窗。快捷键可以在设置中修改。

浮窗会尽量显示在当前输入焦点或鼠标所在显示器，并保持置顶。

| 操作 | 说明 |
| --- | --- |
| `Option+V` | 调出剪贴浮窗 |
| `↑` / `↓` | 选择历史项 |
| `Enter` 或点击条目 | 复制当前选中的剪贴内容 |
| `Esc` | 关闭浮窗 |
| 搜索框输入关键词 | 按内容或来源应用过滤历史记录 |

剪贴历史条目的按钮和右键菜单可用：

- `复制`：复制该条剪贴内容。
- `固定为便签`：按原文转为便签。
- `AI 整理`：调用 OpenAI Chat Completions 兼容接口生成整理方案，再选择方案保存为便签。
- `删除`：从剪贴历史中删除该条记录。

如果未配置 AI，仍可使用原文固定为便签；AI 整理会提示不可用或生成失败。

普通剪贴板历史默认保留最近 100 条；已固定记录不受自动清理影响。

## 设置

设置页当前可配置：

- 显示模式：浅色、深色、跟随系统。
- 主题色。
- 全局快捷键。
- OpenAI Chat Completions 兼容服务地址、模型和 API Key。

Base URL 可填写类似 `https://api.openai.com/v1` 或其他兼容服务地址。API Key 保存到 macOS 钥匙串。

## 便签数据

便签默认保存到当前用户目录的 `.cvsticky` 文件夹：

```text
~/.cvsticky/
└── <note-id>/
    ├── note.md
    └── img/
```

应用内回收站位于：

```text
~/.cvsticky/trash/
```

剪贴板历史与临时图片保存在：

```text
~/Library/Application Support/CVSticky/
```

`note.md` 会兼容 `for-cvsticky` 与旧 `for-clipboard` 元数据块。新版本会使用更可靠的 JSON Base64 元数据载荷，以支持标题、标签中的引号、反斜杠、逗号和换行。

从旧版数据升级时，应用会兼容旧便签目录，并避免重复迁移已有 `note.md` 的便签。

## 便签编辑器

编辑器基于 Milkdown/ProseMirror 和本地 WebKit 资源实现所见即所得 Markdown 编辑，并持续回写纯 Markdown 文件。

编辑区支持：

- 标题、粗体、斜体、下划线、删除线、行内代码。
- 无序列表、有序列表、任务列表、引用。
- 链接、图片、表格、LaTeX 公式、Mermaid 图。
- macOS 主菜单和编辑器右键菜单中的常用格式命令。
- 图片粘贴或选择后写入便签 `img` 目录，并在 Markdown 中保留可迁移的相对路径。
- 预览状态下任务列表可以直接勾选，勾选状态会写回并保存到便签。

常用快捷键：

| 快捷键 | 作用 |
| --- | --- |
| `Command+B` | 粗体 |
| `Command+I` | 斜体 |
| `Command+U` | 下划线 |
| `Command+E` | 行内代码 |
| `Command+K` | 插入链接 |
| `Option+1` | 一级标题 |
| `Option+2` | 二级标题 |
| `Option+3` | 三级标题 |
| `Command+Shift+8` | 无序列表 |
| `Command+Shift+7` | 有序列表 |

Markdown 预览使用本地打包的 Marked、KaTeX 和 Mermaid 资源，不依赖 CDN。预览禁用原始 HTML，并阻止危险链接协议在 WebView 内执行。

## 删除与恢复

- 在 `全部便签` 中删除：确认后移动到 `最近删除`，也就是 `~/.cvsticky/trash/`。
- 在 `最近删除` 中恢复：将便签移回正常便签列表。
- 在 `最近删除` 中彻底删除：永久删除便签文件夹，无法撤销。
- 侧边栏 `最近删除` 右键菜单提供清空入口，并使用原生不可撤销确认。

剪贴板历史条目的 `删除` 只删除该条剪贴历史，不进入便签的最近删除。

## AI 整理

当前支持 OpenAI Chat Completions 兼容接口。可配置：

- Base URL
- 模型名称
- API Key
- 整理方式
- 目标语言
- 自定义补充要求
- 多个差异化方案

AI 输出应由用户复核后再保存为便签。未配置 API Key 或服务不可用时，不影响普通便签和剪贴板能力。
