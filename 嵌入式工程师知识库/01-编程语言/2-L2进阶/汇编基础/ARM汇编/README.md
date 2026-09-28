# ARM汇编

> 上级目录：[01-编程语言](../../../README.md)

## 定位

Cortex-M 寄存器与模式、Thumb 指令、启动文件解读。

## 篇目

| 篇目 | 标签 | 一句话 |
|---|---|---|
| [01-寄存器与模式.md](01-寄存器与模式.md) | 【L2】 | 认全 r0~r15、xPSR、PRIMASK 与 Thread/Handler 双模式分工。 |
| [02-Thumb指令.md](02-Thumb指令.md) | 【L2】 | 工程反汇编最常撞见的指令一次认全，练出看 objdump 手感。 |
| [03-启动文件startup解读.md](03-启动文件startup解读.md) | 【L2】 | 向量表前两项、Reset_Handler 骨架、weak/alias 兜底机制。 |

---

维护约定：笔记命名 `序号-主题.md`；真实截图放 `_images/`；流程/时序/状态/架构图用 PlantUML 内嵌正文，规范见 [图表规范与模板](../../../../00-总览/图表规范与模板.md)。
