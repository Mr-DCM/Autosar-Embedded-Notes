# 03-与NvM链路

> 一句话定位：把一次 NvM_WriteBlock 从应用到 Flash 硅片的完整旅程拉直了看——四层调用、异步工单、逐层回调，以及"你以为写了，其实还没落盘"的三种写策略。
> 等级：L2 ｜ 前置：[02-Fee模拟EEPROM](02-Fee模拟EEPROM.md)

## 原理

### 四层调用链：各管一段，谁也不越界

| 层 | 管什么 | 典型 API |
|---|---|---|
| NvM（服务层） | 块的对外契约：RAM 镜像、CRC、写策略、作业管理 | NvM_WriteBlock/NvM_ReadBlock/NvM_MainFunction |
| MemIf（抽象层） | 只是个路由器：按 DeviceIndex 把调用转给 Fee 或 Ea | MemIf_Write/…（透明转发） |
| Fee（ECU 抽象层） | 模拟 EEPROM：块号→动态物理地址、磨损均衡 | Fee_Write/Fee_Read/Fee_MainFunction |
| Fls（MCAL） | 真碰硬件：按扇区/页擦写 D-Flash | Fls_Erase/Fls_Write/Fls_MainFunction |

MemIf 是四层里最"薄"的一层——它存在的唯一意义是：上层不必关心这块数据存在 Fee 还是 Ea（外接 EEPROM）背后是哪颗芯片。

### 一次 NvM_WriteBlock 的旅程（时序图）

```plantuml
@startuml
title 一次 NvM_WriteBlock 的完整旅程（含逐层回调）
skinparam defaultFontName "Microsoft YaHei"
autonumber on
participant "应用/RTE" as APP
participant "NvM" as NVM
participant "MemIf" as MIF
participant "Fee" as FEE
participant "Fls\n(MCAL)" as FLS
participant "D-Flash\n硬件" as HW

APP -> NVM : NvM_WriteBlock(NvM_BlockDescriptor_t, ramPtr)
note right of NVM : 只登记请求：目标 RAM 拷贝+CRC\n真正干活在 NvM_MainFunction
NVM -> NVM : NvM_MainFunction()\n(周期调度)
NVM -> MIF : MemIf_Write(DeviceIdx, BlockId, ramPtr)
MIF -> FEE : Fee_Write(BlockId, ramPtr)
note right of FEE : 追加写：页满先触发垃圾回收
FEE -> FLS : Fls_Erase(...) / Fls_Write(...)   「异步工单」
FLS -> HW : 擦/编程命令
FLS --> FEE : 受理返回，作业挂起
FEE --> NVM : 挂起中，作业状态 PENDING
== 硬件干完活（中断或轮询发现） ==
HW --> FLS : 完成
FLS -> FLS : Fls_MainFunction/ISR 收尾
FLS -> FEE : Fls_JobEndNotification()\n(配置指向 Fee 的通知函数)
FEE -> FEE : Fee_MainFunction() 继续推进\n(必要时递交下一张工单)
FEE -> NVM : Fee_JobEndNotification()
NVM -> NVM : 作业结果 MEMIF_JOB_OK\n算 CRC、置完成标志
NVM --> APP : NvM_GetErrorStatus 查到 OK\n(或配置的作业结束回调)
@enduml
```

三个读图要点：

1. **每一层都是"受理+推进+回调"三板斧**：API 调用只登记，MainFunction 周期推进，完成后逐层上报——异步是整条链的公约数；
2. **回调方向与调用方向相反**：调用时 NvM→MemIf→Fee→Fls，上报时 Fls→Fee→NvM，一去一回像多米诺；
3. **一次 NvM 写可能对应多张 Fls 工单**：垃圾回收的"擦一页+搬 N 块+写新块"是接力赛，中间任何一步都可能插着别人的块。

### NvM Block 与 Fee Block 的对应关系

- NvM 侧每块配置：NvMBlockDescriptor（NvMNvBlockLength、RAM 镜像、CRC 类型、写策略、NvMNvBlockBaseNumber）；
- Fee 侧每块配置：FeeBlockNumber、FeeBlockSize、立即写属性；
- 对应铁律：**NvM 的块号映射到 Fee 的块号**；块长不是"RAM 长度原样下传"——NvM 若配 CRC，**CRC 与块 ID 管理数据（合计 8 字节量级，以工具链生成为准）计入 NvMNvBlockLength 并随数据一并写入底层**，因此 Fee 侧块长必须按"数据长度 + 管理区"配置，按纯数据长度配会导致写作业长度校验不过；
- 多设备时 NvM 的 DeviceIndex 决定走 Fee 还是 Ea——MemIf 就是按它分发的。
### "NvM 写入到底何时真正落 Flash"：三种写策略

这是本链路最重要的一张表——同一个 NvM_WriteBlock，落盘时机完全不同：

| 策略 | 落盘时机 | 掉电风险 | 适用 |
|---|---|---|---|
| **隐式同步写**（NvM_WriteBlock 到 RAM 镜像） | 只写 RAM 镜像并标脏；等周期 NvM_MainFunction（或 Shutdown 时）攒一批统一落盘 | 周期间隔内掉电丢本批更新 | 大多数标定/配置块（默认选择） |
| **显式写**（NvM_SetRamBlockStatus + 周期机制） | 应用主动置 RAM 脏标志，仍由周期/Shutdown 落盘 | 同上，但落盘点更可控 | 需要应用决定"何时算有效"的块 |
| **立即写**（NvM 写立即块 / FeeImmediateData） | API 调用后当个作业周期内直接穿透到 Fee/Fls | 最小窗口，基本落盘 | 安全关键少量数据（如碰撞标志） |

一句话记：**普通块"攒着批量存"保护寿命，立即块"一次到位"保护数据**——立即写得省着用，否则磨损均衡白做。

### 双平台对照

| 对照维度 | TC377 路径 | S32K 路径 |
|---|---|---|
| NvM→Fls 全链 | NvM→MemIf→Fee→Fls(DFlash/DMU) | NvM→MemIf→Fee→Fls(FlexNVM/FTFC)，或 EEE 分支 |
| Fee 之下的物理 | DFlash 经 DMU 擦写 | FlexNVM 经 FTFC 擦写；EEE 时由 CSEc 代管 |
| 完成通知源 | Flash 完成中断/DMU 状态 | FTFC CCIF 标志中断 |
| 典型写策略 | 隐式为主+关键块立即写 | 同左；EEE 块硬件 record 机制兜底掉电 |
| 寿命压力点 | DFlash 扇区擦写计数 | EEE 备份区 record 消耗/传统分区擦写计数 |

## 配置要点

- **NvM 侧**：块描述表（长度/CRC/优先级/写策略/DeviceIndex）、RAM 镜像与 NvM_MainFunction 周期、作业队列深度 NvMSizeOfJobQueue；
- **Fee/Fls 侧**：块表逐块对齐（见 02 篇）、扇区归属、通知回调指向正确（Fls 的 JobEnd→Fee，Fee 的 JobEnd→NvM）；
- **调度**：NvM_MainFunction/Fee_MainFunction/Fls_MainFunction（轮询模式）都要进周期任务表，周期关系建议 NvM ≥ Fee ≥ Fls 密度；
- **Shutdown 路径**：EcuM 下电流程要给 NvM 留"把脏块写完"的时间预算（NvM_WriteAll/超时）；
- **优先级块**：碰撞/故障码等高优先块配 NvMDatasetSelection 与立即写，别排队排在慢块后面。

## 代码示例

```c
/* 应用视角：三种写策略的典型用法 */
#define NVM_BLK_CFG      NvMConf_NvMBlockDescriptor_Block_Cfg      /* 普通块 */
#define NVM_BLK_CRASH    NvMConf_NvMBlockDescriptor_Block_CrashRec /* 立即块 */

/* 1) 隐式写：只写 RAM 镜像，NvM 攒批落盘（默认策略） */
memcpy(cfgRamMirror, &newCfg, sizeof(newCfg));
NvM_SetRamBlockStatus(NVM_BLK_CFG, TRUE);   /* 标脏，等周期/Shutdown 落盘 */

/* 2) 显式单次写：直接发起一个写作业（异步，受理即返回） */
(void)NvM_WriteBlock(NVM_BLK_CFG, cfgRamMirror);

/* 3) 立即写：关键数据当周期穿透落盘（配置 NvMWriteVerification+Fee 立即属性） */
(void)NvM_WriteBlock(NVM_BLK_CRASH, &crashRec);

/* 查作业结果（异步链的终点确认） */
NvM_RequestResultType res = NVM_REQ_PENDING;
while (res == NVM_REQ_PENDING) {            /* 实际工程用状态机/回调，别死等 */
    NvM_MainFunction();                     /* 周期推进：NvM→MemIf→Fee→Fls */
    NvM_GetErrorStatus(NVM_BLK_CFG, &res);
}
/* res == NVM_REQ_OK：此时（且仅此时）数据真正进了 Flash */
```
## 易错点与陷阱

1. **现象**：NvM_WriteBlock 返回 E_OK 就断电，重启数据丢了。**原因**：E_OK 只表示作业受理，异步链还没走完；隐式写更是只写了 RAM。**对策**：轮询 NvM_GetErrorStatus 到 NVM_REQ_OK（或等作业回调）才认为落盘；下电流程走 NvM_WriteAll。
2. **现象**：MainFunction 全挂了但作业永无进展。**原因**：NvM/Fee/Fls 三层调度周期漏配或顺序错（如 Fls 轮询没进任务表）。**对策**：检查三层 MainFunction 的调度表条目与相对周期。
3. **现象**：两块数据偶尔"串台"。**原因**：块号映射错位（NvM 与 Fee 块表没对齐）或 DeviceIndex 配错走到 Ea。**对策**：块表逐块评审；用 NvM_ReadBlock+已知模式数据全块自测。
4. **现象**：立即写块用太多，Flash 寿命骤减。**原因**：立即写绕过攒批，每次更新都真擦写。**对策**：只给真正安全关键的少量小块开立即写。
5. **现象**：Shutdown 时写一半被硬断电。**原因**：下电序列没给 NvM 留足写完脏块的时间/未等 NVM_REQ_OK。**对策**：EcuM 下电状态机里显式等待 NvM 写完成或超时降级记录 DTC。
6. **现象**：垃圾回收期间高优先块也被拖慢。**原因**：所有块排同一个作业队列，慢回收挡路。**对策**：关键块配高优先级/立即写属性；评估 Fee 回收拆步。

## 面试高频题

1. **画/描述一次 NvM 写的调用链。**
   答：NvM_WriteBlock(登记)→NvM_MainFunction→MemIf_Write→Fee_Write(追加写)→Fls_Erase/Write(异步工单)→硬件完成→Fls_JobEndNotification→Fee→NvM 置 NVM_REQ_OK。
2. **MemIf 存在的意义是什么？**
   答：薄路由层：按 DeviceIndex 在 Fee/Ea 之间转发，让 NvM 不关心存储介质是片内模拟 EEPROM 还是外挂 EEPROM。
3. **NvM 写入何时真正落 Flash？三种策略各适合谁？**
   答：隐式（RAM 标脏攒批，默认）、显式（应用定时点）、立即写（关键小数据当周期穿透）；寿命与掉电安全的权衡。
4. **一次 NvM_WriteBlock 会触发几次 Fls 作业？**
   答：至少一次写；页满时是"擦页+搬多块+写新块"接力，故作业超时必须按最坏（含回收）预算。

## 延伸

- [01-Fls驱动](01-Fls驱动.md)｜[02-Fee模拟EEPROM](02-Fee模拟EEPROM.md)：链路下两层的物理与算法底座；
- [内存栈](../../../07-AUTOSAR架构/2-L2进阶/内存栈/README.md)：NvM/MemIf 在 AUTOSAR 内存栈中的全貌；
- [EcuM 上下电时序](../../../07-AUTOSAR架构/2-L2进阶/系统服务栈/EcuM/02-上下电时序.md)：上下电序列与 NvM 落盘时间预算的来源；
- [SchM 调度表](../../../07-AUTOSAR架构/2-L2进阶/SchM与调度/01-调度表.md)：三层 MainFunction 挂周期任务表的机制；
- [环形缓冲区](../../../01-编程语言/2-L2进阶/数据结构与算法-C实现/01-环形缓冲区.md)：异步"受理-推进-回调"在数据结构层的同类直觉。