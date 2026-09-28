# 通讯服务栈

> 上级目录：[07-AUTOSAR架构](../../README.md)
> 主等级：L2

## 定位

Com/PduR/CanSM/LinSM/CanNm-LinNm/CanIf-LinIf/CanTrcv。

## 计划笔记

- [x] 01-Com.md
- [x] 02-PduR.md
- [x] 03-CanSM.md
- [x] 04-LinSM.md
- [x] 05-CanNm-LinNm.md
- [x] 06-CanIf-LinIf.md
- [x] 07-CanTrcv.md

## 已完成笔记

| 序号 | 标题 | 等级 | 前置 | 一句话定位 |
|---|---|---|---|---|
| 01 | [Com](01-Com.md) | L2 | [07区导读](../../00-入门导读/01-AUTOSAR第一课-一座城的分区图.md) | 信号打包进 I-PDU、四种发送模式与 MDT、Deadline Monitor 与失效值 |
| 02 | [PduR](02-PduR.md) | L2 | [01-Com](01-Com.md) | 查表转发的分拣中心：路由表配置走查、PDU/信号网关、确认链反向路由 |
| 03 | [CanSM](03-CanSM.md) | L2 | [01-Com](01-Com.md) | 通道状态机、ComM 请求链、BusOff 两段计时恢复序列 |
| 04 | [LinSM](04-LinSM.md) | L2 | [03-CanSM](03-CanSM.md) | LIN 模式与调度表切换：ScheduleRequest 确认链、goto-sleep 睡眠序列、与 CanSM 差异表 |
| 05 | [CanNm-LinNm](05-CanNm-LinNm.md) | L2 | [01-Com](01-Com.md)、[NM 状态机](../../../05-汽车网络通讯/2-L2进阶/网络管理/02-AUTOSAR-NM状态机.md) | NM 驱动集成层：CanNm 配置体系、ComM→Nm→CanNm 请求链、CBV 与全网不睡排障 |
| 06 | [CanIf-LinIf](06-CanIf-LinIf.md) | L2 | [01-Com](01-Com.md)、[CanDrv 契约](../../../04-MCAL与外设驱动/2-L2进阶/CanDrv与LinDrv/01-CanDrv接口契约.md) | 硬件抽象收口层：HOH/Hth 映射、收发确认三段式链路、Confirmation 断链排障 |
| 07 | [CanTrcv](07-CanTrcv.md) | L2 | [06-CanIf-LinIf](06-CanIf-LinIf.md) | 收发器管理层：三档模式、TJA1145 唤醒传播链、PN 过滤与睡眠电流陷阱 |

## 建议图表（PlantUML）

- sequence：Com→PduR→CanIf→CanDrv→总线 全链路

---

维护约定：笔记命名 `序号-主题.md`；真实截图放 `_images/`；流程/时序/状态/架构图用 PlantUML 内嵌正文，规范见 [图表规范与模板](../../../00-总览/图表规范与模板.md)。
