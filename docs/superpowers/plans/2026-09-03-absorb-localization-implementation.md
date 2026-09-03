# Absorb 项目汉化与自动化工作流实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完整汉化 Absorb 项目，设置与上游完全相同的自动化工作流，包括自动合并上游、自动构建 APK 和 IPA 文件。

**Architecture:** Fork 上游仓库，完善中文翻译文件，复制上游工作流，添加自动同步工作流，配置签名密钥。

**Tech Stack:** Flutter (Dart), GitHub Actions, Android/iOS 构建工具

**Spec:** `docs/superpowers/specs/2026-09-03-absorb-localization-design.md`

## Global Constraints
- 保持与上游代码风格一致
- 使用现有的 Flutter 构建系统
- 所有工作流必须经过测试验证
- 签名密钥使用 GitHub Secrets 存储
- 翻译保持专业术语一致性

---

## 文件结构映射

```
workroom2008/absorb/
├── .github/workflows/
│   ├── android-release.yml      # 复制上游
│   ├── ios-release.yml          # 复制上游
│   ├── github-release.yml       # 复制上游
│   ├── all-release.yml          # 复制上游
│   ├── sync-upstream.yml        # 新增：自动同步
│   └── build-translated-release.yml  # 新增：构建汉化版
├── lib/l10n/
│   ├── app_en.arb              # 英文原文（参考）
│   └── app_zh.arb              # 完善后的中文翻译
├── android/                    # Android 配置
│   └── key.properties          # 签名配置
├── ios/                        # iOS 配置
└── scripts/                    # 构建脚本
```

---

### Task 1: Fork 仓库并配置 GitHub Secrets

**Files:**
- 创建: `.github/workflows/sync-upstream.yml`
- 创建: `.github/workflows/build-translated-release.yml`
- 修改: `android/key.properties` (如果存在)

**Interfaces:**
- Consumes: GitHub CLI (`gh`), 上游仓库 URL
- Produces: Fork 的仓库，配置的 Secrets

- [ ] **Step 1: Fork 上游仓库**

```bash
# Fork pounat/absorb 到 workroom2008/absorb
gh repo fork pounat/absorb --clone=false --remote=true
```

Run: `gh repo view workroom2008/absorb`
Expected: 显示仓库信息

- [ ] **Step 2: 设置仓库为私有**

```bash
# 设置仓库为私有
gh repo edit workroom2008/absorb --visibility private
```

Run: `gh repo view workroom2008/absorb --json visibility`
Expected: `{"visibility": "private"}`

- [ ] **Step 3: 生成 Android 签名密钥**

```bash
# 生成 Android 签名密钥库
keytool -genkey -v -keystore absorb-upload-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias absorb-upload
```

Run: `ls -la absorb-upload-key.jks`
Expected: 文件存在

- [ ] **Step 4: 存储签名密钥为 GitHub Secret**

```bash
# 将密钥库转换为 base64
base64 -i absorb-upload-key.jks -o absorb-upload-key-base64.txt

# 存储为 GitHub Secret
gh secret set ANDROID_KEYSTORE_BASE64 < absorb-upload-key-base64.txt
gh secret set ANDROID_KEYSTORE_PASSWORD "你的密钥库密码"
gh secret set ANDROID_KEY_PASSWORD "你的密钥密码"
gh secret set ANDROID_KEY_ALIAS "absorb-upload"
```

Run: `gh secret list | grep ANDROID`
Expected: 显示4个 ANDROID 相关 secrets

- [ ] **Step 5: 提交更改**

```bash
git add .
git commit -m "chore: 添加签名密钥配置"
```

---

### Task 2: 完善中文翻译文件

**Files:**
- 修改: `lib/l10n/app_zh.arb`
- 创建: `scripts/compare-locales.py` (可选)

**Interfaces:**
- Consumes: `lib/l10n/app_en.arb` (英文原文)
- Produces: 完善后的 `lib/l10n/app_zh.arb`

- [ ] **Step 1: 比较英文和中文翻译文件**

```python
#!/usr/bin/env python3
# 比较英文和中文翻译文件，找出缺失的条目
import json
import sys

def compare_locales(en_file, zh_file):
    with open(en_file, 'r', encoding='utf-8') as f:
        en_data = json.load(f)
    with open(zh_file, 'r', encoding='utf-8') as f:
        zh_data = json.load(f)
    
    missing = []
    for key in en_data:
        if key not in zh_data and not key.startswith('@'):
            missing.append(key)
    
    return missing

if __name__ == "__main__":
    missing = compare_locales('lib/l10n/app_en.arb', 'lib/l10n/app_zh.arb')
    print(f"缺失 {len(missing)} 个翻译条目:")
    for key in missing[:10]:  # 只显示前10个
        print(f"  - {key}")
    if len(missing) > 10:
        print(f"  ... 还有 {len(missing)-10} 个")
```

Run: `python scripts/compare-locales.py`
Expected: 显示缺失的翻译条目数量

- [ ] **Step 2: 翻译缺失条目**

```python
# 翻译缺失的条目
# 基于英文原文翻译，保持专业术语一致性
# 示例翻译：
missing_translations = {
    "listsNone": "暂无收藏或播放列表",
    "listsNoneHint": "收藏和播放列表在你的 Audiobookshelf 服务器上创建，会显示在这里。",
    "listsLoadFailed": "无法加载你的列表",
    "listsLoadFailedHint": "Absorb 无法连接到你的服务器获取收藏和播放列表。",
    # ... 继续翻译其他缺失条目
}
```

Run: `python scripts/translate-missing.py`
Expected: 生成更新后的中文翻译文件

- [ ] **Step 3: 验证翻译完整性**

```bash
# 再次比较，确保没有缺失
python scripts/compare-locales.py
```

Run: `python scripts/compare-locales.py`
Expected: 缺失条目数量为 0

- [ ] **Step 4: 测试翻译效果**

```bash
# 运行 Flutter 国际化生成
flutter gen-l10n
```

Run: `flutter gen-l10n`
Expected: 成功生成本地化文件

- [ ] **Step 5: 提交翻译更改**

```bash
git add lib/l10n/app_zh.arb
git commit -m "feat: 完善中文翻译，补全缺失条目"
```

---

### Task 3: 复制上游工作流文件

**Files:**
- 创建: `.github/workflows/android-release.yml`
- 创建: `.github/workflows/ios-release.yml`
- 创建: `.github/workflows/github-release.yml`
- 创建: `.github/workflows/all-release.yml`

**Interfaces:**
- Consumes: 上游工作流文件
- Produces: 本地工作流文件

- [ ] **Step 1: 复制 Android 构建工作流**

```bash
# 从上游仓库复制工作流文件
cp ../absorb-upstream/.github/workflows/android-release.yml .github/workflows/
```

Run: `ls -la .github/workflows/android-release.yml`
Expected: 文件存在

- [ ] **Step 2: 复制 iOS 构建工作流**

```bash
cp ../absorb-upstream/.github/workflows/ios-release.yml .github/workflows/
```

Run: `ls -la .github/workflows/ios-release.yml`
Expected: 文件存在

- [ ] **Step 3: 复制 GitHub 发布工作流**

```bash
cp ../absorb-upstream/.github/workflows/github-release.yml .github/workflows/
```

Run: `ls -la .github/workflows/github-release.yml`
Expected: 文件存在

- [ ] **Step 4: 复制完整发布工作流**

```bash
cp ../absorb-upstream/.github/workflows/all-release.yml .github/workflows/
```

Run: `ls -la .github/workflows/all-release.yml`
Expected: 文件存在

- [ ] **Step 5: 提交工作流文件**

```bash
git add .github/workflows/
git commit -m "chore: 复制上游构建工作流"
```

---

### Task 4: 创建自动同步工作流

**Files:**
- 创建: `.github/workflows/sync-upstream.yml`

**Interfaces:**
- Consumes: 上游仓库 URL，GitHub CLI
- Produces: 自动同步工作流

- [ ] **Step 1: 创建同步工作流文件**

```yaml
name: Sync Fork from Upstream

on:
  schedule:
    # 每天北京时间 14:00 检查上游（UTC 06:00）
    - cron: '0 6 * * *'
  workflow_dispatch:

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          ref: main
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Sync upstream changes
        run: |
          # 添加上游仓库
          git remote add upstream https://github.com/pounat/absorb.git
          git fetch upstream
          
          # 检查是否有新的提交
          LOCAL=$(git rev-parse HEAD)
          UPSTREAM=$(git rev-parse upstream/main)
          
          if [ "$LOCAL" != "$UPSTREAM" ]; then
            echo "发现上游更新，正在同步..."
            git rebase upstream/main
            git push origin main
            echo "同步完成"
          else
            echo "已是最新版本"
          fi

      - name: Notify on conflict
        if: failure()
        run: |
          echo "同步冲突，请手动解决"
          # 可以添加通知逻辑
```

Run: `cat .github/workflows/sync-upstream.yml`
Expected: 显示工作流内容

- [ ] **Step 2: 测试同步工作流**

```bash
# 手动触发工作流测试
gh workflow run "Sync Fork from Upstream" --repo workroom2008/absorb
```

Run: `gh run list --repo workroom2008/absorb --limit 1`
Expected: 显示工作流运行状态

- [ ] **Step 3: 提交同步工作流**

```bash
git add .github/workflows/sync-upstream.yml
git commit -m "ci: 添加自动同步上游工作流"
```

---

### Task 5: 创建构建汉化版本工作流

**Files:**
- 创建: `.github/workflows/build-translated-release.yml`

**Interfaces:**
- Consumes: Flutter 构建系统，签名密钥
- Produces: 汉化版本的 APK 和 IPA

- [ ] **Step 1: 创建构建工作流文件**

```yaml
name: Build Translated Release

on:
  push:
    branches: [main]
    paths:
      - 'lib/l10n/**'
  workflow_dispatch:

jobs:
  build-android:
    name: Build Android APK
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
      
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      
      - name: Read pubspec version
        id: version
        run: |
          RAW=$(grep '^version:' pubspec.yaml | sed 's/version: *//')
          VERSION_NAME="${RAW%%+*}"
          BUILD="${RAW##*+}"
          echo "tag=v${VERSION_NAME}-zh-${BUILD}" >> "$GITHUB_OUTPUT"
          echo "fname=absorb-${RAW//+/-}-zh" >> "$GITHUB_OUTPUT"
      
      - name: Setup Android signing
        env:
          ANDROID_KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          ANDROID_KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          ANDROID_KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
          ANDROID_KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
        run: |
          echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > "$RUNNER_TEMP/absorb-upload-key.jks"
          cat > android/key.properties <<EOF
          storePassword=$ANDROID_KEYSTORE_PASSWORD
          keyPassword=$ANDROID_KEY_PASSWORD
          keyAlias=$ANDROID_KEY_ALIAS
          storeFile=$RUNNER_TEMP/absorb-upload-key.jks
          EOF
      
      - name: Build APK
        run: flutter build apk --release --flavor github
      
      - name: Upload APK
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          VERSION_TAG: ${{ steps.version.outputs.tag }}
        run: |
          APK_PATH=$(ls build/app/outputs/apk/github/release/*.apk | head -1)
          mv "$APK_PATH" "build/app/outputs/apk/github/release/${{ steps.version.outputs.fname }}.apk"
          gh release create "$VERSION_TAG" "build/app/outputs/apk/github/release/${{ steps.version.outputs.fname }}.apk" --title "$VERSION_TAG" --notes "汉化版本"
```

Run: `cat .github/workflows/build-translated-release.yml`
Expected: 显示工作流内容

- [ ] **Step 2: 测试构建工作流**

```bash
# 手动触发构建测试
gh workflow run "Build Translated Release" --repo workroom2008/absorb
```

Run: `gh run list --repo workroom2008/absorb --limit 1`
Expected: 显示工作流运行状态

- [ ] **Step 3: 提交构建工作流**

```bash
git add .github/workflows/build-translated-release.yml
git commit -m "ci: 添加构建汉化版本工作流"
```

---

### Task 6: 配置 iOS 构建环境

**Files:**
- 创建: `ios/ExportOptions.plist` (如果不存在)
- 修改: `.github/workflows/ios-release.yml`

**Interfaces:**
- Consumes: Apple 开发者账户，App Store Connect API
- Produces: iOS 构建配置

- [ ] **Step 1: 创建 ExportOptions.plist 文件**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>3W9C9PWP64</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
```

Run: `cat ios/ExportOptions.plist`
Expected: 显示 plist 内容

- [ ] **Step 2: 配置 iOS 构建工作流**

```yaml
# 在 ios-release.yml 中添加以下步骤
- name: Build IPA
  run: flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

Run: `grep -A 5 "Build IPA" .github/workflows/ios-release.yml`
Expected: 显示构建步骤

- [ ] **Step 3: 测试 iOS 构建**

```bash
# 本地测试 iOS 构建
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

Run: `ls -la build/ios/ipa/`
Expected: 生成 IPA 文件

- [ ] **Step 4: 提交 iOS 配置**

```bash
git add ios/ .github/workflows/ios-release.yml
git commit -m "chore: 配置 iOS 构建环境"
```

---

### Task 7: 测试完整工作流

**Files:**
- 无新文件，测试现有工作流

**Interfaces:**
- Consumes: 所有已创建的工作流
- Produces: 验证报告

- [ ] **Step 1: 测试自动同步**

```bash
# 触发同步工作流
gh workflow run "Sync Fork from Upstream" --repo workroom2008/absorb

# 等待完成
sleep 60

# 检查状态
gh run list --repo workroom2008/absorb --limit 1
```

Run: `gh run list --repo workroom2008/absorb --limit 1`
Expected: 工作流成功完成

- [ ] **Step 2: 测试 Android 构建**

```bash
# 触发 Android 构建
gh workflow run "Build Translated Release" --repo workroom2008/absorb

# 等待完成
sleep 300

# 检查状态
gh run list --repo workroom2008/absorb --limit 1
```

Run: `gh run list --repo workroom2008/absorb --limit 1`
Expected: 工作流成功完成

- [ ] **Step 3: 验证构建产物**

```bash
# 下载并验证 APK 文件
gh release download v1.0.0-zh --pattern "*.apk" --dir ./artifacts

# 检查文件
ls -la artifacts/
```

Run: `ls -la artifacts/`
Expected: APK 文件存在

- [ ] **Step 4: 创建测试报告**

```bash
# 生成测试报告
echo "工作流测试报告" > test-report.md
echo "1. 自动同步: 通过" >> test-report.md
echo "2. Android 构建: 通过" >> test-report.md
echo "3. iOS 构建: 待测试" >> test-report.md
```

Run: `cat test-report.md`
Expected: 显示测试报告

- [ ] **Step 5: 提交测试报告**

```bash
git add test-report.md
git commit -m "docs: 添加工作流测试报告"
```

---

### Task 8: 文档更新和最终提交

**Files:**
- 修改: `README.md` (添加中文说明)
- 创建: `CHANGELOG.md`

**Interfaces:**
- Consumes: 所有已完成的任务
- Produces: 完整的项目文档

- [ ] **Step 1: 更新 README.md**

```markdown
# Absorb - 中文版

A cross platform Audiobookshelf client for Android and iOS

## 功能特性
- 跨平台支持 (Android/iOS)
- 中文界面
- 自动同步上游更新
- 自动构建发布版本

## 安装使用
1. 从 GitHub Releases 下载最新版本
2. 或使用包管理器安装

## 开发构建
```bash
# 克隆仓库
git clone https://github.com/workroom2008/absorb.git

# 安装依赖
flutter pub get

# 运行应用
flutter run
```

## 自动工作流
- 每天自动检查上游更新
- 推送代码自动触发构建
- 自动发布到 GitHub Releases
```

Run: `head -20 README.md`
Expected: 显示更新后的 README

- [ ] **Step 2: 创建 CHANGELOG.md**

```markdown
# Changelog

## [1.0.0-zh] - 2026-09-03
### Added
- 完整中文翻译
- 自动同步上游工作流
- 自动构建工作流
- Android 签名配置

### Changed
- 更新中文界面文本
- 优化构建流程

### Fixed
- 修复翻译缺失问题
```

Run: `cat CHANGELOG.md`
Expected: 显示 CHANGELOG 内容

- [ ] **Step 3: 最终提交**

```bash
git add README.md CHANGELOG.md
git commit -m "docs: 更新项目文档"
```

- [ ] **Step 4: 推送到远程仓库**

```bash
git push origin main
```

Run: `git status`
Expected: 显示推送成功

---

## 执行选项

**Plan complete and saved to `docs/superpowers/plans/2026-09-03-absorb-localization-implementation.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - 我为每个任务分发一个新的子代理，任务之间进行审查，快速迭代

**2. Inline Execution** - 在当前会话中使用 executing-plans 执行任务，批量执行并设置检查点

**你选择哪种方式？**