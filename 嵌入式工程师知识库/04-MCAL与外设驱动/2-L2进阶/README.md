# 2-L2进阶

> 上级目录：[04-MCAL与外设驱动](../README.md)

## 定位

**逐模块推进的主力带。** 九个子目录覆盖 MCAL 各模块（Mcu/Gpt/Icu/Pwm/Adc/Spi/Wdg/CanDrv/LinDrv/Fls/Fee），每个模块都是"原理 + 双平台实现（TC377/S32K）+ MCAL 配置要点"三段式；CDD设计方法论是主业方法论——复杂驱动编写规范、中断挂接、与 BSW/OS 集成，从 L2 起坡（子目录标【L2→L3】）。

- 主标签：**【L2】**（前置：1-L1基础 的 MCAL 总览与 Port/Dio 实践；CDD 为【L2→L3】坡度）
- 何时进：跑通过第一次 Port/Dio 配置，想系统性补齐各模块；
- 何时离开：常用模块（Mcu/Gpt/Adc/Spi/CanDrv/Fls）能在配置工具里独立配置并定位问题、CDD 评审清单会用，即可按需进 [3-L3高级](../3-L3高级/README.md) 或转入 05/06/07 区结合主业实践。

## 子目录

| 目录 | 主等级 | 定位 |
|---|---|---|
| [Mcu模块](Mcu模块/README.md) | 【L2】 | 时钟初始化、RAM 初始化、复位管理。 |
| [Gpt与Icu](Gpt与Icu/README.md) | 【L2】 | Gpt 定时器与 Icu 输入捕获。 |
| [Pwm](Pwm/README.md) | 【L2】 | PWM 原理与双平台实现（S32K eMIOS/FTM、TC377 GTM）。 |
| [Adc](Adc/README.md) | 【L2】 | 转换链路原理与双平台实现（TC377 EVADC、S32K ADC/BCTU）。 |
| [Spi](Spi/README.md) | 【L2】 | SPI 时序与双平台实现（LPSPI、ASCLIN-SPI）。 |
| [Wdg](Wdg/README.md) | 【L2】 | 看门狗原理、双平台实现、与 WdgM 联动。 |
| [CanDrv与LinDrv](CanDrv与LinDrv/README.md) | 【L2】 | MCAL 收发驱动与 CanIf/LinIf 的接口契约。 |
| [Fls与Fee](Fls与Fee/README.md) | 【L2】 | Flash 驱动、Fee 模拟 EEPROM、与 NvM 链路。 |
| [CDD设计方法论](CDD设计方法论/README.md) | 【L2→L3】 | 复杂驱动编写规范、中断挂接、与 BSW/OS 集成。（主业方法论，L2 起坡） |

## 读完去向（L3 带 / 跨区）

- 深水区：DMA 排查与跨平台搬运见 [3-L3高级/DMA专题](../3-L3高级/DMA专题/README.md)；
- 平台纵深（跨区）：[02-芯片与体系结构/2-L2进阶/TC377平台](../../02-芯片与体系结构/2-L2进阶/TC377平台/README.md) 的 GTM/iLLD 笔记与 Pwm/Adc 篇互为地基；
- 主业衔接（跨区）：[05-汽车网络通讯](../../05-汽车网络通讯/README.md)（CanDrv 上接 CanIf 全链路）、[07-AUTOSAR架构](../../07-AUTOSAR架构/README.md)（WdgM/内存栈集成）。

---

维护约定：笔记命名 `序号-主题.md`；真实截图放 `_images/`；流程/时序/状态/架构图用 PlantUML 内嵌正文，规范见 [图表规范与模板](../../00-总览/图表规范与模板.md)。
