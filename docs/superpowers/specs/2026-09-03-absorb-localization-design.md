# Absorb 项目汉化与自动化工作流设计

## 概述
将开源听书项目 `pounat/absorb` 完整汉化，并设置与上游完全相同的自动化工作流，包括自动合并上游、自动构建 APK 和 IPA 文件。

## 项目背景
- **项目名称**: Absorb - 跨平台 Audiobookshelf 客户端
- **技术栈**: Flutter (Dart)
- **上游仓库**: https://github.com/pounat/absorb
- **目标仓库**: https://github.com/workroom2008/absorb (私有)
- **本地路径**: D:\github\absorb

## 需求分析
1. **汉化完善**: 补全中文翻译文件 `app_zh.arb` 中缺失的条目
2. **自动同步**: 设置工作流自动合并上游更改
3. **自动构建**: 设置工作流自动构建 APK 和 IPA 文件
4. **签名配置**: 生成 Android 签名密钥，配置 iOS 证书

## 实现方案

### 1. 仓库设置
- Fork `pounat/absorb` 到 `workroom2008/absorb`
- 设置为私有仓库
- 配置仓库权限和 Secrets

### 2. 翻译完善
**现状分析**:
- 英文文件: 4859 行
- 中文文件: 1462 行
- 缺失约 70% 的翻译条目

**实施步骤**:
1. 比较 `app_en.arb` 和 `app_zh.arb` 的键值对
2. 识别缺失的翻译条目
3. 基于英文原文翻译缺失条目
4. 保持翻译风格一致
5. 测试翻译效果

### 3. 工作流设置
**上游工作流** (4个):
1. `android-release.yml` - Android 构建发布
2. `ios-release.yml` - iOS 构建发布
3. `github-release.yml` - GitHub 发布
4. `all-release.yml` - 完整发布流程

**新增工作流**:
1. `sync-upstream.yml` - 自动同步上游更改
2. `build-translated-release.yml` - 构建汉化版本

### 4. 签名配置
**Android**:
- 生成调试密钥库
- 存储为 GitHub Secrets
- 配置 `key.properties`

**iOS**:
- 使用 Apple 免费开发者证书
- 配置 App Store Connect API 密钥
- 设置临时钥匙串

## 架构设计

### 组件结构
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
│   ├── app_en.arb              # 英文原文
│   └── app_zh.arb              # 完善后的中文翻译
├── android/                    # Android 配置
├── ios/                        # iOS 配置
└── scripts/                    # 构建脚本
```

### 数据流
1. **上游同步**: 定时检查上游更改 → 自动合并到本地
2. **翻译更新**: 比较英文文件 → 补全中文翻译 → 提交更改
3. **构建触发**: 推送代码 → 触发构建 → 生成 APK/IPA
4. **发布管理**: 创建 Release → 上传构建产物

## 实施计划

### 阶段1：仓库设置 (1天)
1. Fork 仓库到 workroom2008
2. 配置仓库权限
3. 设置 GitHub Secrets

### 阶段2：翻译完善 (3-5天)
1. 分析缺失翻译条目
2. 翻译缺失内容
3. 测试翻译效果
4. 提交翻译更改

### 阶段3：工作流配置 (2天)
1. 复制上游工作流
2. 设置自动同步工作流
3. 配置构建工作流
4. 测试工作流

### 阶段4：测试与验证 (1天)
1. 测试自动同步
2. 测试构建流程
3. 验证 APK/IPA 文件
4. 文档更新

## 风险与缓解

### 风险1: 翻译不准确
- **缓解**: 使用专业翻译工具，参考上下文
- **备用**: 建立翻译审核机制

### 风险2: 工作流配置错误
- **缓解**: 在测试分支验证工作流
- **备用**: 逐步部署，先测试后生产

### 风险3: 签名密钥泄露
- **缓解**: 使用 GitHub Secrets，定期轮换
- **备用**: 监控仓库访问日志

## 成功标准
1. 中文翻译完整度 > 95%
2. 自动同步工作流正常运行
3. APK 和 IPA 文件可正常安装
4. 构建时间 < 30分钟
5. 无关键功能缺失

## 后续维护
1. 定期同步上游更改
2. 更新翻译文件
3. 维护签名密钥
4. 监控构建状态