# 04-AUTOSAR架构与BSW

> 一句话定位：BSW/平台岗的核心问答——分层架构、RTE、Com-PduR-CanIf 链路、EcuM/BswM/SchM、ARXML 十八题，每题带答案与出处回链，全部指向 07 区。
> 等级：L2 ｜ 前置：[面试是知识库的期末考试](../../00-入门导读/01-面试是知识库的期末考试.md)

## 太长不看

本篇 18 题：**基础 8 题**（分层/RTE/栈职责，答错基本没戏）、**进阶 7 题**（端到端数据流/模式管理/ARXML，拉开差距）、**区分度 3 题**（生成代码/多核/调试栈，聊出深度）。AUTOSAR 题的判卷口径：能画分层图+说清一条报文的旅程=及格；能讲配置项背后的 why=优秀。

## 基础题（8 题——答错基本没戏）

**Q：AUTOSAR 分层架构从上到下是什么？**

答：三层夹一个"标准化接口"——**应用层**（SWC，由 RTE 隔离）→ **RTE**（运行时环境，通信与调度的唯一中介）→ **BSW 基础软件**（再分服务层/ECU 抽象层/MCAL）→ **微控制器**。

设计思想：应用只依赖 RTE 提供的标准化端口 API，不碰硬件与 BSW 内部——换芯片只重配 BSW，SWC 原则上不动。追问常打在"BSW 内部三层各放什么"：服务层（OS/Com/DEM/DCM/NvM）、ECU 抽象层（统一外设接口）、MCAL（寄存器级驱动）。

出处：[分层架构](../../../07-AUTOSAR架构/1-L1基础/架构总览/01-分层架构.md)

**Q：RTE 是干什么的？为什么需要它？**

答：RTE 是 SWC 与其余世界之间的虚拟总线：对上提供端口通信 API（Rte_Write/Rte_Read/Rte_Call）与 runnable 运行环境，对下把通信映射到 Com/OS/IOC。两个使命：①**隔离**——SWC 与硬件、调度、物理通信解耦，可移植可复用；②**生成**——RTE 代码由工具按系统描述（arxml）生成，保证配置与代码一致。

一句话：没有 RTE，SWC 就得直接调 BSW API，AUTOSAR 的可交换性就归零。

出处：[AUTOSAR 第一课](../../../07-AUTOSAR架构/00-入门导读/01-AUTOSAR第一课-一座城的分区图.md)、[S-R 与 C-S 端口](../../../07-AUTOSAR架构/3-L3高级/RTE/01-S-R与C-S端口.md)

**Q：SWC 之间怎么通信？S-R 和 C-S 端口的区别？**

答：两种端口：**S-R**（Sender-Receiver）传数据——发送方 Rte_Write、接收方 Rte_Read，异步、无调用关系，适合信号/状态；**C-S**（Client-Server）传操作——Client 调 Rte_Call、Server 执行后回结果，同步或异步，适合"命令+确认"（如请求执行一次自检）。

数据流：S-R 经 RTE → Com（如果跨 ECU）或直接内存（同 ECU）；C-S 同 ECU 就是函数调用，跨 ECU 要靠服务映射。选错端口的代价：用 S-R 做"命令"会丢时序语义，用 C-S 传高频数据会拖死调度。

出处：[S-R 与 C-S 端口](../../../07-AUTOSAR架构/3-L3高级/RTE/01-S-R与C-S端口.md)

**Q：Classic Platform 和 Adaptive Platform 的区别？**

答：Classic：静态配置、硬实时、无动态内存、OSEK 型 OS——ECU 控制器主流；Adaptive：面向高性能计算（POSIX 型 OS、动态服务发现 SOME/IP、C++14）——域控制器/自动驾驶/车联网。一句话：Classic 管"确定的实时控制"，Adaptive 管"变化的计算服务"。多数岗位仍是 Classic，答出 AP 存在的意义即可。

出处：[Classic vs Adaptive](../../../07-AUTOSAR架构/1-L1基础/架构总览/02-Classic-vs-Adaptive.md)

**Q：Com 模块干什么？信号是怎么变成报文的？**

答：Com 在 PduR 之上做**信号级**管理：发送侧把信号值按 I-SIGNAL-I-PDU 打包（字节序、符号扩展按配置），按传输模式发（周期/事件/混合），并做信号超时监控（TOE）与失效替代值；接收侧解包分发、给 RTE，越时给默认值。

关键配置：TxMode（周期/事件+最小间隔）、超时、First Timeout。追问点：信号打包后的 I-PDU 交给 PduR，Com 不知道也不管底层走 CAN 还是 LIN。

出处：[Com](../../../07-AUTOSAR架构/2-L2进阶/通讯服务栈/01-Com.md)

**Q：PduR 是干什么的？**

答：PDU 路由器——把 I-PDU 在模块之间按路由表转发：上行（CanIf→CanTp→Dcm）、下行（Com→CanIf）、网关路由（CanIf→CanIf 跨通道转发）。它不解析内容，只查表搬 PDU。路由表是 ARXML 里最容易配错的点：目标漏配报文"发不出去"、上下行表不对称"收得到发不出"。

出处：[PduR](../../../07-AUTOSAR架构/2-L2进阶/通讯服务栈/02-PduR.md)

**Q：CanIf 的职责是什么？**

答：CAN 接口抽象层：对上提供与硬件无关的 CanIf_Transmit/读回调，对下管理 CanDrv（多控制器）、HOH/HRH（硬件对象句柄）与邮箱映射、确认 SW 类 CAN ID 范围、做 DLC 校验、通知 busoff/唤醒事件。一句话：CanDrv 的差异被 CanIf 抹平，PduR/CanTp 看到统一接口。

出处：[CanIf-LinIf](../../../07-AUTOSAR架构/2-L2进阶/通讯服务栈/06-CanIf-LinIf.md)

**Q：EcuM 的上下电流程走一遍？**

答：上电：**启动阶段**（初始化 OS 前：Mcu/Port/Dio 等 I 驱动 → 启动调度）→ **RUN**（应用主循环，等待所有资源释放请求）→ 下电：**POST_RUN** → **SHUTDOWN**（NvM 写回、外设停）→ 断电/复位。

两大学派：fixed EcuM（时序写死，简单可控，量产主流）vs flex EcuM（由 BswM 驱动各阶段跳转，灵活复杂）。追问"为什么下电要等 NvM 写完"——不写回参数就丢/写一半 Flash 损坏。

出处：[上下电时序](../../../07-AUTOSAR架构/2-L2进阶/系统服务栈/EcuM/02-上下电时序.md)、[flex vs fixed](../../../07-AUTOSAR架构/2-L2进阶/系统服务栈/EcuM/01-flex-vs-fixed.md)

## 进阶题（7 题——拉开差距）

**Q：一条应用信号从 SWC 到总线的完整路径？**

答：发送链路（自上而下）：SWC `Rte_Write` → RTE（信号更新通知）→ Com（打包进 I-PDU、判传输模式）→ PduR（查表）→ CanIf（取 HOH、组 L-PDU）→ CanDrv（写邮箱/请求发送）→ 硬件发帧；总线帧再由对端反向走一遍上来。接收链路镜像：CanDrv 中断 → CanIf（HRH 分发）→ PduR → Com（解包、超时判断）→ RTE → SWC `Rte_Read`。

面试画图题：能白板画出这条链并标出每层的"数据单位变化"（信号→I-PDU→L-PDU→帧）就是优秀。

出处：[Com](../../../07-AUTOSAR架构/2-L2进阶/通讯服务栈/01-Com.md)、[PduR](../../../07-AUTOSAR架构/2-L2进阶/通讯服务栈/02-PduR.md)、[CanIf-LinIf](../../../07-AUTOSAR架构/2-L2进阶/通讯服务栈/06-CanIf-LinIf.md)

**Q：BswM 是干什么的？和 EcuM 什么关系？**

答：BswM = 模式管理器：把"模式请求"（应用或其他 BSW 发起）与"模式条件"用**规则（Rule：IF 条件 THEN 动作列表）**驱动——切换通信（全通信/静默）、控制 LIN 调度表、开关路由、发分区命令。

关系：fixed EcuM 自己走时序；flex 架构下 BswM 是"大脑"，EcuM 阶段跳转听 BswM 指挥。一句话：EcuM 管"活着/死了"，BswM 管"以什么姿态活着"。

出处：[模式仲裁](../../../07-AUTOSAR架构/2-L2进阶/系统服务栈/BswM/01-模式仲裁.md)、[规则配置](../../../07-AUTOSAR架构/2-L2进阶/系统服务栈/BswM/02-规则配置.md)

**Q：SchM 怎么把 Runnable 映射到任务？**

答：系统描述里每个 runnable 声明触发事件（周期 TimingEvent、数据接收事件、模式切换事件、InitEvent…），映射到 OS task；生成器按映射生成调度表与 RTE 调用代码。原则：周期快的 runnable 映射高优先级短周期 task；同一 task 的 runnable 串行执行，耗时叠加要有余量。排障点：runnable 塞进 10ms task 但自己跑 8ms，task 超时抖动。

出处：[调度表](../../../07-AUTOSAR架构/2-L2进阶/SchM与调度/01-调度表.md)、[Runnable 到 Task 映射](../../../07-AUTOSAR架构/2-L2进阶/SchM与调度/02-Runnable到Task映射.md)

**Q：NvM-Fee/Ea-Fls 链路怎么工作？**

答：NvM 管块（Block：NvM job API、CRC、冗余、写优先级），MemIf 做多 Fee/Ea 设备选择，Fee 把逻辑块地址映射到 DFlash 段（磨损均衡、掉电安全），Fls 打底做物理擦写。典型流程：应用 NvM_WriteBlock → NvM 排队（写队列）→ Fee 拷贝到备份/写新副本 → Fls 擦写扇区 → 完成回调。显式/隐式同步决定什么时候通知应用完成。

出处：[NvM 块管理](../../../07-AUTOSAR架构/2-L2进阶/内存栈/01-NvM块管理.md)、[MemIf-Fee-Ea](../../../07-AUTOSAR架构/2-L2进阶/内存栈/04-MemIf-Fee-Ea.md)

**Q：ARXML 怎么手读？拿一份配置先看什么？**

答：先抓四个骨架：ECUC 配置树（模块→容器→参数）、模块清单、端口与连接（SWC 描述）、映射（系统描述：task/runnable/报文）。实用技巧：按模块名 grep 到容器，再看 REF 引用链（短名路径）串起关系；diff 两版 arxml 定位配置变更是集成排障核心技能——别通读，按问题反查。

出处：[ARXML 手读](../../../07-AUTOSAR架构/2-L2进阶/方法论与ARXML/03-ARXML手读.md)、[ECU 配置结构](../../../07-AUTOSAR架构/2-L2进阶/方法论与ARXML/01-ECU配置结构.md)

**Q：CanSM 管什么？和 EcuM/BswM 怎么联动？**

答：CanSM 管 CAN 网络的"通信模式"：请求全通信（Start）→ 依次启动控制器（CanIf→CanDrv）、开收发器（CanTrcv）、等待 busoff 恢复策略；请求静默（STOP）→ 停发但可收。它汇总控制器状态、busoff 事件上报 ComM/BswM。典型链路：BswM 规则"车速>0"→请求 CanSM FULL COM→网络醒。区分 CanIf（数据面）与 CanSM（控制面）是常见考点。

出处：[CanSM](../../../07-AUTOSAR架构/2-L2进阶/通讯服务栈/03-CanSM.md)、[CanTrcv](../../../07-AUTOSAR架构/2-L2进阶/通讯服务栈/07-CanTrcv.md)

**Q：Det 和 Dlt 分别是什么？**

答：**Det**（默认错误跟踪器）开发期检查 API 参数/状态错误，Det_ReportError 打点——查出"谁用错了接口"；量产可裁剪。**Dlt**（诊断日志跟踪）把应用/BSW 的日志文本按协议打包（经 PduR 上以太网/诊断口），供 ecu.test/CANoe 抓日志。一句话：Det 抓编程错误，Dlt 传运行日志。

出处：[Det](../../../07-AUTOSAR架构/2-L2进阶/系统服务栈/Det与Dlt/01-Det.md)、[Dlt](../../../07-AUTOSAR架构/2-L2进阶/系统服务栈/Det与Dlt/02-Dlt.md)

## 区分度题（3 题——聊出深度）

**Q：RTE 生成的代码长什么样？怎么读懂它？**

答：套路三件套：①端口存根（`Rte_Write_<Port>_<DataElement>` 展开为对全局信号缓冲/Com 调用的 inline）；②runnable 包装函数（Os task 调 Rte_CData…/Rte_Run，前后做事件查询）；③IOC 跨核/SWC 通信函数（Rte_IocWrite_xxx）。读法：从 map 的 Rte_ 符号入手，找到 SWC 对应的 .c，跟一个 Write 调用链到 Com——生成代码是"配置的可执行证明"，读通一次，配置错误无处遁形。

出处：[生成代码解读](../../../07-AUTOSAR架构/3-L3高级/RTE/04-生成代码解读.md)、[Runnable 映射](../../../07-AUTOSAR架构/3-L3高级/RTE/02-Runnable映射.md)

**Q：多核 AUTOSAR 项目要注意什么？**

答：四件事：①主从核启动——Core0 起来再放行其他核（Startup 放行 + 各核 OsApp）；②跨核通信用 IOC（RTE 生成、无锁队列/双缓冲），别裸共享变量；③共享资源（Flash 写、NvM 队列）要 SpinLock 串行化——TriCore 上常见"多核同时写 Fee 拖慢"；④中断与任务按核分配，负载均衡别把高速链路全堆一个核。能讲一个具体踩坑（如双核同时刷 Flash 死锁）最加分。

出处：[主从核启动](../../../07-AUTOSAR架构/3-L3高级/多核集成/01-主从核启动.md)、[IOC 与核间中断](../../../07-AUTOSAR架构/3-L3高级/多核集成/02-IOC与核间中断.md)、[共享资源保护](../../../07-AUTOSAR架构/3-L3高级/多核集成/03-共享资源保护.md)

**Q：BSW 集成工程师的日常是什么？讲一个集成排障案例。**

答：日常：配 DaVinci/Tresos（Com/PduR/OS/Dcm…）→ 生成与编译 → 集成 SWC 与 CDD → 静态检查/冒烟测试 → 支持问题单。案例 STAR：S——报文"别家能收我们收不到"；T——定位是集成配置问题；A——从 CanIf HRH 过滤表入手，发现该 ID 不在任何 HRH 范围 → 补配置再生成；R——问题闭环，并把"HRH 过滤表检查"写进冒烟清单。展示的是分层排查路径，不是背参数。

出处：[DaVinci Configurator](../../../10-工具链与工程化/2-L2进阶/AUTOSAR配置工具/01-DaVinci-Configurator.md)、[EB tresos](../../../10-工具链与工程化/2-L2进阶/AUTOSAR配置工具/02-EB-tresos.md)

## 回炉地图

| 答不上的题型 | 回炉篇 |
|---|---|
| 分层/RTE/端口 | [07 区/架构总览](../../../07-AUTOSAR架构/1-L1基础/架构总览/README.md)、[07 区/RTE](../../../07-AUTOSAR架构/3-L3高级/RTE/README.md) |
| 通讯服务栈 | [07 区/通讯服务栈](../../../07-AUTOSAR架构/2-L2进阶/通讯服务栈/README.md) |
| EcuM/BswM/Os/WdgM | [07 区/系统服务栈](../../../07-AUTOSAR架构/2-L2进阶/系统服务栈/README.md) |
| 内存栈 | [07 区/内存栈](../../../07-AUTOSAR架构/2-L2进阶/内存栈/README.md) |
| ARXML/方法论 | [07 区/方法论与 ARXML](../../../07-AUTOSAR架构/2-L2进阶/方法论与ARXML/README.md) |

---

维护约定：笔记命名 `序号-主题.md`；真实截图放 `_images/`；流程/时序/状态/架构图用 PlantUML 内嵌正文，规范见 [图表规范与模板](../../../00-总览/图表规范与模板.md)。
