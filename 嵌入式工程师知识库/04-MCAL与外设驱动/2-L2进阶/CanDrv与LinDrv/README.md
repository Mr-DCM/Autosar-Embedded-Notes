# CanDrv与LinDrv

> 上级目录：[2-L2进阶](../../README.md)
> 主等级：L2

## 定位

MCAL 收发驱动与 CanIf/LinIf 的接口契约。

## 计划笔记

- [x] 01-CanDrv接口契约.md
- [x] 02-LinDrv接口契约.md
- [x] 03-与CanIf-LinIf集成.md
- [x] 04-中断与轮询模式.md

## 已完成笔记

| 序号 | 标题 | 等级 | 前置 | 一句话定位 |
|---|---|---|---|---|
| 01 | [CanDrv接口契约](01-CanDrv接口契约.md) | L2 | [MCAL第一课](../../00-入门导读/01-MCAL第一课-从点灯到分层驱动.md) | CanIf↔CanDrv 双向契约账本、Hth/Hoh、CAN_BUSY 背压语义 |
| 02 | [LinDrv接口契约](02-LinDrv接口契约.md) | L2 | [MCAL第一课](../../00-入门导读/01-MCAL第一课-从点灯到分层驱动.md) | 帧头/响应两段式、M2A/A2M 方向、帧槽与调度表 |
| 03 | [与CanIf-LinIf集成](03-与CanIf-LinIf集成.md) | L2 | [01](01-CanDrv接口契约.md)+[02](02-LinDrv接口契约.md) | 一次发送全链路时序、ControllerMode 状态机、初始化铁律顺序 |
| 04 | [中断与轮询模式](04-中断与轮询模式.md) | L2 | [03-与CanIf-LinIf集成](03-与CanIf-LinIf集成.md) | TX/RX/BusOff 事件搬运两机制、时间片安排、中断配置来源 |

## 建议图表（PlantUML）

- sequence：一帧 CAN 从 CanIf 到总线的完整路径（已落进 [03-与CanIf-LinIf集成](03-与CanIf-LinIf集成.md)）

---

维护约定：笔记命名 `序号-主题.md`；真实截图放 `_images/`；流程/时序/状态/架构图用 PlantUML 内嵌正文，规范见 [图表规范与模板](../../../00-总览/图表规范与模板.md)。
