# CVSticky macOS 发版规范

本文记录当前 `cvsticky-macos` 仓库的版本号与发版流程。旧 `paste_notes` 仓库中的 `prod` 分支、Windows 安装包、Linux CLI 和 Tauri 发布流程不适用于本仓库。

## 分支规则

- `dev` 是日常开发与验证分支。
- `main` 是稳定发布分支。
- 所有进入 `dev` 的变更必须通过 Pull Request，并由仓库作者本人审核。
- 除作者本人外，任何人不得直接提交、推送或合并到 `main`。
- 作者本人有权在代码验证通过后，手动将 `dev` 或发布分支合并到 `main`。
- 发版 tag 应基于 `main` 中已验证的提交创建。

完整分支规则见 [分支开发、PR 审核与 main 分支保护规范](BRANCH_POLICY.md)。

推荐流程：

```bash
git switch dev
swift test
scripts/build-app.sh
git push origin dev

# 作者确认验证通过后
git switch main
git merge --ff-only dev
git push origin main

git tag v<version>
git push origin v<version>
```

发布工作流在推送 `v*` tag 时触发，也支持手动 workflow dispatch。推送 tag 前必须确认 `main` 已包含本次要发布的全部代码。

## 版本号规则

通常版本号使用三段式：

```text
x.x.x
```

例如：

```text
0.2.4
```

如果当前版本已经发布，但需要补包、补构建产物或修正发布包问题，使用四段式补包版本：

```text
x.x.x.n
```

例如：

```text
0.2.3.1
0.2.3.2
```

四段式版本只用于同一功能版本的补包场景。新功能、较大修复或正常迭代仍应进入下一个三段式版本。

## 发版前检查

发版前至少确认：

- `dev` 分支已经完成验证，并已按作者确认合并到 `main`。
- 工作区没有未提交的修改。
- Release Notes 已写入 `docs/release-notes/<tag>.md`，或确认使用 GitHub 自动生成说明。
- App 版本号与构建号可以从 Git tag 和 GitHub Run Number 正确注入。
- 本地基础校验通过。

常用校验命令：

```bash
swift test
scripts/build-app.sh
git diff --check
```

## 发布产物

当前 Release 应包含：

- `CVSticky-macOS-arm64.dmg`
- `CVSticky-macOS-arm64.zip`

构建脚本会生成：

```text
dist/CVSticky.app
dist/CVSticky-macOS-arm64.dmg
dist/CVSticky-macOS-arm64.zip
```

当前项目只面向 Apple Silicon Mac，不构建 Windows 安装包，不发布 Linux CLI，不上传旧 Tauri 产物。

正式面向普通用户分发时，应使用 Developer ID Application 签名并完成 Apple 公证；开发验收阶段可使用 ad-hoc 签名构建。

## Release Notes 规范

每次发版都必须写清楚本次发布内容，至少覆盖：

- 修复了哪些具体问题。
- 新增了哪些具体功能。
- 调整了哪些用户可感知的行为、入口、快捷键、安装包或兼容性。
- 如果是补包版本，必须说明补包原因，以及与上一版相比只变更了哪些内容。

不要使用过于笼统的描述，例如：

```text
修复若干问题
优化体验
提升稳定性
更新依赖
```

可以写成：

```text
- 修复编辑状态下从 Markdown 预览勾选任务可能覆盖未保存标题、标签和颜色的问题
- 新增 macOS 风格 app 图标，并写入 CFBundleIconFile
- 调整 DMG 打包，加入 Applications 快捷入口
- 修复本地图片文件名包含空格或非 ASCII 字符时 Markdown 无法识别的问题
```
