# SID19-读DTC

> 一句话定位：翻看 ECU 的故障账本——DTC 3 字节编号 + 1 字节状态构成一条记录，按 statusMask 过滤、按子功能取数量/快照/扩展数据，是售后排障与产线 EOL 检测的主读口。
> 等级：L2 ｜ 前置：[01-服务总览](01-服务总览.md)

## 原理

### 账本的行结构：DTC + 状态字节

每条故障记录 = **DTC（3 字节编号）+ statusOfDTC（1 字节状态位图）**。DTC 高 2 位是组别：P 动力总成、C 底盘、B 车身、U 网络（如 `01 21 03` = P012103 类）。账本的记账人、清账人分别是 Dem 与 [SID14](SID14-清DTC.md)，19 只负责"读"。

```plantuml
@startuml
autonumber on
participant "诊断仪" as TESTER
participant "Dcm" as DCM
participant "Dem\n(故障账本)" as DEM

TESTER -> DCM : 19 02 09（按 mask=09 读状态）
note right of DCM : mask 过滤：\nbit0 testFailed 或 bit3 confirmed
DCM -> DEM : Dem_GetStatusOfDTC...
DEM --> DCM : 命中的 DTC+status 列表
DCM --> TESTER : 59 02 FF <count> [DTC 3B + status 1B]...
note over TESTER : 屏幕上逐条显示：\nP0121 当前故障 / P0234 历史故障
TESTER -> DCM : 19 04 02（读快照，单 DTC）
DCM -> DEM : Dem_GetFreezeFrameData
DEM --> DCM : 事发瞬间的环境数据
DCM --> TESTER : 59 04 ...（快照记录）
@enduml
```

### statusMask 8 位逐位表（14229 口径）

| bit | 名称 | 含义（直觉） |
|---|---|---|
| 0 | testFailed | **当前**失败：最后一次检测结果是"坏"——修没修好看它 |
| 1 | testFailedThisOperationCycle | 本操作循环内失败过（点火循环内出现过） |
| 2 | pendingDTC | 待定：本循环首次失败，还没到确认门槛——OBD 的"疑似" |
| 3 | confirmedDTC | 已确认：连续失败达确认阈值，正式立案（历史故障含此位） |
| 4 | testNotCompletedSinceLastClear | 自上次清除后**没测过**（传感器没上电/没运行） |
| 5 | testFailedSinceLastClear | 自上次清除后失败过（即便后来又好了） |
| 6 | testNotCompletedThisOperationCycle | 本循环还没测完 |
| 7 | warningIndicatorRequested | 请求点亮警告灯（MIL/红灯） |

三点直觉：**mask=0x08 只看已立案**（售后"读历史故障码"）；**mask=0x01 只看当前仍坏的**（"还有没有活的故障"）；**bit4/6 的"没测过"位**是隐蔽坑——清码后不上电循环就回读，看到的不是"好了"而是"没测"。

### 子功能一览表

| 子功能 | 名称 | 干什么 | 典型用途 |
|---|---|---|---|
| 0x01 | reportNumberOfDTCByStatusMask | 按掩码报**数量**（不含明细） | EOL 快速判断"有没有故障" |
| 0x02 | reportDTCByStatusMask | 按掩码报 DTC+状态明细 | 读故障码列表 |
| 0x04 | reportDTCSnapshotRecordByDTCNumber | 读单 DTC 的**快照**（冻结帧环境值） | 复现事发工况 |
| 0x06 | reportDTCExtendedDataRecordByDTCNumber | 读扩展数据（发生计数/老化计数/寿命等） | 统计型分析 |
| 0x0A | reportSupportedDTC | 报**全部支持**的 DTC 及当前状态 | 体检：本 ECU 有哪些故障位 |
| 0x03/0x05/07/09 等 | 镜像/组合报告 | 按厂商/OBD 需求扩展 | 查 CDD 为准 |

## 详解

### 报文格式逐字节

**请求（以 02 为例）：** `19 02 09`

| 字节 | 值 | 含义 |
|---|---|---|
| 1 | 0x19 | SID：ReadDTCInformation |
| 2 | 0x02 | 子功能 |
| 3 | 0x09 | statusMask（仅 01/02 需要；04/06 跟 DTC 号+记录号） |

**正响应（02）：** `59 02 FF 02 [01 21 03 09] [01 22 04 08]`

| 字节 | 值 | 含义 |
|---|---|---|
| 1 | 0x59 | SID+0x40 |
| 2 | 0x02 | 回显子功能 |
| 3 | 0xFF | statusAvailabilityMask：本 ECU 支持哪些状态位 |
| 4 | 0x02 | 命中条数 |
| 5~8 | 01 21 03 09 | DTC P0121 + status 0x09（bit0+bit3：当前且确认） |
| 9~12 | 01 22 04 08 | DTC P0220 + status 0x08（仅确认：历史故障） |

**负响应 `7F 19 NRC`：**

| NRC | 场景 |
|---|---|
| 0x12/0x13 | 子功能不支持/长度错 |
| 0x31 | DTC 号不存在、快照/扩展记录号越界 |
| 0x7E/0x7F | 会话不支持（多数 ECU 默认会话也放行 01/02，看 CDD） |

### 快照与扩展数据的差别

快照（04）= 事发瞬间的**环境照片**（车速/电压/温度，Dem 冻结帧）；扩展数据（06）= 该故障的**累计统计**（发生次数、老化计数、首次/最近里程）。两者都是 Dem 的账本字段，通过 Dcm 透传——结构定义在 [Dem配置](../../2-L2进阶/Dem配置/README.md)。

## 配置层

- 19 的每个子功能在 Dcm **DspReadDTCInfo** 一族配置行里启用，映射到 Dem API（`Dem_GetNumberOfFilteredDTC` 等）——接线见 [Dcm配置](../../2-L2进阶/Dcm配置/README.md)；
- DTC 的确认阈值、老化循环数、快照记录数、扩展数据种类是 **Dem 事件配置**的核心参数，决定 19 读出来什么——见 [Dem配置](../../2-L2进阶/Dem配置/README.md)；
- statusAvailabilityMask 第三字节如实反映实现：不支持某状态位就别在 mask 里要求它。

## 易错点与陷阱

1. **现象：清码后回读 status 变 0x50 而不是 0x00。原因：bit4/bit6 置位表示"清后没测过"，不是故障。对策：清码后至少跑一个完整操作循环再判断"修好"**；
2. **现象：19 02 明明有故障却回 0 条。原因：statusMask 过滤条件不含该故障当前状态。对策：用 19 0A（全部支持）或 mask=0xFF 兜底看全貌**；
3. **现象：多 ECU 各自读到不同 DTC 列表。原因：19 是 ECU 级账本，网关聚合需另行实现。对策：整车读码按 ECU 逐个轮询，或用网关路由聚合（OEM 定义）**；
4. **现象：快照数据看着"不合理"。原因：快照在故障确认瞬间抓取，字段取的是当时值；Dem 配置的抓取时机/触发源不对。对策：核对 Dem 冻结帧触发配置（confirmation 时 or first failed 时）**；
5. **现象：扩展数据记录号报 0x31。原因：请求的 record number 超出该 DTC 配置的扩展数据条目。对策：按 CDD 的 Extended Data 表逐条读**；
6. **现象：诊断仪显示 DTC 号与 3 字节对不上。原因：工具做了 P/C/B/U 前缀与高低位的换算，字节序填错。对策：用十六进制原始报文核对 3 字节 DTC 的换算规则（首字节高 2 bit→组别字母）**。

## 面试高频题

**Q1：DTC 记录的结构？**
答：3 字节 DTC 编号（高 2 bit 定 P/C/B/U 组）+ 1 字节状态位图，状态 8 位从 bit0 testFailed 到 bit7 warningIndicatorRequested。

**Q2：mask=0x08 与 0x01 分别读到什么？**
答：0x08 只读"已确认（立案）"的故障——历史+当前；0x01 只读"当前仍失败"的——判断是否修好。

**Q3：pending（bit2）和 confirmed（bit3）的区别？**
答：pending：本循环首次失败、尚未达确认门槛的"疑似"；confirmed：连续失败达阈值正式立案的"实锤"——OBD 用两步确认防误报。

**Q4：快照与扩展数据的区别？**
答：快照是确认瞬间的环境值冻结帧（车速/电压），扩展数据是累计统计（计数/老化）——都由 Dem 记账、19 的 04/06 子功能读出。

## 延伸

- [SID14-清DTC](SID14-清DTC.md)——账本的清账侧；
- [01-服务总览](01-服务总览.md)——存储管理组全景；
- [Dem配置](../../2-L2进阶/Dem配置/README.md)——确认阈值、冻结帧、老化的配置现场；
- [OBD 法规与模式](../OBD/01-法规与模式.md)——Mode 03/07 与 19 的映射关系。

---

维护约定：笔记命名 `序号-主题.md`；真实截图放 `_images/`；流程/时序/状态/架构图用 PlantUML 内嵌正文，规范见 [图表规范与模板](../../../00-总览/图表规范与模板.md)。
