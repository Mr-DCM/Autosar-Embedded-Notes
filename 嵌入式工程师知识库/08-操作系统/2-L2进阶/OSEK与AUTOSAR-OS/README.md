# OSEK与AUTOSAR-OS

> 上级目录：[08-操作系统](../../README.md)
> 主等级：L2

## 定位

OSEK 内核本质、AUTOSAR OS 扩展、商业实现对比。本目录聚焦内核原理本质；"怎么在 ECU 里集成配置 Os"的专篇在 [07-AUTOSAR架构/2-L2进阶/系统服务栈/Os](../../../07-AUTOSAR架构/2-L2进阶/系统服务栈/Os/README.md)，两区互链不重复。

## 计划笔记

- [x] 01-OSEK内核.md
- [x] 02-AUTOSAR-OS扩展.md
- [x] 03-商业实现对比.md

## 已完成

| 笔记 | 等级 | 一句话 |
|---|---|---|
| [01-OSEK内核.md](01-OSEK内核.md) | 【L2】 | 静态内核四要素+天花板协议——一切编译期定死，换可证明的实时性 |
| [02-AUTOSAR-OS扩展.md](02-AUTOSAR-OS扩展.md) | 【L2】 | OSEK 超集四件套：ScheduleTable/分区/多核 SpinLock/多源 Counter，SC1~SC4 按需缩放 |
| [03-商业实现对比.md](03-商业实现对比.md) | 【L2】 | RTA-CAR/MICROSAR/EB tresos 一句定位+选型考量：语义跟标准走，体验跟工具链走 |

---

维护约定：笔记命名 `序号-主题.md`；真实截图放 `_images/`；流程/时序/状态/架构图用 PlantUML 内嵌正文，规范见 [图表规范与模板](../../../00-总览/图表规范与模板.md)。
