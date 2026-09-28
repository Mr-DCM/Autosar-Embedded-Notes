# 04-MCAL与外设驱动

> 上级目录：[嵌入式工程师知识库](../README.md)

## 定位

短板区，P0 优先：MCAL 各模块 + 双平台实现对照 + CDD 设计方法论，按 L1~L3 分带组织——先用导读和总览建立分层直觉，再用 Port/Dio 热身动手，L2 带逐模块推进，DMA 深水区点到即止。

## 四带结构

| 带 | 定位 |
|---|---|
| [00-入门导读](00-入门导读/README.md) | 半天入门地图：从一次点灯调用链看懂 MCAL 分层、配置工具生成流程。 |
| [1-L1基础](1-L1基础/README.md) | 地基+热身：MCAL 总览（L1→L2 桥接）、驱动分层思想、Port 与 Dio。 |
| [2-L2进阶](2-L2进阶/README.md) | 逐模块推进：Mcu/Gpt/Icu/Pwm/Adc/Spi/Wdg/CanDrv/LinDrv/Fls/Fee + CDD 设计方法论（主业方法论，L2 起坡）。 |
| [3-L3高级](3-L3高级/README.md) | 深水区参考层：DMA 专题（L2→L3 点到即止）。 |

## 入门坡道（起读序列）

1. [00-入门导读](00-入门导读/README.md)（1 篇）：一次 Dio_WriteChannel 的全链路 + 配置生成流程 5 步直觉，先建地图；
2. [1-L1基础/MCAL总览](1-L1基础/MCAL总览/README.md)：先搞清 MCAL 在分层中的位置、与 iLLD/RTD 的关系、配置生成流程；
3. [1-L1基础/Port与Dio](1-L1基础/Port与Dio/README.md)：最简单的两个模块热身，跑通引脚配置与读写；
4. [2-L2进阶/Mcu模块](2-L2进阶/Mcu模块/README.md)：时钟与复位初始化，理解工程从哪一行开始跑；
5. 再按 [2-L2进阶/Gpt与Icu](2-L2进阶/Gpt与Icu/README.md)、[2-L2进阶/Pwm](2-L2进阶/Pwm/README.md)、[2-L2进阶/Adc](2-L2进阶/Adc/README.md) 逐模块推进；对照 [02-芯片与体系结构/1-L1基础/S32K平台](../02-芯片与体系结构/1-L1基础/S32K平台/README.md) 笔记在 RTD 上把 Port/Dio/Mcu 配置实践一遍。

## 各带子目录明细

### 1-L1基础

| 目录 | 主等级 | 定位 |
|---|---|---|
| [MCAL总览](1-L1基础/MCAL总览/README.md) | 【L1→L2】 | MCAL 分层位置、与 iLLD/RTD 的关系、配置生成流程。（L1→L2 桥接） |
| [驱动分层思想](1-L1基础/驱动分层思想/README.md) | 【L1→L2】 | 寄存器层到 IoHwAb 的分层与移植性。 |
| [Port与Dio](1-L1基础/Port与Dio/README.md) | 【L1→L2】 | Port 引脚配置与 Dio 接口。 |

### 2-L2进阶

| 目录 | 主等级 | 定位 |
|---|---|---|
| [Mcu模块](2-L2进阶/Mcu模块/README.md) | 【L2】 | 时钟初始化、RAM 初始化、复位管理。 |
| [Gpt与Icu](2-L2进阶/Gpt与Icu/README.md) | 【L2】 | Gpt 定时器与 Icu 输入捕获。 |
| [Pwm](2-L2进阶/Pwm/README.md) | 【L2】 | PWM 原理与双平台实现（S32K eMIOS/FTM、TC377 GTM）。 |
| [Adc](2-L2进阶/Adc/README.md) | 【L2】 | 转换链路原理与双平台实现（TC377 EVADC、S32K ADC/BCTU）。 |
| [Spi](2-L2进阶/Spi/README.md) | 【L2】 | SPI 时序与双平台实现（LPSPI、ASCLIN-SPI）。 |
| [Wdg](2-L2进阶/Wdg/README.md) | 【L2】 | 看门狗原理、双平台实现、与 WdgM 联动。 |
| [CanDrv与LinDrv](2-L2进阶/CanDrv与LinDrv/README.md) | 【L2】 | MCAL 收发驱动与 CanIf/LinIf 的接口契约。 |
| [Fls与Fee](2-L2进阶/Fls与Fee/README.md) | 【L2】 | Flash 驱动、Fee 模拟 EEPROM、与 NvM 链路。 |
| [CDD设计方法论](2-L2进阶/CDD设计方法论/README.md) | 【L2→L3】 | 复杂驱动编写规范、中断挂接、与 BSW/OS 集成。（主业方法论，L2 起坡） |

### 3-L3高级

| 目录 | 主等级 | 定位 |
|---|---|---|
| [DMA专题](3-L3高级/DMA专题/README.md) | 【L2→L3】 | DMA 原理与双平台实现（TC377 DMA、S32K eDMA/DMAMUX）。（L2→L3 点到即止） |

---

维护约定：笔记命名 `序号-主题.md`；真实截图放 `_images/`；流程/时序/状态/架构图用 PlantUML 内嵌正文，规范见 [图表规范与模板](../00-总览/图表规范与模板.md)。
标签说明：子目录难度标签为写作规划，笔记落笔时以头部行为准；归带从主，个别深水篇在篇级头部行标更高等级。
