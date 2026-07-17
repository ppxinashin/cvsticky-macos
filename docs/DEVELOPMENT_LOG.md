# CVSticky for macOS 开发日志

## 2026-07-17：原生 macOS 功能对齐与 Liquid Glass

### 本次目标

- 将 CVSticky 拆分为独立的原生 macOS 项目，原项目后续不再构建 macOS 版本。
- 以原版现有能力为基准补齐功能，不保留仅能演示的占位实现。
- 覆盖所有 Apple Silicon Mac；macOS 26 起启用系统原生 Liquid Glass。

### 技术与兼容策略

- 使用 SwiftUI 构建主界面，AppKit 负责剪贴板、菜单栏、全局快捷键、窗口和系统集成，WebKit 负责 Markdown 预览。
- 部署目标为 macOS 12 Monterey，构建产物仅包含 `arm64` 架构，覆盖 M1 及后续 M 系列芯片。
- macOS 26 及以上通过可用性判断调用系统 `glassEffect`；macOS 12–15 使用 `NSVisualEffectView` 材质降级，业务功能不降级。
- 便签继续采用文件型存储：`~/.cvsticky/<便签>/note.md`，并兼容原有 `for-cvsticky`、`for-clipboard` 元数据。
- API Key 写入 macOS Keychain，不保存在普通配置文件或仓库中。

### 已完成能力

#### 剪贴板

- 捕获文本、富文本/HTML、图片和文件。
- 持久化历史、搜索、删除、复制、来源应用显示和原文固定。
- 普通记录最多保留最近 100 条，已固定记录不受自动清理影响。
- `Option+V` 全局快捷键、菜单栏入口、多显示器居中和置顶浮层。
- 浮层支持方向键选择、Enter 复制、Esc 关闭以及 AI 整理。

#### 便签

- 搜索、标签/颜色筛选、列表/网格切换和右键操作。
- 新建、编辑、自动保存、删除、恢复和彻底删除。
- 从剪贴板原文或 AI 结果创建便签。
- ZIP 导入导出及旧便签目录兼容读取。

#### Markdown

- 原生编辑器与格式工具栏。
- GFM、表格、任务列表及任务状态回写。
- 本地图片、链接、代码高亮、KaTeX 数学公式和 Mermaid 图表。
- 编辑/预览分屏与外部链接默认浏览器打开。
- Marked、KaTeX 和 Mermaid 作为本地资源打包，预览不依赖 CDN。

#### 设置与 AI

- 跟随系统、浅色、深色、主题色和快捷键配置。
- OpenAI Chat Completions 兼容服务地址、模型和流式响应。
- AI 连接测试、整理方案生成和便签转换。
- 数据目录访问、导入和导出入口。

#### 工程化

- Swift Package 测试目标。
- arm64 Release App 打包、临时签名和 ZIP 生成脚本。
- GitHub Actions CI 与按标签发布工作流。
- 独立仓库：<https://github.com/ppxinashin/cvsticky-macos>。

### 验证记录

- `swift test`：4 项测试全部通过，0 失败。
- Release 构建成功。
- `file`：Mach-O 64-bit executable arm64。
- `otool`：最低系统版本为 macOS 12.0。
- `codesign --verify --deep --strict`：通过。
- GitHub Actions CI：通过。
- 实机验收：主窗口、设置页、Markdown 预览和剪贴板置顶浮层均可正常打开和操作。

### 相关提交与 PR

- 功能提交：`b0d511d`（Complete native macOS feature parity and Liquid Glass）
- 开发分支：`agent/native-parity-liquid-glass`
- PR：<https://github.com/ppxinashin/cvsticky-macos/pull/1>

### 数据迁移注意事项

开发验收期间发现旧目录迁移判断会在目标目录已有便签时重复复制数据。代码已改为先检查目标目录中的实际 `note.md`，避免后续再次迁移。

测试期间已经产生的 16 条重复便签没有被自动删除，以避免误删用户数据。它们已被精确识别，但只有在用户明确确认后才应移动到可恢复的废纸篓目录。

### 后续发布事项

- 合并 PR 后，以 `v*` 标签触发 GitHub Release 构建。
- 面向普通用户正式分发时，应改用 Developer ID Application 签名并完成 Apple 公证；当前脚本生成的是适合开发验收的临时签名构建。
