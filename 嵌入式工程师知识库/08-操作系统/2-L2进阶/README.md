# 2-L2进阶

> 上级目录：[08-操作系统](../README.md)

## 定位

**实现与主业落点。** OSEK与AUTOSAR-OS 是汽车人的正业——OSEK 内核本质（静态任务、事件与资源、优先级天花板）与商业 OS 对比，"怎么在 ECU 里配出来"归 07 区 Os 篇，两区互链；FreeRTOS 用开源实现当教材，把 L1 带学的三大件逐一对照（任务/调度/同步/中断/heap 方案/源码）；RT-Thread、VxWorks 各一篇概览，认门牌即可。

- 主标签：**【L2】**（前置：1-L1基础 的 RTOS通用原理，三大件概念已入脑；OSEK 篇另需 [07 区架构总览](../../07-AUTOSAR架构/1-L1基础/架构总览/README.md) 的分层图）
- 何时进：裸机三板斧与内核三大件概念已通，开始追问"项目里这个 OS 内核到底怎么工作"；
- 何时离开：能讲清 OSEK 与 FreeRTOS 在任务创建时机/静态 vs 动态/资源保护上的差异、能沿 FreeRTOS 源码找到一次上下文切换，即算出师。

## 子目录

| 目录 | 主等级 | 定位 |
|---|---|---|
| [OSEK与AUTOSAR-OS](OSEK与AUTOSAR-OS/README.md) | 【L2】 | OSEK 内核本质、AUTOSAR OS 扩展、商业实现对比。 |
| [FreeRTOS](FreeRTOS/README.md) | 【L2】 | 对比学习用：任务/调度/同步/中断/heap 方案/源码。 |
| [RT-Thread](RT-Thread/README.md) | 【L2】 | 概览。 |
| [VxWorks](VxWorks/README.md) | 【L2→L3】 | 概览。 |

## 读完去向（L3 带 / 跨区）

- 跨界方向按需：[3-L3高级/嵌入式Linux](../3-L3高级/嵌入式Linux/README.md)（概念+清单为主，点到即止）；
- 主业衔接（跨区）：[07-AUTOSAR架构/2-L2进阶/系统服务栈/Os](../../07-AUTOSAR架构/2-L2进阶/系统服务栈/Os/README.md)——OSEK 原理读完后，去 07 区看它在 ECU 里的集成配置五专篇。

---

维护约定：笔记命名 `序号-主题.md`；真实截图放 `_images/`；流程/时序/状态/架构图用 PlantUML 内嵌正文，规范见 [图表规范与模板](../../00-总览/图表规范与模板.md)。
