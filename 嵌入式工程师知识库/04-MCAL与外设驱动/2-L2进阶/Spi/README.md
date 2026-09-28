# Spi

> 上级目录：[2-L2进阶](../../README.md)
> 主等级：L2

## 定位

SPI 时序与双平台实现（LPSPI、ASCLIN-SPI）。

## 计划笔记

- [x] 01-SPI时序.md
- [x] 02-S32K-LPSPI.md
- [x] 03-TC377-ASCLIN-SPI.md
- [x] 04-MCAL配置要点.md

## 已完成笔记

| 序号 | 标题 | 等级 | 前置 | 一句话定位 |
|---|---|---|---|---|
| 01 | [SPI时序](01-SPI时序.md) | L2 | [MCAL第一课](../../00-入门导读/01-MCAL第一课-从点灯到分层驱动.md) | 四线/四模式/全双工本质，读手册配 MCAL 不再靠猜 |
| 02 | [S32K-LPSPI](02-S32K-LPSPI.md) | L2 | [01-SPI时序](01-SPI时序.md) | FIFO 与水线、TCF 完成判定、片选时序参数与从机匹配 |
| 03 | [TC377-ASCLIN-SPI](03-TC377-ASCLIN-SPI.md) | L2 | [01-SPI时序](01-SPI时序.md) | ASC/LIN/SPI 三合一复用、输入源选择、与 QSPI 渊源 |
| 04 | [MCAL配置要点](04-MCAL配置要点.md) | L2 | [02](02-S32K-LPSPI.md)+[03](03-TC377-ASCLIN-SPI.md) | Channel→Job→Sequence 三级结构与 IB/EB、同步/异步取舍 |

---

维护约定：笔记命名 `序号-主题.md`；真实截图放 `_images/`；流程/时序/状态/架构图用 PlantUML 内嵌正文，规范见 [图表规范与模板](../../../00-总览/图表规范与模板.md)。
