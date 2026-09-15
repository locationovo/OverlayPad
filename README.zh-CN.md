# OverlayPad

[English](README.md) | [简体中文](README.zh-CN.md)

可自定义虚拟手柄，为触屏上的游戏操作而设计。
适用于UNDERTALE/DELTARUNE以及任意支持手柄的游戏/应用（支持四个方向键）

## 功能

- 长按悬浮球隐藏/恢复控件
- 预设可导出/导入
- 编译时可通过`make DEBUG=1`开启debug控制台

## 要求

- 目标游戏或应用需支持接入手柄（可识别GameController输入），否则虚拟手柄无法生效
- iOS15+
- 在visionOS上可能需要额外的权限声明

## 使用

将`OverlayPad.dylib`注入到目标app中，以下方式均可：

- 注入IPA后重新签名/巨魔（TrollStore）安装
- LiveContainer等侧载环境

## 许可

本项目采用 [LGPL-3.0](LICENSE)。

欢迎fork、二改、打包分发
联系方式：locationovo@outlook.com