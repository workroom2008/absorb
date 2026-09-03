# Absorb

[![Buy Me A Coffee](https://img.shields.io/badge/Buy_Me_A_Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/BarnabasApps)

一个现代化的 Audiobookshelf 客户端，提供卡片式播放体验。

> **关于 AI 的说明：** Absorb 由人类开发者开发，并借助 AI 辅助（主要是 Claude Code）进行代码编写、重构和审查。它并非"氛围编码"或自动生成，每一次更改都经过审查、测试和有意的发布。我全力支持 AI 作为开发工具，它极大地加速了开发工作，让独立开发者能够以其他方式无法实现的速度发布功能和修复。我公开分享这些信息，让你了解应用背后的情况。

## 截图

<p align="center">
  <img src="screenshots/absorbing.png" width="200">
  &nbsp;
  <img src="screenshots/library.png" width="200">
  &nbsp;
  <img src="screenshots/details.png" width="200">
</p>
<p align="center">
  <img src="screenshots/fullScreen.png" width="200">
  &nbsp;
  <img src="screenshots/stats.png" width="200">
</p>

## 功能特性

- **卡片式播放器** — 全屏"沉浸式"卡片取代传统播放界面
- **Audiobookshelf 集成** — 连接到你自托管的 Audiobookshelf 服务器
- **离线播放** — 下载书籍以便无网络时收听
- **播客支持** — 支持章节的播客，带有丰富的 HTML 描述
- **备份与恢复** — 将所有设置导出为 `.absorb` 文件，可在任何设备上导入，支持可选的账户凭证以实现无缝设备迁移
- **多账户** — 登录多个服务器并在它们之间切换
- **睡眠定时器** — 带有可视化填充条倒计时、自动睡眠调度和摇动重置
- **播放速度** — 精细滑块控制，每本书独立记忆速度设置
- **自动回退** — 可配置的暂停后回退时间，根据离开时长自动调整
- **均衡器** — 内置音频均衡器，支持频段和预设
- **书签** — 保存并跳转到任何书籍中的时刻
- **章节导航** — 双进度条（书籍 + 章节）
- **搜索与筛选** — 全文搜索，按进度/类型/系列筛选，多种排序模式
- **Audible 评分** — 查看书籍的 Audible 星级评分
- **自动播放下一集** — 自动继续系列中的下一本书或下一个播客剧集
- **Android Auto 和 Apple CarPlay** — 在车内浏览和收听
- **Chromecast** — 将播放投射到 Google Cast 设备（仅 Android）
- **自定义请求头** — 为反向代理设置添加自定义 HTTP 请求头
- **OIDC/SSO 登录** — 支持 OpenID Connect 和标准认证
- **服务器管理** — 从应用管理用户、备份和播客
- **收听统计** — 跟踪你的收听历史
- **Audnexus 元数据** — 丰富的书籍封面、描述和系列信息
- **发现未来缺失书籍** — 通过 Audible 目录发现系列中即将出版的书籍
- **笔记** — 每本书或剧集的笔记
- **播放列表与收藏** — 创建、管理和播放自定义分组
- **最近播放** — 快速访问收听历史
- **实时同步** — 通过 socket.io 同步进度、媒体库更改和系列更新
- **主屏幕小组件** — Android 和 iOS 上的正在播放小组件
- **驾驶模式** — 大按钮驾驶界面，无需 Android Auto 即可使用
- **本地化** — 通过 Crowdin 进行社区翻译

## 翻译

[![Crowdin](https://badges.crowdin.net/absorb/localized.svg)](https://crowdin.com/project/absorb)

Absorb 通过 [Crowdin](https://crowdin.com/project/absorb) 由社区翻译。想要添加或改进你的语言？加入我们，无需编码。

## 安装

[![Get it on GitHub](https://img.shields.io/badge/Get_it_on-GitHub-blue?style=for-the-badge&logo=github)](../../releases)
[![Get it on Obtainium](https://img.shields.io/badge/Get_it_on-Obtainium-teal?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZD0iTTEyIDJMMiAyMmgMEwxMiAyeiIgZmlsbD0id2hpdGUiLz48L3N2Zz4=)](https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/pounat/absorb)
[![Get it on Google Play](https://img.shields.io/badge/Google_Play-Open_Beta-414141?style=for-the-badge&logo=google-play&logoColor=white)](https://play.google.com/store/apps/details?id=com.barnabas.absorb)
[![Download on the App Store](https://img.shields.io/badge/App_Store-iOS-007AFF?style=for-the-badge&logo=apple&logoColor=white)](https://apps.apple.com/us/app/absorb-for-audiobookshelf/id6760673498)
[![Join TestFlight](https://img.shields.io/badge/TestFlight-iOS-007AFF?style=for-the-badge&logo=apple&logoColor=white)](https://testflight.apple.com/join/GgUbDbve)

### 发布轨道

**GitHub 预发布 (Alpha)** - 频繁更新，包含新功能和错误修复。在 Obtainium 中可以切换预发布版本的开关。

**GitHub 正式发布 (Beta/Stable)** - 预发布版本稳定后，会提升为正式发布。这些版本与推送到 Google Play 和 App Store 的版本一致。

### Google Play

公开测试已上线 - [在 Google Play 加入公开测试](https://play.google.com/store/apps/details?id=com.barnabas.absorb)。公开测试和正式发布与 GitHub 正式发布一致。内部测试（Alpha）与 GitHub 预发布一致 - 加入 [Discord](https://discord.gg/dW4Y4zCxRp) 以申请内部测试访问权限。

### App Store

已在 [App Store](https://apps.apple.com/us/app/absorb-for-audiobookshelf/id6760673498) 上架。App Store 发布版本与 GitHub 正式发布一致。部分功能目前仅限 Android 或正在开发中，请参阅下方 iOS 部分。

### iOS TestFlight (Alpha)

TestFlight 是 iOS Alpha 测试轨道，与 GitHub 预发布一致。构建频率更高，但不如 App Store 版本完善。[加入 TestFlight](https://testflight.apple.com/join/GgUbDbve)。如果你想要稳定版本，请使用 App Store。

### iOS Alpha (侧载)

Alpha `.ipa` 文件包含在 GitHub 预发布中，与 Android APK 一起提供。如果你知道如何侧载 IPA（通过 AltStore、Sideloadly 等），可以从[发布页面](../../releases)获取最新的 Alpha 构建。对大多数用户来说，TestFlight 更简单 - 自动更新，无需侧载设置。

## Android Auto

Absorb 支持 Android Auto，可在车内浏览和收听。如果你使用的是 GitHub 版本，需要在 Android Auto 中启用未知来源：

> 1. 在手机上打开 **Android Auto** 设置
> 2. 反复点击底部的 **版本** 以启用开发者模式
> 3. 点击右上角的三点菜单，选择 **开发者设置**
> 4. 启用 **未知来源**
>
> 这是必需的，因为 GitHub 版本的 Absorb 不通过 Google Play 的正式发布渠道分发。

## 系统要求

- [Audiobookshelf](https://www.audiobookshelf.org/) 服务器（自托管）
- Android 7.0+ / iOS 16+

## 许可证

版权所有 (C) 2026 Nathan Poulson

本程序是自由软件：你可以根据自由软件基金会发布的 GNU 通用公共许可证的条款，重新分发和/或修改它， either version 3 of the License, or (at your option) any later version.

本程序的分发是希望它会有用，但没有任何保证；甚至没有适销性或特定用途适用性的隐含保证。有关更多详细信息，请参阅 GNU 通用公共许可证。

你应该已经收到了 GNU 通用公共许可证的副本。如果没有，请参阅 <https://www.gnu.org/licenses/>。
