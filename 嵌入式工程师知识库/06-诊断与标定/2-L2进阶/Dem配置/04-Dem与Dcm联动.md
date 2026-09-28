# 04-Dem与Dcm联动

> 一句话定位：19/14 是嘴，Dem 是账本——本篇把"读故障/清故障"从诊断仪报文到 Dem 接口的调用链一次走通，再给一张"读不到 DTC"的分叉排查图。
> 等级：L2 ｜ 前置：[01-事件与DTC](01-事件与DTC.md) + [DSL-DSD-DSP分层](../Dcm配置/01-DSL-DSD-DSP分层.md)

## 原理

诊断仪永远不直接碰 Dem——它说 UDS（19/14），Dcm 的 DSP 层把这些 SID 翻译成 Dem 接口调用，再把结果拼回 UDS 报文。**联动的本质是一张翻译对照表：Dcm 服务子功能 ↔ Dem 查询接口**。

```plantuml
@startuml
title 19 02 / 14 的完整调用链（读故障→清故障）
skinparam defaultFontName "Microsoft YaHei"
autonumber on
participant "诊断仪" as T
participant "Dcm\nDSD 查表" as DSD
participant "Dcm\nDSP(19/14)" as DSP
participant "Dem" as DEM
database "事件存储器\n(Primary)" as MEM

T -> DSD : 19 02 FF（报所有 confirmed DTC）
DSD -> DSP : 子服务 0x02 分发
DSP -> DEM : Dem_ReadDTCInformation\n·ReportDTCByStatusMask(0x08)
DEM -> MEM : 按掩码过滤事件
MEM --> DEM : DTC+状态 列表
DEM --> DSP : 匹配条目计数+数据
DSP --> T : 59 02 + 计数 + (DTC+status)*

T -> DSD : 14 FF FF FF（清全部）
DSD -> DSP : SID 14 分发
DSP -> DEM : Dem_ClearDTC(FF FF FF)
MEM -> MEM : 删记录/清状态位\n重置 aging·occurrence
DEM --> DSP : E_OK（清除结果）
note right of MEM
  清除结果按 SWS 有三种：
  OK / 不支持该组 / 繁忙(进行中)
  繁忙时 Dcm 回 0x22 而非硬等
end note
DSP --> T : 54（正响应）
@enduml
```

## 详解

### 走查表：Dcm 服务 ↔ Dem 接口

| 诊断仪发出 | Dcm DSP 动作 | Dem 接口（SWS 通用名） | 返回里有什么 |
|---|---|---|---|
| 19 01 | 读 DTC 状态位可用性 | ReportDTCByStatusMaskAvailability | 掩码支持位图 |
| 19 02 + mask | 按状态掩码报 DTC | ReportDTCByStatusMask | 计数 +（DTC+状态）* |
| 19 03 | 报 DTCSnapshot ident | GetFreezeFrameIdentifier | 支持的快照记录号 |
| 19 04 + DTC | 读某 DTC 快照 | GetFreezeFrameDataByDTC | 记录号 + DID 数据集（见 [02-冻结帧](02-冻结帧.md)） |
| 19 06 + DTC + 记录号 | 读扩展数据记录 | GetExtendedDataRecordByDTC | occurrence/aging 等履历 |
| 19 0A | 报支持的 DTC | ReportSupportedDTC | 全量清单（含掩码） |
| 19 AB/AC | 首帧/首未帧时间戳 | GetDTCByOccurrenceTime | 最近/首次故障时间线 |
| 14 + 组掩码 | 清 DTC | Dem_ClearDTC | 状态：OK/不支持/繁忙 |
| 22 读"DTC 环境"DID | DID 路由到 Dem 通道 | 状态/计数类查询接口 | 如读某事件状态封装成 DID |

走查表的用法：集成验收时**逐行发真报文核对响应**——任何一行"报文对不上"，先查这张表定位断点在 Dcm（没配子服务）还是 Dem（接口返回空）。

### 读环境数据的两条路

同一个"看故障现场"，协议给了两条路：**19 04 按记录号读快照**（Dem 管理的标准路径），以及**22 读 DID**——把事件状态、发生次数、环境量封装成 DID 走 DID 路由（DID 路由表里数据源挂 Dem 通道，见 [02-DID路由](../Dcm配置/02-DID路由.md)）。OEM 通常混用：标准故障走 19，产线定制检查走 22——两条路数据同源（都出自 Dem 账本），但格式各异，设计期必须指定每条信息走哪条路，防止两套口径漂移。

### 清码的"繁忙"细节

Dem_ClearDTC 可能异步（涉及 NvM 删除多个块），SWS 定义三种返回：清除成功 / 该组不支持 / **Dem 正忙**（上一轮清除还在进行）。忙时 Dcm 应回 NRC 0x22（conditionsNotCorrect）让诊断仪稍后重试——把这做成"清完 54 再发下一条"的脚本习惯，可以避开绝大多数竞态。

## 配置层

| 配置项 | 含义 | 典型值 | 易错点 |
|---|---|---|---|
| DcmDspSid=19 容器+子服务列表 | 19 挂哪些子功能 | 01/02/04/06/0A 常配 | 配了 02 没配 04：读得了清单读不了现场，产线流程卡死 |
| 19 各子服务 SessionLevelRef | 子服务级会话白名单 | 默认会话也放开（售后读码刚需） | 19 只勾扩展会话：售后 4S 店默认态读不了码 |
| DcmDspSid=14>ClearDTC 组支持 | 允许清的组掩码（all/组/单条） | 按 OEM（常全支持） | 只支持全清：想单清某一条回 0x31 |
| 14 会话/安全门禁 | 清码权限 | 常默认会话+锁 0（或锁 1） | 清码挂高锁：售后流程忘解锁批量失败 |
| DemEventParameter>EventMemoryRef | 事件挂哪个存储器 | 挂 Primary | 没挂 Primary：事件有账但 19 永远读不到 |
| DemPrimaryMemory>状态掩码支持 | 19 02 掩码允许过滤哪些位 | 至少 bit2/bit3 | 掩码支持没含诊断仪发的位：响应条数为 0 的"假象" |
| DID 路由表 Dem 通道条目 | 22 读 DTC 相关 DID 的数据源 | 事件状态/计数类 DID | DID 里塞了超长故障清单：单帧装不下，改走 19 |

## 易错点与陷阱

1. **现象：19 02 回"0 个 DTC"，但故障明明在。排查路径按序走：① 19 0A 看清单里有没有该 DTC（没有→事件未挂 Primary 或 DTC 映射断链）；② 有→看状态掩码（诊断仪发 FF，Dem 只支持部分位时按支持位过滤，非 confirmed 事件不回）；③ 再看监控是否真报过 FAILED（见 [01-事件与DTC](01-事件与DTC.md) 的 debounce 断链）。**
2. **现象：14 清码回 0x22。原因：Dem 正在执行上一轮清除（NvM 慢），或清码时操作循环收尾进行中。对策：诊断脚本对 0x22 等待重试；不要连发 14。**
3. **现象：清码后 19 02 立即又读到同一条。原因：故障仍然在发生（清≠老化，见 [03-老化与操作循环](03-老化与操作循环.md)），清完即重新立案。对策：这是正常机制；验证流程应"先断故障源再清码"。**
4. **现象：19 04 读回的数据诊断仪解析乱码。原因：快照 DID 清单与诊断仪 CDD/ODX 不同步（ECU 侧加了 DID 没更新数据库）。对策：快照清单进同源三表管理（DID/事件/DTC），数据库发布与 ECU 版本绑定。**
5. **现象：ECU 复位后 19 读不到之前的故障。原因：事件存储 NvM 块没映射或写入策略为"循环末"，掉电丢账。对策：清码/复位/读码的联合用例必须进回归清单。**
6. **现象：22 读"DTC 环境 DID"与 19 04 数据对不上。原因：两条路径由不同团队实现，一个读实时值一个读快照。对策：设计模板里给每个环境量标注唯一来源（实时/快照），评审对表。**

## 面试高频题

- **Q：19 02 从报文到数据的完整链路？**
  A：诊断仪 19 02+掩码 → Dcm DSD 查会话/安全 → DSP 子服务 0x02 → Dem 按 ReportDTCByStatusMask 过滤事件存储器 → 返回（DTC+状态）列表 → DSP 拼 59 02 响应。链路上任何一环配置缺失，现象都是"0 条"或 0x31。
- **Q：为什么 14 之后 DTC 又出现了？是清码失败吗？**
  A：不是。清码是"人为销案"，若故障源仍在，监控继续报 FAILED，事件重新走 pending→confirmed 立案——清 ≠ 老化，老化的销案才有"连续 N 循环健康"的证据语义。
- **Q：Dcm 和 Dem 之间的接口是谁定义的？**
  A：AUTOSAR Dem SWS 定义的标准化接口（Dem_ReadDTCInformation 子族、Dem_ClearDTC 等），Dcm 的 DSP 层是这些接口的固定调用方；配置层只需要把 19/14 服务与子服务挂对会话/安全，运行时调用是栈生成的，不需要手写。
- **Q：读故障"现场"有哪两条路？怎么选？**
  A：19 04 读快照（标准路径，按记录号取 DID 数据集）或 22 读封装成 DID 的 Dem 数据（产线定制路径）。标准诊断和跨 OEM 互换走 19；项目内部产线工位检查走 22 更灵活——但同一信息只能指定一条源，防止两套口径漂移。

## 延伸

- [01-事件与DTC](01-事件与DTC.md)：账本本身的记账规则；
- [02-冻结帧](02-冻结帧.md)：19 04 背后的快照机制；
- [03-老化与操作循环](03-老化与操作循环.md)：14 与 aging 的销案语义对比；
- [01-DSL-DSD-DSP分层](../Dcm配置/01-DSL-DSD-DSP分层.md)：19/14 在 DSD 查表、DSP 分发的位置；
- [02-DID路由](../Dcm配置/02-DID路由.md)：DID 路由的 Dem 通道如何挂接。

---

维护约定：笔记命名 `序号-主题.md`；真实截图放 `_images/`；流程/时序/状态/架构图用 PlantUML 内嵌正文，规范见 [图表规范与模板](../../../00-总览/图表规范与模板.md)。
