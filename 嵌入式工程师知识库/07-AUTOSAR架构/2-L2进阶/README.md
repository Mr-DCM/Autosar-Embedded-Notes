# 2-L2进阶

> 上级目录：[07-AUTOSAR架构](../README.md)

## 定位

**四大栈主线与图纸。** 系统服务栈（Os/EcuM/BswM/WdgM/Det与Dlt）管"开机睡觉与调度监督"；通讯服务栈（Com/PduR/CanSM/NM/CanIf…）管"报文的打包与选路"；内存栈（NvM…）管"掉电不丢"；IO栈（IoHwAb）管"MCAL 与应用的桥"；再加 方法论与ARXML（配置图纸怎么读）与 SchM与调度（Runnable 怎么上 Task）——本带是"配得出 + 排得掉"的工程级主战场。

- 主标签：**【L2】**（前置：1-L1基础 的分层图；通讯/内存栈另需 05 区与 04 区相应地基）
- 何时进：分层概念已入脑、开始在配置工具里配栈或追栈内问题；
- 何时离开：能独立完成一个模块（如 EcuM/NvM）的配置并沿调用链排障，即算出师——之后按问题回查本带。

## 子目录

| 目录 | 主等级 | 定位 |
|---|---|---|
| [方法论与ARXML](方法论与ARXML/README.md) | 【L2】 | ECU 配置结构、容器与参数、ARXML 手读、diff review。 |
| [SchM与调度](SchM与调度/README.md) | 【L2】 | 调度表、Runnable 到 Task 映射。 |
| [系统服务栈](系统服务栈/README.md) | 【L2】 | Os/EcuM/BswM/WdgM/Det/Dlt 服务栈模块（孙目录五枚）。 |
| [通讯服务栈](通讯服务栈/README.md) | 【L2】 | Com/PduR/CanSM/LinSM/CanNm-LinNm/CanIf-LinIf/CanTrcv。 |
| [内存栈](内存栈/README.md) | 【L2】 | NvM 块管理、写队列、冗余、MemIf/Fee/Ea。 |
| [IO栈](IO栈/README.md) | 【L2】 | IoHwAb：MCAL 与 ASW 之间的桥。 |

## 读完去向（L3 带 / 跨区）

- 深水区按需：[3-L3高级](../3-L3高级/README.md)（RTE / 加密栈 / 多核集成——RTE 的 S/R 与 C/S 端口篇可提前读）；
- 底层衔接（跨区）：[05-汽车网络通讯/传输层](../../05-汽车网络通讯/2-L2进阶/传输层/README.md)（CanIf 之下的总线世界）、[04-MCAL与外设驱动](../../04-MCAL与外设驱动/README.md)（MCAL 驱动接口契约）；
- 诊断衔接（跨区）：[06-诊断与标定/Dcm配置](../../06-诊断与标定/2-L2进阶/Dcm配置/README.md)（Dcm 也是服务栈一员）。

---

维护约定：笔记命名 `序号-主题.md`；真实截图放 `_images/`；流程/时序/状态/架构图用 PlantUML 内嵌正文，规范见 [图表规范与模板](../../00-总览/图表规范与模板.md)。
