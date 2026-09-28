# XCP与标定

> 上级目录：[06-诊断与标定](../../README.md)
> 主等级：L2

## 定位

XCP-on-CAN、A2L 文件、CANape 实操。

## 计划笔记

- [x] 01-XCP-on-CAN.md
- [x] 02-A2L文件.md
- [x] 03-CANape实操.md

## 已完成笔记

| 序号 | 标题 | 等级 | 前置 | 一句话定位 |
|---|---|---|---|---|
| 01 | [XCP-on-CAN](01-XCP-on-CAN.md) | L2 | [从诊断仪的一次连接说起](../../00-入门导读/01-从诊断仪的一次连接说起-诊断全景.md) | CTO/DTO 双通道、常用命令表、DAQ vs POLLING、五类 ID 分配与 UDS 共存 |
| 02 | [A2L文件](02-A2L文件.md) | L2 | [XCP-on-CAN](01-XCP-on-CAN.md) | 地址簿+换算表：关键字层级、MEASUREMENT/CHARACTERISTIC 逐字段、map→A2L 流水线与 BYTE_ORDER 陷阱 |
| 03 | [CANape实操](03-CANape实操.md) | L2 | [XCP-on-CAN](01-XCP-on-CAN.md) + [A2L文件](02-A2L文件.md) | 建工程五步、DAQ 列表、RAM/Flash 页切换与固化、TOP5 连不上排查表 |

---

维护约定：笔记命名 `序号-主题.md`；真实截图放 `_images/`；流程/时序/状态/架构图用 PlantUML 内嵌正文，规范见 [图表规范与模板](../../../00-总览/图表规范与模板.md)。
