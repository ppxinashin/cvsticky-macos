# Mac App Store 合规审计记录

检查日期：2026-07-18

检查对象：CVSticky macOS 当前源码、`dist/CVSticky.app`、DMG/ZIP 打包脚本及 GitHub Release 工作流。

## 结论

当前版本不符合 Mac App Store 上架要求，不应直接提交审核。主要阻塞项是缺少 App Sandbox、便签数据直接写入用户主目录、当前产物使用 ad-hoc 签名、没有商店提交构建流程，以及应用内缺少完整隐私政策和剪贴板监控告知。

当前版本可以作为开发测试包使用，但现有 GitHub Release 流程生成的公开产物同样使用 ad-hoc 签名且没有 Apple 公证，不适合作为面向普通用户的正式站外分发包。

合规就绪度仅用于内部规划，不代表 Apple 审核结论：

- Mac App Store：约 40%，当前不可提交。
- 官网 Developer ID 分发：约 65%，需要完成正式签名、公证和装订票据。

## 阻塞项

### 1. 未启用 App Sandbox

仓库中没有应用 entitlements 文件，当前 App 签名也不包含 `com.apple.security.app-sandbox`。Mac App Store 要求 macOS App 使用 App Sandbox。

整改要求：

- 增加商店专用 entitlements。
- 至少评估并配置：
  - `com.apple.security.app-sandbox`
  - `com.apple.security.network.client`
  - 如允许用户自选数据目录，配置 `com.apple.security.files.user-selected.read-write`
- 使用商店签名后的实际 App 验证所有功能，而不能只验证未沙盒化开发包。

Apple 依据：[Protecting user data with App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)、[App Review Guidelines 2.4.5](https://developer.apple.com/app-store/review/guidelines/)。

### 2. 默认数据目录与沙盒不兼容

`NoteStore` 默认直接创建和访问：

```text
~/.cvsticky/
~/.clipboard/
```

沙盒应用不能任意读写用户主目录。直接启用沙盒后，现有便签创建、迁移、导入、导出和“在访达中显示”等流程可能失效。

整改方案二选一：

1. 将默认数据迁移到应用容器中的 Application Support；或
2. 首次启动时由用户通过系统面板选择工作目录，并保存 security-scoped bookmark 供后续访问。

采用第二种方案时，还需要设计旧版 `~/.cvsticky` 数据的一次性、用户授权迁移流程。

Apple 依据：[Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)。

### 3. 当前产物不是商店分发签名

本次实测 `dist/CVSticky.app`：

```text
Signature=adhoc
TeamIdentifier=not set
```

`scripts/build-app.sh` 的默认 `CODE_SIGN_IDENTITY` 也是 `-`，GitHub Release 工作流没有注入正式签名证书，因此自动发布的 DMG/ZIP 仍为 ad-hoc 签名。

整改要求：

- Mac App Store 版本使用 Apple Distribution/Mac App Distribution 所需的证书、App ID 和 provisioning profile。
- 建立独立的商店归档、验证和上传流程，通过 Xcode/App Store Connect 提交，而不是提交 DMG。
- 站外版本使用 Developer ID Application 签名、Hardened Runtime、安全时间戳、`notarytool` 公证及 `stapler` 装订。

Apple 依据：[Creating distribution-signed code for macOS](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac/)、[Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)。

### 4. 缺少隐私政策入口

仓库和应用内当前没有公开隐私政策链接。帮助页只说明了部分本地存储位置和钥匙串行为，不能替代完整隐私政策。

整改要求：

- 发布一份可公开访问的隐私政策网页。
- 在应用内“设置”或“帮助”中提供容易找到的隐私政策入口。
- 在 App Store Connect 填写隐私政策 URL。
- 隐私政策至少说明：
  - 剪贴板内容如何读取、保存、保留和删除；
  - 便签、图片和文件路径如何保存；
  - AI 功能会向哪个用户配置的服务发送什么内容；
  - API Key 的保存方式；
  - 第三方服务的数据保护、保留和删除责任；
  - 用户如何停止监控、撤回同意和删除本地数据。

Apple 依据：[App Review Guidelines 5.1.1](https://developer.apple.com/app-store/review/guidelines/)、[Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)。

### 5. 剪贴板监控缺少首次告知和明确同意

当前主窗口出现后会立即启动剪贴板监控，定时检查并把文本、富文本、图片和文件路径保存到历史中。应用没有首次启动说明、监控总开关、明确同意记录或持续状态提示。

这是隐私审核的高风险项。剪贴板可能包含密码、验证码、个人资料或其他敏感内容，即使数据只保存在本机，也应让用户在监控开始前清楚知情并主动选择。

整改要求：

- 首次启动时说明读取范围、保存位置、保留数量和清除方式。
- 由用户主动启用剪贴板历史；建议初始状态为未启用。
- 提供随时可用的监控开关和清晰的启用状态。
- 提供清空历史、删除本地数据和调整保留范围的入口。
- 在审核备注中具体解释剪贴板监控是产品核心功能及其隐私保护方式。

Apple 依据：[App Review Guidelines 2.5.14 and 5.1](https://developer.apple.com/app-store/review/guidelines/)。

## 高风险与待确认项

### AI 数据发送披露

启用 AI 后，应用会把最多 12,000 个字符的剪贴内容作为 Chat Completions 请求发送到用户填写的 Base URL，同时发送模型名并在请求头携带 API Key。当前设置页只说明“密钥保存在系统钥匙串”，没有说明剪贴内容会离开设备。

整改要求：

- AI 默认保持关闭。
- 启用 AI 和首次发送前，明确显示目标域名、发送内容类型和第三方处理责任。
- 对敏感剪贴内容给出提醒，并让用户每次主动触发发送。
- 根据第三方服务是否保留请求内容，在 App Store Connect 中准确申报数据处理；自由文本通常需要评估 `Other User Content`。
- 不得把“自带 API Key”视为免除应用隐私披露责任。

Apple 依据：[App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)。

### 通过外部进程调用 `/usr/bin/ditto`

便签 ZIP 导入和导出通过 `Process` 调用系统 `/usr/bin/ditto`。需要在真实 App Sandbox 和商店签名环境中验证子进程继承的权限、用户选择文件的沙盒扩展和审核兼容性。

建议优先评估使用 Foundation/系统归档 API 在应用进程内完成 ZIP 操作，减少沙盒和审核不确定性。

### PrivacyInfo.xcprivacy

当前仓库没有 `PrivacyInfo.xcprivacy`。原生代码没有引入 Apple 强制列出的常用第三方原生 SDK，但仍应在最终数据流确定后生成并验证隐私清单，确保它与 App Store Connect 的隐私申报及实际行为一致。

注意：Apple 当前“required reason API”文档列出的平台范围和 macOS 并不完全相同，不能机械复制 iOS 清单；应使用最终提交所用 Xcode 的隐私报告和上传验证结果确定内容。

Apple 依据：[Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)。

### 第三方前端资源许可证

应用包中包含 Milkdown、Marked、KaTeX、Mermaid 及其依赖。当前只有 Milkdown 的独立许可证文件；Marked 在源文件头保留了 MIT 声明，但 KaTeX、Mermaid 和间接依赖的许可证归档仍需完整核对。

整改要求：

- 建立依赖名称、版本、来源、许可证和随包声明清单。
- 将所有许可证要求的版权与许可文本放入 App bundle，并在应用内提供“开源许可”入口。
- 确认图标、截图、帮助图片和字体的使用权。

Apple 依据：[App Review Guidelines 5.2](https://developer.apple.com/app-store/review/guidelines/)。

### 商店元数据尚未形成

仓库中未发现完整的 App Store Connect 元数据，因此以下内容尚不能判定合规：

- App 名称、关键词、说明和“新增内容”；
- 支持 URL、营销 URL 和隐私政策 URL；
- 截图和预览；
- 2026 年新版年龄分级问卷；
- App Privacy 回答；
- 内容权利声明；
- 审核备注和测试步骤。

应在提交前建立元数据检查表，确保描述准确披露剪贴板监控、后台驻留、全局快捷键、AI 和本地文件行为。

## 当前符合或风险较低的部分

- 使用 SwiftUI、AppKit、WebKit、Security 等系统公开框架。
- API Key 存入 macOS Keychain，普通设置和导出文件不保存明文密钥。
- AI 默认关闭，未配置密钥时不影响本地功能。
- 没有自建更新器；商店版不会与“只能通过 Mac App Store 更新”的要求冲突。
- 没有自有支付、许可证密钥或付费解锁逻辑，当前不存在 IAP 绕行问题。
- Markdown 预览使用 WebKit，相关 JavaScript/CSS 资源随应用打包，未依赖 CDN。
- 导入压缩包后检查符号链接、文件数量和总大小。
- 应用功能完整度明显高于简单网页封装或模板应用。
- 只支持 Apple Silicon 本身不是审核阻塞项，但商店元数据必须准确说明兼容设备。

## 本次验证结果

### 构建和测试

使用本机 `/Applications/Xcode-beta.app`：

```text
Xcode 27.0
macOS SDK 27.0
```

执行 Swift Package 测试结果：

```text
15 tests, 0 failures
```

最初在受限执行环境中 SwiftUI 宏插件无法启动；允许在工具沙盒外执行后，项目成功构建且全部测试通过。该问题属于检查环境限制，不是已确认的产品源码故障。

### 当前发布产物

- `codesign --verify --deep --strict`：App 文件结构和现有 ad-hoc 签名校验通过。
- `codesign -dvvv`：确认签名类型为 ad-hoc，无 TeamIdentifier，无 App Sandbox entitlement。
- `hdiutil verify`：DMG 校验和有效。
- `spctl`/`stapler`：当前包没有可验证的 Developer ID/公证票据，不能视为正式 Gatekeeper 分发包。
- 二进制架构：arm64。

## 整改顺序

建议按以下顺序推进，避免先做签名和元数据后又因数据目录设计返工：

1. 确定商店版的数据目录和旧数据迁移方案。
2. 启用 App Sandbox，配置最小权限，并修复沙盒下的功能。
3. 增加剪贴板首次告知、主动启用和监控状态管理。
4. 完善 AI 数据发送披露、隐私政策和数据删除说明。
5. 验证或替换 `/usr/bin/ditto` 导入导出实现。
6. 补齐第三方许可证和应用内开源许可页。
7. 建立 App Store 专用签名、归档和上传流程。
8. 在真实商店签名构建上进行功能、沙盒、网络、钥匙串、导入导出和升级测试。
9. 准备 App Store Connect 元数据、隐私申报和审核备注。
10. 上传预检并处理 Xcode/App Store Connect 返回的全部错误和警告，再提交人工审核。

## 发版门槛

在以下条件全部满足前，不应将版本标记为“Mac App Store ready”：

- 商店签名构建包含有效 App Sandbox entitlement。
- 沙盒环境下便签、剪贴板、AI、钥匙串、导入导出和旧数据迁移全部通过测试。
- 应用内存在可访问的隐私政策、剪贴板监控开关和 AI 数据发送说明。
- App Store Connect 隐私、年龄分级、内容权利和元数据已经填写并复核。
- Xcode Archive Validate/App Store Connect 上传预检无阻塞错误。
- 审核备注提供完整测试路径和非显而易见功能说明。

## 审计限制

本记录是基于 2026-07-18 可见源码、当前本地产物和 Apple 当日公开规则的工程审查，不是 Apple 的正式审核结果，也不构成法律意见。Apple 规则、工具链门槛和审核实践会更新；每次正式提交前都应重新核对最新要求。
