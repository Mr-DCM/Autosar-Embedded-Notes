# 网络管理

> 上级目录：[2-L2进阶](../../README.md)
> 主等级：L2

## 定位

OSEK NM vs AUTOSAR NM、睡眠与假醒、部分网络。

## 计划笔记

- [x] 01-OSEK-NM.md
- [x] 02-AUTOSAR-NM状态机.md
- [x] 03-睡眠与假醒.md
- [x] 04-部分网络.md

## 已完成笔记

| 序号 | 标题 | 等级 | 前置 | 一句话定位 |
|---|---|---|---|---|
| 01 | [OSEK-NM](01-OSEK-NM.md) | L2 | [从一帧CAN报文说起](../../00-入门导读/01-从一帧CAN报文说起-车载网络全景.md) | 逻辑环+令牌传递的第一代网络管理，NM-Off/On/Shutdown 标准口径与跳边算法 |
| 02 | [AUTOSAR-NM状态机](02-AUTOSAR-NM状态机.md) | L2 | [01-OSEK-NM](01-OSEK-NM.md) | 三模式三状态全图、RMS 意义、CBV 位表、CanNm 超时四件套配置主业 |
| 03 | [睡眠与假醒](03-睡眠与假醒.md) | L2 | [02-AUTOSAR-NM状态机](02-AUTOSAR-NM状态机.md) | 整机睡眠流水线（CanNm→CanSM→EcuM→MCU）、假醒来源表与排障路径 |
| 04 | [部分网络](04-部分网络.md) | L2→L3 | [02-AUTOSAR-NM状态机](02-AUTOSAR-NM状态机.md) | PNC 位图与请求应答闭环、CanNm/Com/ComM 与 IPduGroup 联动，点到即止 |

## 建议图表（PlantUML）

- stateDiagram：AUTOSAR NM 状态机

---

维护约定：笔记命名 `序号-主题.md`；真实截图放 `_images/`；流程/时序/状态/架构图用 PlantUML 内嵌正文，规范见 [图表规范与模板](../../../00-总览/图表规范与模板.md)。
