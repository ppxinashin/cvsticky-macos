# 跨设备剪贴板联动替代方案

CVSticky macOS 只做本机剪贴板历史与 Markdown 便签管理。项目不计划开发或维护手机剪贴板、验证码、短信、通知、跨设备剪贴板同步功能，也不计划提供 Android/iOS 端 App、ADB/scrcpy 桥接、网页消息抓取或第三方账号联动。

如果需要手机与电脑、Windows 与 macOS、或多台电脑之间的剪贴板联动，请优先使用手机厂商、操作系统厂商或成熟第三方工具提供的官方能力，并只从官网下载。

CVSticky 只会读取当前 Mac 本机系统剪贴板中已经出现的内容。外部设备的内容如果通过系统或第三方工具同步到了 macOS 剪贴板，CVSticky 才会按普通本机剪贴板内容处理。

## 安卓手机与电脑

| 手机/生态 | 推荐方案 | 说明 | 官网入口 |
| --- | --- | --- | --- |
| 华为 | 微信输入法剪贴板同步 | 适合华为与 macOS 之间做剪贴板同步。需要在手机和 Mac 端使用微信输入法并开启对应同步能力，支持范围以微信输入法官网和应用商店当前版本为准。 | [微信输入法](https://z.weixin.qq.com/) |
| 小米/REDMI | 小米互联服务、Xiaomi HyperConnect | 面向 HyperOS 设备的跨端互联，适合在手机、平板、电脑之间做跨设备复制粘贴和文件流转。 | [Xiaomi HyperConnect](https://hyperos.mi.com/continuity) |
| OPPO/一加/realme | O+ Connect、跨屏互联 | 适合 ColorOS 生态设备与电脑互联。是否支持跨设备剪贴板、支持哪些机型和系统版本，以官网客户端说明为准。 | [O+ Connect](https://connect.oppo.com/) |
| vivo/iQOO | vivo 办公套件 | 适合 vivo/iQOO 手机与电脑之间的跨屏办公。剪贴板联动能力与支持设备范围以当前官网版本为准。 | [vivo 办公套件](https://pc.vivo.com.cn/) |
| 三星 Galaxy | KDE Connect、微信输入法剪贴板同步 | macOS 上可优先评估 KDE Connect 的设备互联和剪贴板插件；也可将微信输入法剪贴板同步作为备选方案。不同系统版本、输入法权限和设备权限设置会影响体验。 | [KDE Connect](https://kdeconnect.kde.org/)、[微信输入法](https://z.weixin.qq.com/) |

### 使用建议

- 华为及所有使用鸿蒙 NEXT 设备需要和 macOS 做剪贴板同步时，优先评估微信输入法剪贴板同步。
- 三星 Galaxy 设备需要和 macOS 做剪贴板同步时，优先评估 KDE Connect，也可评估微信输入法剪贴板同步。
- 其他安卓设备优先选手机厂商自己的电脑端工具，例如小米互联服务、O+ Connect、vivo 办公套件。
- 下载时只使用官网或系统应用商店，避免使用第三方下载站、破解包、绿色版。
- 如果工具要求登录厂商账号、蓝牙、同一 Wi-Fi、USB 调试或设备互信，请按厂商指引开启。
- 验证码属于敏感信息。开启跨设备剪贴板后，验证码可能进入电脑端剪贴板历史、输入法历史或第三方工具历史，请在对应工具里检查隐私和保留策略。

## 苹果手机与 Mac、Windows

| 组合 | 推荐方案 | 剪贴板联动结论 | 官网入口 |
| --- | --- | --- | --- |
| iPhone/iPad 与 Mac | Universal Clipboard / 连续互通 | 官方原生支持。在同一 Apple ID、蓝牙/Wi-Fi/Handoff 满足条件时，可在 Apple 设备之间复制粘贴文本、图片、照片和视频。 | [Apple Universal Clipboard](https://support.apple.com/en-us/102430) |
| iPhone 与 Windows | Phone Link for iOS | 可做电话、短信、通知等基础联动，但不是 Apple 官方 Universal Clipboard，不能按 Mac 体验理解为完整剪贴板同步。 | [Phone Link](https://www.microsoft.com/windows/sync-across-your-devices) |
| iPhone 与非苹果电脑 | 第三方工具 | 不作为 CVSticky 推荐主线。iOS 对后台剪贴板读取和自动同步限制较多，稳定性、隐私和审核限制都取决于具体工具。 | 以工具官网为准 |

## 安卓/苹果手机与电脑通用方案

| 方案 | 适合场景 | 说明 | 官网入口 |
| --- | --- | --- | --- |
| KDE Connect | 安卓或苹果手机与 Windows、macOS、Linux 电脑互联 | 支持多平台设备互联和剪贴板插件。这里仅作为手机与电脑之间的同步方案推荐；不同平台体验差异较大，适合作为可折腾选项。 | [KDE Connect](https://kdeconnect.kde.org/) |
| 微信输入法剪贴板同步 | 安卓手机与 Windows、macOS 电脑之间同步剪贴板 | 适合没有稳定厂商互联工具、或希望使用输入法自带同步能力的安卓手机。需要在手机和电脑端使用微信输入法并开启对应同步能力，支持范围以当前版本为准。 | [微信输入法](https://z.weixin.qq.com/) |

如果是不知名安卓手机、海外品牌安卓手机，或手机厂商没有提供稳定的 macOS 互联工具，可以直接优先评估 KDE Connect 或微信输入法剪贴板同步。

## Windows 与 macOS 之间

| 方案 | 适合场景 | 说明 | 官网入口 |
| --- | --- | --- | --- |
| Logitech Options+ / Flow | 已使用支持 Flow 的罗技鼠标或键盘 | 可在多台电脑之间切换鼠标键盘，并共享复制粘贴内容。适合 Windows 与 macOS 混用办公桌。 | [Logitech Options+](https://www.logitech.com/software/logi-options-plus.html) |
| Synergy | 希望用一套键鼠控制多台电脑 | 商业软件，支持 Windows、macOS、Linux 之间共享键鼠和剪贴板。 | [Synergy](https://symless.com/synergy) |
| ShareMouse | 希望快速做跨平台键鼠与剪贴板共享 | 支持 Windows 与 macOS，适合桌面间共享输入和剪贴板。授权模式以官网为准。 | [ShareMouse](https://www.sharemouse.com/) |

## CVSticky 的边界

CVSticky 不会内置跨设备剪贴板同步，也不会接管手机验证码。原因包括：

- Android、iOS 对后台剪贴板、短信和通知读取都有严格隐私限制。
- 验证码、短信、通知属于高敏感数据，保存到剪贴历史容易带来误留存风险。
- 各手机厂商已经提供系统级互联工具，兼容性和授权体验更适合由厂商维护。
- CVSticky 的定位是轻量级本机剪贴板历史与便签工具，跨设备同步会显著扩大隐私、安全和维护边界。

用户如果需要跨设备剪贴板联动，请直接使用上面列出的系统或厂商方案。CVSticky 只会读取电脑本机系统剪贴板中已经出现的内容，不负责从手机、网页短信、云账号或外部设备主动抓取内容。
