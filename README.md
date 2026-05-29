# MatrixAegisLite

[![Build](https://github.com/sansonecreig/12/workflows/Build%20iOS%20Tweak/badge.svg)](https://github.com/sansonecreig/12/actions)

**精简版 iOS 设备伪造插件** - 只专注于设备信息伪造，移除内存扫描等复杂功能，稳定兼容所有 App。

## 功能特性

- 📱 **设备型号切换** - 支持全系列 iPhone/iPad
- 🔐 **Keychain 影子域隔离** - 切换时自动洗机
- 🎯 **双指双击呼出** - 在任意 App 中使用
- ✅ **稳定优先** - 无内存扫描、无内购拦截、无广告跳过

## 使用方法

1. 双指双击任意 App 界面，呼出红色悬浮点
2. 点击悬浮点打开面板
3. 点击"切换设备型号"选择目标设备
4. 手动滑掉 App 并重新打开，设备信息即被伪造

## 构建

```bash
# 本地构建
./build.sh
```

## 自动构建

推送到 main 分支会自动触发 GitHub Actions 构建。

## 安装

```bash
dpkg -i com.matrix.aegis.lite_1.0.0_iphoneos-arm.deb
```
