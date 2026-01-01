# TProxyShell (Personal Mod)

这是一个基于 **sing-box** 的 Android 透明代理模块。
本项目 Fork 自 [CHIZI-0618/AndroidTProxyShell](https://github.com/CHIZI-0618/AndroidTProxyShell)

> **说明**：本项目主要用于个人学习和自用。代码经过了调整以适配我的需求，不保证在所有设备上都能完美运行。

## 目录结构

安装后，模块文件位于 `/data/adb/box/`：

* `bin/` - 核心二进制文件
* `conf/` - 配置文件 (`config.json` 和 `settings.ini`)
* `scripts/` - 功能脚本
* `run/` - 运行时的缓存、日志和 PID 文件

## 配置

    * **核心配置**：修改 `/data/adb/box/conf/config.json` (填入你的 sing-box 节点配置)。
    * **脚本设置**：修改 `/data/adb/box/conf/settings.ini` (设置代理模式、端口、黑白名单等)。

## 致谢

* 感谢 [CHIZI-0618](https://github.com/CHIZI-0618) 提供的原版项目。
* 感谢 sing-box 开发者。
