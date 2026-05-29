# MatrixNebulaAegis

[![Build](https://github.com/sansonecreig/12/workflows/Build%20iOS%20Tweak/badge.svg)](https://github.com/sansonecreig/12/actions)

Advanced iOS debug framework for jailbroken devices.

## Features

- 📱 **Device Spoofer** - Change device model
- 🔍 **Memory Viewer** - Hex memory viewer
- 🔎 **Memory Scanner** - Scan and modify values
- 🌐 **Network Interceptor** - Block requests
- 💰 **IAP Interceptor** - Block purchases
- ⏭️ **Ad Skip** - Auto skip ads
- 🔐 **AES Crypto** - Data encryption

## Build

```bash
# Install Theos
git clone https://github.com/theos/theos.git ~/theos

# Build
./build.sh
```

## Auto Build

Push to main branch triggers GitHub Actions build automatically.

## Install

```bash
dpkg -i com.matrix.aegis_4.0.0_iphoneos-arm.deb
```
