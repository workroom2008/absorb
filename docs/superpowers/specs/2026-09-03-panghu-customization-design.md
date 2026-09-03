# 胖虎听书定制化设计文档

## 概述
对 Absorb 项目进行深度定制：新增功能、UI 改造、品牌重命名、完善汉化、优化构建。

---

## 模块1：跳过片头片尾

**需求**：每本书可单独设置片头/片尾跳过时长，播放界面加设置按钮。

**实现方案**：
- 在 `PlayerSettings` 中添加每本书的片头片尾时长存储（`Map<String, int>`，key 为书籍 ID）
- 新增设置项：`getSkipIntro(bookId)` / `getSkipOutro(bookId)`
- 在播放卡片界面（`card_playback_controls.dart`）添加一个"跳过设置"按钮
- 点击弹出 BottomSheet，可设置当前书的片头/片尾秒数（默认0=不跳）
- 播放开始时自动跳过片头，播放结束前自动跳过片尾（跳转下一章）

**涉及文件**：
- `lib/services/player_settings.dart` — 新增片头片尾设置
- `lib/widgets/card_playback_controls.dart` — 添加设置按钮
- `lib/l10n/app_zh.arb` — 新增翻译条目

---

## 模块2：悬浮玻璃导航栏

**需求**：从 PangHuMusic 移植悬浮玻璃导航栏效果。

**实现方案**：
- 引入 `liquid_glass_widgets` 依赖
- 创建 `lib/widgets/glass_navigation_bar.dart` 悬浮玻璃导航栏
- 修改主界面 Scaffold 使用悬浮导航栏（Positioned in Stack）
- 添加玻璃效果开关（设置页面）
- 默认启用，支持调节模糊强度

**涉及文件**：
- `pubspec.yaml` — 添加 liquid_glass_widgets 依赖
- `lib/widgets/glass_navigation_bar.dart` — 新建玻璃导航栏组件
- `lib/screens/home_screen.dart` — 修改主界面布局
- `lib/l10n/app_zh.arb` — 新增翻译条目

---

## 模块3：改名胖虎听书

**需求**：全局替换应用名称为"胖虎听书"。

**替换位置**：
| 文件 | 键 | 原值 | 新值 |
|------|-----|------|------|
| `android/app/src/main/AndroidManifest.xml` | android:label | Absorb | 胖虎听书 |
| `ios/Runner/Info.plist` | CFBundleDisplayName | Absorb | 胖虎听书 |
| `ios/Runner/Info.plist` | CFBundleName | Absorb | 胖虎听书 |
| `pubspec.yaml` | description | An Audiobookshelf Client | 胖虎听书 - 跨平台有声书客户端 |
| `lib/services/audio_player_service.dart` | 通知渠道名 | Absorb | 胖虎听书 |
| `lib/services/dictionary_service.dart` | User-Agent | Absorb audiobook app | 胖虎听书 |
| `lib/l10n/app_zh.arb` | appTitle | A B S O R B | 胖虎听书 |
| `lib/l10n/app_en.arb` | appTitle | A B S O R B | 胖虎听书 |

---

## 模块4：完善所有汉化

**需求**：补全所有未汉化的英文字符串。

**已发现的未汉化位置**：

### 播放速度相关
- `lib/widgets/card_playback_controls.dart` — 速度按钮标签
- `lib/services/audio_player_service.dart` — 通知栏速度标签 "Speed"

### 设置页面
- `lib/screens/settings_screen.dart`:
  - "Classic wording" → "经典措辞"
  - "Lock rotation" → "锁定屏幕旋转"
  - "Duck brief interruptions" → "短暂中断时降低音量"
  - "Auto-download series" → "自动下载系列"

### 媒体控制
- `lib/services/audio_player_service.dart`:
  - "Previous chapter" → "上一章"
  - "Next chapter" → "下一章"
  - "Bookmark" → "书签"
  - "Saved" → "已保存"

### 其他
- `lib/widgets/clip_editor_sheet.dart` — "Preview ending"
- `lib/widgets/desktop_batch_actions.dart` — "Replace covers" / "Replace details"
- `lib/widgets/card_buttons.dart` — "Show more"
- `lib/screens/admin_library_edit_screen.dart` — 多个管理项
- `lib/screens/stats_screen.dart` — "Nothing listened in $_yirYear yet"

**实施方式**：
1. 将所有硬编码英文字符串提取到 ARB 文件
2. 更新 app_zh.arb 添加中文翻译
3. 更新 app_en.arb 保持一致

---

## 模块5：减少体积 + 按 ABI 分别编译

**需求**：减少安装包体积，分别编译不同架构版本。

**实现方案**：
- 修改 `build-translated-release.yml`，改为 `--split-per-abi` 构建
- 上传3个独立 APK：arm64-v8a、armeabi-v7a、x86_64
- Release 标题标注各版本大小
- 用户根据自己手机架构下载对应版本

**预期效果**：
| 版本 | 预估大小 |
|------|----------|
| arm64-v8a（主流手机） | ~45MB |
| armeabi-v7a（老款手机） | ~40MB |
| x86_64（模拟器） | ~50MB |

---

## 模块6：播放界面改造（中文有声书风格）

**需求**：将播放界面改为中文有声书风格，参考截图。

**界面布局**：
```
┌─────────────────────────────────┐
│  ▾  章节标题（滚动）        📤  │  ← 顶部：返回 + 标题 + 分享
├─────────────────────────────────┤
│                                 │
│      ┌─────────────────┐        │
│      │                 │        │
│      │    封面图片     │        │  ← 大封面（圆角，居中）
│      │   （圆角矩形）  │        │
│      │                 │        │
│      └─────────────────┘        │
│                                 │
│  ⬇下载   1.0x倍速   👍102  💬46  ···│  ← 功能按钮行
│                                 │
│  ◀15 ──●────────────── 15▶      │  ← 进度条 + 快进快退
│  07:27     超高        08:28     │  ← 时间 + 音质标签
│                                 │
│  ≡    ⏮    ▶⏸    ⏭    ⏰      │  ← 底部控制栏
└─────────────────────────────────┘
```

**实现方案**：

### 6.1 新建播放界面
- 创建 `lib/screens/player_screen.dart` — 全屏播放界面
- 背景色：从封面提取主色调（使用 `palette_generator` 包）
- 封面图：圆角矩形，居中显示，带阴影

### 6.2 顶部栏
- 左：下拉箭头（收起播放界面）
- 中：章节标题（跑马灯滚动）
- 右：分享按钮

### 6.3 功能按钮行
- 下载、倍速、书签、笔记、更多（5个按钮）
- 书签：调用原有书签接口 `AudioPlayerService.addBookmark()`
- 笔记：调用原有笔记接口 `AudioPlayerService.addNote()`
- 倍速按钮：点击弹出速度选择面板

### 6.4 进度条
- 自定义滑块样式
- 左右两侧：快退15秒 / 快进15秒按钮
- 下方：当前时间 | 音质标签 | 总时长

### 6.5 底部控制栏
- 播放列表、上一曲、播放/暂停（大按钮）、下一曲、睡眠定时器

### 6.6 从封面提取颜色
- 使用 `palette_generator` 包提取封面主色
- 作为播放界面背景渐变色
- 文字/图标颜色根据背景明暗自动适配

**涉及文件**：
- `lib/screens/player_screen.dart` — 新建全屏播放界面
- `lib/widgets/player_controls.dart` — 新建播放控制组件
- `pubspec.yaml` — 添加 palette_generator 依赖
- `lib/l10n/app_zh.arb` — 新增翻译条目

---

## 实施顺序

1. **模块3：改名胖虎听书**（最简单，先做）
2. **模块4：完善汉化**（独立，可并行）
3. **模块6：播放界面改造**（核心 UI 改造）
4. **模块1：跳过片头片尾**（新功能，集成到新播放界面）
5. **模块5：减少体积 + 分别编译**（构建配置）
6. **模块2：悬浮玻璃导航栏**（最复杂，最后做）
