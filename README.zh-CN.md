[Português](README.md) · [English](README.en.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [日本語](README.ja.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

# Cockpit Drone - 无人机控制、遥测监控与 3D 仿真系统

基于 Object Pascal（Lazarus / Free Pascal）开发的一体化无人机地面站与 3D 动力学仿真平台。深度集成模拟量游戏手柄/飞行摇杆、高精度 GPS 传感器、低延迟视频图传（H.264 及模拟器共享内存合成画面）、OpenStreetMap 战术电子地图以及多机在线共享世界。

---

## 目录

1. [项目概述](#项目概述)
2. [代码架构](#代码架构)
3. [支持的无人机协议](#支持的无人机协议)
4. [官方 3D 模拟器与多人在线世界](#官方-3d-模拟器与多人在线世界)
5. [操控方式：手柄 vs 键盘](#操控方式手柄-vs-键盘)
6. [编译运行与环境需求](#编译运行与环境需求)
7. [下载编译好的可执行程序](#下载编译好的可执行程序)
8. [联系方式与开源协议](#联系方式与开源协议)

---

## 项目概述

**Cockpit Drone** 采用 UI 与飞控通信线程严格解耦的架构，确保每 50 毫秒高频下发的控制指令和遥测接收不受前端窗口渲染与模态对话框干扰。

核心特性：
- **高安全性飞控循环：** 独立后台线程保障实时性，配备空格键一键断电（Panic）及松油门自动平滑回中悬停保护机制。
- **专业多窗口战术面板：** 飞行姿态仪表、LED 链路状态灯、军工级 HUD 平视投影、动态航迹追踪地图以及视频监控。
- **全栈系统生态：** 内置 6DOF 空气动力学 **3D 飞行模拟器**（`simulador/`）及 PHP/WebSocket 在线多人协作服务器（`PHP/`）。

---

## 官方 3D 模拟器与多人在线世界

> **多人模式入口说明：**  
> 加入**多人共享世界（Multiplayer）**需在**模拟器**（`simulador.exe`）中发起：  
> 1. 打开 `simulador.exe`。  
> 2. 在“共享世界”面板中输入官方服务器地址（`https://maurinsoft.com.br/cockpit/`）与您的呼号昵称，点击**进入**。  
> 3. 方圆 **2 公里**以内的所有在线无人机将实时呈现在战术地图和 3D 画面中。  
> 4. 地面站 **Cockpit Drone**（`drone.exe`）通过本地 `127.0.0.1` 连接模拟器进行全功能遥控。

---

## 下载编译好的可执行程序

直接前往 [`bin/`](bin/) 目录获取开箱即用的安装程序与独立程序：
- **`bin/setup_cockpit_drone_0.41.exe`：** 包含模拟器、座舱与依赖库的完整 Windows 安装包。
- **`bin/drone.exe`：** Cockpit Drone 地面站程序。
- **`bin/simulador.exe`：** 3D 飞行模拟器程序。

---

## 联系方式与开源协议

- **作者：** Marcelo Maurin Martins (marcelomaurinmartins@gmail.com)
- **官方主页：** [Maurinsoft - Cockpit Drone](https://maurinsoft.com.br/wp/projetos-open-source/projeto-cockpit-drone/)
- **开源协议：** 遵循宽松自由开源许可证。
