# Cache 与 MPU

> 一句话定位：核与慢存储之间的"隐形加速层"和"电子围栏"——Cache 带来性能也带来一致性坑，MPU 在无 MMU 的 MCU 上做内存隔离，两者都是 ECU 上"偶发诡异问题"的高发区。
> 等级：L2→L3 ｜ 前置：[04-MPU](../../1-L1基础/ARM-Cortex-M/04-MPU.md)

## 太长不看

- **人话直觉**：Cache 是草稿纸（快慢），MPU 是门禁卡（能不能进）。
- **本篇解决**：DMA 搬完数据 CPU 读到旧值怎么回事？MPU 只在有 MMU 的芯片上才有用吗？
- **赶时间记住 3 条**：
  1. 局部性是 Cache 有效的根；
  2. DMA 写后 CPU 读旧值=一致性坑，invalidate/clean 解决；
  3. MPU 按 region 划权限，裸机也能用。

## 原理

### 1. Cache 的存在动机

- 核心速度与主存（SRAM/Flash）速度差距持续拉大，不加缓存，核每几拍就要空等存储。
- 局部性原理（Principle of Locality）：时间局部性（刚访问的很快再被访问）+ 空间局部性（临近地址大概率一起被访问）——Cache 按**行（line）**整块搬运，命中就近、不中才走慢总线。
- Cache 是**地址到数据的隐藏副本**：对程序透明，也正是所有一致性问题的根源。

### 2. 写策略：写直达 vs 写回

| 策略 | 英文 | 写命中动作 | 优点 | 代价 |
|---|---|---|---|---|
| 写直达 | Write-Through | 同时写 cache 与主存 | 主存永远新鲜，一致性简单 | 写流量大、慢总线被打爆 |
| 写回 | Write-Back | 只写 cache，置脏位（Dirty），换出时才写回主存 | 写快、总线流量小 | 主存可能过期，必须维护脏行 |

配合**写分配（Write-Allocate）**与**写不分配（No-Write-Allocate）**决定写未命中时是否把该行取进 cache。MCU 上的 L1 cache 多为写回型（具体策略以各核手册为准）。

### 3. Cache 一致性三大来源与对策

| 来源 | 场景 | 典型症状 | 对策 |
|---|---|---|---|
| DMA | DMA 直接搬内存，CPU cache 里留着旧副本（收）或主存还是旧数据（发） | 收到旧帧/发出旧帧，偶发 | DMA 缓冲放非缓存区；或发送前清理（clean）cache、接收后失效（invalidate）cache |
| 多核 | 各核私有 D-cache 缓存同一共享变量 | 一核改了另一核看不见 | 共享区设为共享/非缓存，或软件维护清理/失效（见多核笔记） |
| 自修改代码 | 写完代码立即执行 | 执行旧指令 | 写后做指令 cache 失效 + 同步屏障（isb/dsb 类），MCU 上尽量避免自修改代码 |

> 口诀：**CPU 写 → 给别人看之前 clean（清理/写回）；CPU 读别人写的 → 先 invalidate（失效）再读。**

### 4. 为什么 TC377 的 DSPR/PSPR 常免 Cache 之忧

- DSPR/PSPR 是每核**私有**的紧耦合内存（Tightly Coupled Memory）：固定地址、单周期直达、**根本不经过 cache**——没有副本就没有一致性问题。
- 数据放 DSPR、代码放 PSPR，等于"手工管理的确定性 cache"：不命中、不失效、抖动为零，这正是功能安全代码的惯用放法。
- 代价：容量小、每核独占（跨核访问走总线，变慢），详见 [05-存储层次](05-存储层次.md)。

### 5. MPU vs MMU

| 维度 | MPU（Memory Protection Unit） | MMU（Memory Management Unit） |
|---|---|---|
| 地址转换 | 无，物理地址直通 | 虚拟地址 → 物理地址转换（页表） |
| 粒度 | 区域（region，若干个，粒度可到 KB 级） | 页（4KB 量级） |
| 功能 | 权限检查（读/写/执行、特权级） | 权限 + 进程隔离 + 换页 + demand paging |
| 功耗/延迟 | 极低 | 有 TLB miss 代价 |
| 典型场景 | MCU：任务隔离、外设保护、栈保护 | 应用处理器：Linux/Android 等 |

MCU 上要的是 MPU 的"**防呆**"：错误访问当场触发 fault（快失败），而不是污染数据后难查。

### 6. 区域权限与背景区域

- 每个区域（region）可独立设定：基地址、大小、特权/非特权的读/写/执行权限（XN = eXecute Never）、可缓存属性（TEX/C/B 等，架构相关）。
- **背景区域（Background Region）**：未命中任何已定义区域时的默认属性——通常映射整个地址空间的默认访问规则；把背景区域关掉可以做到"白名单"式防护（默认全禁止，仅定义的区域可访问），但漏配哪个区哪里就 fault。
- ECU 上的典型用法：OS/内核区只读（防跑飞改写）、每任务栈限界（栈溢出当场 fault）、外设区按任务授权、代码区 XN 之外全只读。

```plantuml
@startuml
title 核-Cache/TCM-总线-DMA-外设的访问路径与保护点
skinparam defaultFontName "Microsoft YaHei"
package "CPU 核" {
  [执行单元]
}
package "核侧加速与保护" {
  [I-Cache / 预取] as IC
  [D-Cache] as DC
  [MPU 检查] as MPU
}
package "紧耦合内存(私有)" {
  [PSPR / ITCM] as PSPR
  [DSPR / DTCM] as DSPR
}
package "系统互联" {
  [系统总线/矩阵]
}
package "从设备" {
  [共享SRAM]
  [Flash]
  [DMA引擎]
  [外设 SFR]
}
[执行单元] --> MPU
MPU --> IC
MPU --> DC
IC --> PSPR : 命中TCM零等待
DC --> DSPR : 命中TCM零等待
IC --> 系统总线 : miss
DC --> 系统总线 : miss
系统总线 --> 共享SRAM
系统总线 --> Flash
系统总线 --> DMA引擎
系统总线 --> 外设 SFR
DMA引擎 --> 共享SRAM : 绕过CPU cache\n(一致性风险点)
@enduml
```

## 寄存器与位表

### Cortex-M MPU（ARMv7-M，S32K 上存在与否及区域数查对应 RM）

| 寄存器 | 作用 | 关键字段/位 |
|---|---|---|
| MPU_TYPE | 只读能力描述 | DREGION（支持的硬件区域数，S32K 各型号不同，查 RM） |
| MPU_CTRL | 总开关 | ENABLE；PRIVDEFENA（背景区域使能）——位号查 ARMv7-M ARM/RM |
| MPU_RNR | 选择当前配置的区域号 | REGION 域 |
| MPU_RBAR | 区域基地址 | ADDR + VALID + REGION |
| MPU_RASR | 区域属性与大小 | XN（禁止执行）、AP（访问权限编码表查手册）、TEX/C/B（缓存属性）、SRD（子区域屏蔽）、SIZE（区域大小编码）、ENABLE |

AP 权限编码（特权/非特权 × 读/写）与 SIZE 编码表**查 ARMv7-M Architecture Reference Manual 或厂商 RM**，不同核代间有差异。

### TriCore（TC377）

TC1.6P 核内是否有 MPU/范围保护（Range Protection）单元、其寄存器组名称与位定义：**查 TC377 UM 的内存保护相关章节**（TC3xx 体系下保护机制与 Cortex-M 的区域式 MPU 模型不同，不能照搬 M 核的配置思路）。通用结论可先记住：AURIX 的确定性主要靠 DSPR/PSPR 私有性 + lockstep，而不是"给共享存储配权限"这条路。

## 双平台对照

| 维度 | TC377（TriCore TC1.6P） | S32K（Cortex-M4 / M7） |
|---|---|---|
| 指令缓存 | 无传统 I-cache，靠 PFLASH 缓冲/PSPR（以 UM 为准） | M4 无 I-cache（Flash 预取/加速）；M7 带 I-cache（S32K3，容量查 RM） |
| 数据缓存 | 无传统 D-cache，DSPR 充当"显式 D-cache" | M4 无 D-cache；M7 带 D-cache（S32K3） |
| 一致性风险 | 低（DMA 多与 CPU 分区而治，不经过核内 cache） | M7 上 DMA × D-cache 是经典坑点 |
| 内存保护 | 保护机制查 UM（非 Cortex-M 区域模型） | MPU 区域式：M4 可选 8 区、M7 可配 16 区（具体以型号 RM 为准） |
| 栈保护手段 | 软件限界/OS 检查为主（手段查 UM/OS 手册） | MPU 区域做栈护栏，溢出即 fault |
| 典型工程结论 | 功能代码进 PSPR/DSPR，天然确定性 | M7 上对 DMA 缓冲设非缓存区或手动 clean/invalidate |

## 代码/实操

MPU 配置步骤（CMSIS 风格概念示例，寄存器名以厂商头文件为准）：

```c
/* 概念示例：把共享 DMA 缓冲区设为非缓存、全访问 */
/* 1. 使能 MPU（含背景区域与否按需） */
/* 2. 选区域号 -> 写基地址 -> 写属性(大小/AP/非缓存属性) -> 使能该区域 */
/* 3. 执行数据同步屏障后切换任务/退出 handler 生效  */
/* 具体 API：CMSIS 的 ARM_MPU_SetRegion() / ARM_MPU_Enable()，
   属性宏与区域大小编码见对应平台的 MPU 头文件，不手拼位号 */
```

## 易错点与陷阱

1. **DMA 收发偶发出旧/坏数据**：第一反应查 cache——发送侧没 clean（CPU 改的还在 cache 行里），或接收侧没 invalidate（读到 cache 里的旧行）。
2. **非缓存区当万能药**：全片非缓存会显著掉速；只对 DMA 缓冲、核间共享区做非缓存或共享属性。
3. **MPU 区域没覆盖外设地址**：任务一旦访问未授权外设区直接 MemManage fault，白名单模式下漏配哪个区哪里 fault。
4. **背景区域误解**：PRIVDEFENA 打开时特权代码"默认能访问全图"，保护强度取决于你还配了什么；要强隔离就明确规划背景区域语义。
5. **栈保护区域边界设太大**：MPU 区域粒度有限（大小编码 + 对齐要求），护栏和真实栈底之间留不出足够余量，溢出先破坏相邻区再 fault，现场已经难看。
6. **自修改代码/搬运代码后不失效 I-cache**（有 I-cache 的核）：执行到旧指令。MCU 上尽量启动期一次搬完，运行期不做代码替换。

## 面试高频题

1. **写直达和写回的区别？各自适合什么场景？**
   答：写直达同时写 cache 和主存，主存永远一致，适合写少、一致性敏感场景；写回只写 cache 并标脏，换出才写回，写快但需要 clean/invalidate 维护，适合通用计算。MCU L1 多为写回。
2. **DMA 和 CPU cache 的一致性问题怎么产生、怎么解决？**
   答：DMA 直接访主存，CPU cache 里可能有副本：发送方向 CPU 新数据滞留 cache（要先 clean 写回），接收方向 cache 旧行挡住新数据（要先 invalidate）。工程上更稳的是把 DMA 缓冲放非缓存/共享区。
3. **MPU 和 MMU 的区别？MCU 为什么用 MPU？**
   答：MMU 做虚拟地址转换 + 页粒度保护，支撑多进程；MPU 只做区域式权限检查，无转换、低延迟低功耗。MCU 无虚拟内存需求，要的是任务隔离、栈护栏、外设授权的快失败。
4. **什么是背景区域？**
   答：访问未命中任何已配置区域时使用的默认属性（由使能位控制），相当于兜底规则；白名单式配置即关闭背景区域，未定义即禁止。
5. **为什么 TC377 上很少讨论 cache 一致性？**
   答：TC3xx 核以私有 DSPR/PSPR 为主要工作存储，固定地址、不经 cache、单周期访问，没有副本就没有一致性问题；共享资源问题转化为总线带宽与分区规划问题。
6. **如何在 ECU 上用 MPU 保护任务栈？**
   答：给每个任务栈尾部（低地址端）设一小块"禁止写"区域作为护栏，溢出触及护栏立即 fault，handler 里定位任务；比 OS 轮询水印更及时。

## 延伸

- [04-总线与DMA](04-总线与DMA.md)：一致性问题的另一端——DMA 引擎怎么工作
- [05-存储层次](05-存储层次.md)：DSPR/PSPR/TCM 在金字塔中的位置
- [01-寄存器模型](01-寄存器模型.md)：fault 之后先看哪些寄存器
- [ARM-Cortex-M](../../1-L1基础/ARM-Cortex-M/README.md)：M4/M7 MPU 细节
- [多核架构](../../3-L3高级/多核架构/README.md)：核间共享与一致性问题
- [上级目录](../README.md)
- 工程深入场景：S32K3（M7 带 D-cache）项目里 CAN 报文经 DMA 收发，台架偶发"收到旧帧/坏帧"——十有八九是收发两侧没做 invalidate/clean；量产前把 DMA 缓冲改设非缓存 MPU 区域，问题消失，这是本篇一致性口诀最常兑现的场景。
