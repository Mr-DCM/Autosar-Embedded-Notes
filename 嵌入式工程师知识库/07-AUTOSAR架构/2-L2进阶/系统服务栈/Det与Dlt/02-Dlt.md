# 02-Dlt

> 一句话定位：Dlt 是 AUTOSAR 的标准化日志协议——分级、带上下文、可远程从诊断口（CAN/以太网）抓取，CANoe/DLT Viewer 连上就能看整车日志，是 printf 调试的正规军版本。
> 等级：L2 ｜ 前置：[01-Det](01-Det.md)

## 原理

### Dlt 的定位：结构化日志管道

printf 是"往串口扔一行文本"；Dlt 是"把日志当数据管道运营"：应用注册 AppID/ContextID，打日志时带级别，经过缓冲、过滤、协议封装，从诊断口输出——**车还在跑、诊断仪还连着，日志实时流出来**。

```plantuml
@startuml
title Dlt 日志管道：从代码到上位机
skinparam defaultFontName "Microsoft YaHei"
[SWC / BSW 模块] as APP
[Dlt 用户 API\nDlt_LogString 等] as API
[Dlt 缓冲与过滤\n(按 level/context)] as BUF
[协议封装\nAppID+CtxID+level+时间戳] as PKG
[传输：DoIP/以太网\n或 CAN 诊断通道] as NET
[CANoe / DLT Viewer] as PC
APP --> API : 带级别的日志调用
API --> BUF
BUF --> PKG : 过滤通过的
PKG --> NET
NET --> PC : 标准协议帧\n可远程/可分级过滤
note right of BUF : 过滤在 ECU 内完成：\n低级别日志根本不上总线\n不占诊断带宽
end note
@enduml
```

### 核心 API 与身份体系

- **身份**：`Dlt_RegisterApplication(APPID, 描述)` + `Dlt_RegisterContext(ctx, ...)`——AppID 粗分模块（如 `PWR`），ContextID 细分场景（如 `PWR.INIT` / `PWR.RUN`）；
- **打日志**：`Dlt_LogString(ctx, logLevel, "...")`（带格式化文本）；配套 Raw/Binary 接口传原始数据；
- **级别**（用户可定义 log level，常用集）：FATAL / ERROR / WARN / INFO / DEBUG / VERBOSE——每条日志自带级别，级别过滤由配置+运行时设置共同决定。

### 与 printf 调试对比

| 维度 | printf/串口 | Dlt |
|---|---|---|
| 硬件依赖 | 专用调试串口线、拆车接探头 | 走诊断口（CAN/以太网），整车状态即可抓 |
| 时序影响 | 阻塞发送常见，拖慢真实时序 | 缓冲+异步发送，可控 |
| 可分级 | 无，全打或全关 | FATAL~VERBOSE 分级，运行时可调 |
| 可过滤 | 无 | 按 AppID/ContextID/level 三维过滤 |
| 远程/多 ECU | 一车一串口 | 诊断网络上一并收集，多 ECU 时间线对齐 |
| 格式 | 裸文本 | 协议帧：ID+级别+时间戳，机器可解析 |
| 裁剪 | 手删代码 | 配置级开关 |

一句话：**printf 是给自己看的草稿纸，Dlt 是给团队和产线看的档案系统**。

### 抓取工具一句

上位机用 **DLT Viewer**（GENIVI/COVESA 开源）或 **CANoe**（挂 DLT/DoIP 分析窗）连接 ECU，即可实时查看、按 AppID/Context/级别过滤、离线回放——诊断口里跑的就是标准 DLT 协议帧。

## 详解

**log level 的运行时控制流**：上位机经控制报文（SetLogLevel）下发"某 Context 只收 WARN 以上"——ECU 内 Dlt 立即按新级别过滤，**被滤掉的日志不打包不发送**，诊断带宽只留给真消息。这是"开着日志跑路试"也能不拖累时序的关键。

**典型配置节奏**：开发版 VERBOSE 全开（配合 Det 钩子输出，见 [01-Det](01-Det.md)）；台架版 INFO；量产版 ERROR/FATAL 常开（关键故障可追溯），DEBUG 类靠开关按需打开。

**与 Det 的配合**：Det 钩子里调 Dlt 输出一条带级别的错误日志——Det 负责"发现"，Dlt 负责"运输"，开发期一条链路打通：BSW 参数错 → Det_ReportError → Dlt ERROR 帧 → CANoe 时间线上一条红。

**缓冲策略**：日志风暴（如循环里误打 VERBOSE）会撑爆环形缓冲——新消息丢弃或覆盖旧消息（按配置）；打日志前想一句"这条线最坏每秒出现多少次"。

## 配置层

| 配置项 | 含义 | 典型值 | 易错点 |
|---|---|---|---|
| DltApplication（AppID） | 应用身份 | 每模块一个，3~4 字符 | AppID 重号：日志归属混乱 |
| DltContext（ContextID） | 场景细分 | INIT/RUN/DIAG | 一模块一 Context 打天下：没法按场景过滤 |
| DltDefaultLogLevel | 默认输出级别 | 开发 VERBOSE / 量产 ERROR | 默认级别即生效上限，忘调量产留 VERBOSE |
| Dlt 缓冲深度 | 环形缓冲条数 | 按峰值日志率×传输延迟 | 太浅：突发日志丢头几条（恰恰是案发第一条） |
| 传输通道绑定 | 走哪个 PduR/SoAd 通道 | DoIP over Ethernet 常见 | 通道未随诊断栈初始化：起车日志全丢 |
| Dlt use timestamps / ECU ID | 帧内标识 | 开 | 多 ECU 混流时没 ECU ID：分不清谁说的 |
| 运行时控制 | SetLogLevel/GetLogInfo | 支持 | 只会全开全关：白白占满诊断口 |

## 易错点与陷阱

1. **在中断/关键区打日志**：Dlt API 非中断安全（要拿缓冲锁），在 ISR/持 SpinLock 时调用轻则丢日志重则死锁；ISR 里置标志，任务里补打。
2. **循环里打 VERBOSE 忘关**：量产默认级别没调，日志风暴撑爆缓冲+占满诊断口，真错误被淹；默认级别随版本配置走，不靠人记。
3. **缓冲深度不足**：突发故障的头几条（最有价值）被环形覆盖；按最坏日志率×传输窗口估缓冲，或故障场景单独通道。
4. **传输通道初始化时序错**：Dlt 起得比以太网/诊断栈早，启动期日志全丢；启动早期日志走本地缓冲，链路就绪后再冲刷（或接受丢失并记录水位）。
5. **AppID/ContextID 规划随意**：跨团队重号、命名无语义，后期过滤/检索全靠人肉；立项时定命名表并入配置评审。
6. **拿 Dlt 当实时性工具**：异步缓冲意味着日志顺序≈但不严格等于事件顺序，时间戳粒度也有限；精确时序问题用 GPIO/示波器或 OS trace。

## 面试高频题

- **Q：Dlt 和 printf 调试的本质区别？**
  A：Dlt 是标准化日志协议：带 AppID/Context/级别、ECU 内先过滤再经诊断口（CAN/以太网）异步输出，可远程、可分级、多 ECU 对齐；printf 是裸串口文本，阻塞、不可分级、需专用调试线。
- **Q：Dlt 的级别过滤在哪里生效？为什么不占满诊断口？**
  A：ECU 内部：每条日志先按（AppID/Context/运行时 level）过滤，被滤掉的封装都不做、不上总线；上位机还能经控制报文动态调级别。
- **Q：Det 和 Dlt 怎么配合？**
  A：Det 负责发现开发错误（参数/状态检查失败），集成层在 Det 钩子里调 Dlt 输出 ERROR 日志——发现+运输一条链，错误直接出现在 CANoe/DLT Viewer 时间线上。
- **Q：量产版 Dlt 应该怎么配？**
  A：默认级别收到 ERROR/FATAL（关键故障可追溯），DEBUG/VERBOSE 按需运行时打开；缓冲按峰值日志率配置；确保通道随诊断栈正常初始化。

## 延伸

- [01-Det](01-Det.md)：错误的"发现端"；
- [Hook](../Os/04-Hook.md)：OS 错误接入日志链路的另一入口；
- [通讯服务栈目录](../../通讯服务栈/README.md)：传输通道背后的 PduR/SoAd/诊断栈；
- [AUTOSAR第一课-一座城的分区图](../../../00-入门导读/01-AUTOSAR第一课-一座城的分区图.md)：Dlt 在服务栈中的位置。
