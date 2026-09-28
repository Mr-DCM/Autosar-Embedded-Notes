# RTE

> 上级目录：[07-AUTOSAR架构](../../README.md)
> 主等级：L2→L3

## 定位

S/R 与 C/S 端口、Runnable 映射、IOC、生成代码解读。

## 计划笔记

- [x] 01-S-R与C-S端口.md
- [x] 02-Runnable映射.md
- [x] 03-IOC.md
- [x] 04-生成代码解读.md

## 已完稿

| 篇目 | 等级 | 一句话定位 | 前置 |
|---|---|---|---|
| [01-S-R与C-S端口](01-S-R与C-S端口.md) | L2（带内可提前读） | S/R 放数据等人取、C/S 喊一嗓子要回答——SWC 端口选型与语义 | [分层架构](../../1-L1基础/架构总览/01-分层架构.md) |
| [02-Runnable映射](02-Runnable映射.md) | L2→L3 | 四类 RteEvent 如何叫醒 Runnable 并落进 Task | [S-R与C-S端口](01-S-R与C-S端口.md) |
| [03-IOC](03-IOC.md) | L2→L3 | 跨 OS-Application/跨核的 1:1 数据直通通道 | [S-R与C-S端口](01-S-R与C-S端口.md) |
| [04-生成代码解读](04-生成代码解读.md) | L2→L3 | 生成物分工、宏展开直觉、追信号路径、不可手改铁律 | [S-R与C-S端口](01-S-R与C-S端口.md) |

## 建议图表（PlantUML）

- sequence：SWC→RTE→BSW 调用链

---

维护约定：笔记命名 `序号-主题.md`；真实截图放 `_images/`；流程/时序/状态/架构图用 PlantUML 内嵌正文，规范见 [图表规范与模板](../../../00-总览/图表规范与模板.md)。
