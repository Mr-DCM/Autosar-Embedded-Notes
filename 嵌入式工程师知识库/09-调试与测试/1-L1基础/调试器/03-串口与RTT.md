# 03-串口与RTT

> 一句话定位：不停核的旁路日志——UART 打印便宜稳定，RTT 借调试口走 RAM 环形缓冲几乎零开销，两者是 TRACE32 停核式调试的日常互补。
> 等级：L1→L2 ｜ 前置：[TRACE32](01-TRACE32.md)

## 原理

打印日志的本质是"把芯片内部状态低成本地漏给 PC"。UART 走专用引脚按波特率逐位发；RTT（Real-Time Transfer）则只让目标程序往一块 **RAM 环形缓冲区**写指针级数据，"搬运工"是调试探针——它经 DAP/JTAG 在后台周期性读走缓冲，目标 CPU 全程不停、不进中断服务级耗时。

```plantuml
@startuml
title 两条日志通路：UART vs RTT
skinparam defaultFontName "Microsoft YaHei"
participant "应用代码\nprintf(\"x=%d\", x)" as APP
participant "UART 驱动\n(TC377 ASCLIN / S32K LPUART)" as UART
participant "RTT 缓冲\nDSRAM 环形 buffer" as RTT
participant "PC 端" as PC

APP -> UART : 逐字节阻塞/DMA发送
UART -> PC : TX 引脚 → USB 转串口 → 终端\n代价：字节级耗时，误配波特率即乱码

APP -> RTT : memcpy 进环形缓冲(微秒级)
RTT -> PC : 探针经 DAP 后台轮询读走\nTRACE32/J-Link Viewer 显示，目标不停核
@enduml
```

## 详解

### 1. UART 打印：先解决"怎么打"

- **重定向**：`printf` → `fputc`/`_write` → FIFO → UART 驱动。AUTOSAR 工程里更常见是绕开 libc，直接用自写 `dbg_print(fmt, ...)`（可裁剪、无堆依赖）；
- **发送方式三档**：轮询（最简单、阻塞最狠）→ 中断 FIFO（折中）→ DMA（busy 位轮询零拷贝）。调试日志推荐"DMA + FIFO 满 8 字节触发"，单条日志阻塞微秒级；
- **TC377 用 ASCLIN，S32K 用 LPUART**：注意引脚复用（IOCR/PORT PCR）与核间归属——日志驱动固定跑在 CPU0（Shell 核），别让三个核抢同一个 UART。

### 2. RTT：结构与开销

- SEGGER RTT 提供**上行缓冲**（target→host，日志主通道）与**下行缓冲**（host→target，可当命令通道）；
- 写入端是普通内存写 + 环形指针更新，**关中断窗口纳秒级**；读端由探针后台轮询，`RTT_ControlBlock` 放固定地址（链接段指定），工具按符号找缓冲；
- 不只是 J-Link 专属：TRACE32 也有 RTT 支持（`TOOL.rttdump` 类命令/RTT 窗口），AURIX 上探针经 DAP 读同一块 RAM 即可。

### 3. 三通道对比（什么时候用哪个）

| 维度 | UART 打印 | RTT | TRACE32 停核 |
|---|---|---|---|
| 目标开销 | 中（每字节 87µs@115200 起步，DMA 可摊薄） | 极低（内存写） | 零（但停核改变时序） |
| 侵入性 | 占 UART 引脚 | 只占 RAM 几 KB | 无 |
| 看什么 | 长期趋势、量产排障口 | 高频状态、时序敏感路径 | 精确变量/栈/寄存器现场 |
| 门槛 | 一根线一个终端 | 需探针在线 | 需探针+ELF |
| 典型坑 | 波特率错→乱码 | 缓冲溢出丢行 | 停核喂狗超时复位 |

### 4. 日志分级与节奏（比通道更重要）

约定 `LOG_ERR/WRN/INF/DBG` 四级 + 模块前缀（如 `[CAN][E]`），默认级别编译期可裁剪；每条带时戳（OS tick 或 GPT 自由计数器）与上下文（任务名/核号）。**高频路径用"计数器 + 周期汇总"代替逐次打印**——否则 100µs 周期的任务自己把日志刷爆。

## 实操/配置

### 1. UART bring-up 步骤（TC377 + ASCLIN）

1. 确认引脚：ASCLIN 选型 + IOCR 配置输出方向（如 P14.1/P14.0）；
2. 配置 115200-8-N-1：`ASCLIN_x_FBGR` 分频按内核时钟算（算错波特率=乱码第一嫌疑人）；
3. 先裸发 `dbg_puts("boot ok")` 验证物理链路，再挂 printf；
4. PC 端终端工具（Tera Term/putty）同参数打开 USB 串口。

### 2. RTT 集成步骤

1. 工程(开发主机侧)拉入 `SEGGER_RTT.c/h`；
2. 链接脚本把 `__SEGGER_RTT` 放固定地址段（可选但利于工具快速定位）；
3. `SEGGER_RTT_ConfigUpBuffer(0, "Term", buf, 2048, SEGGER_RTT_MODE_NO_BLOCK_SKIP)`；
4. 常用 API 速查：

| API | 用途 |
|---|---|
| `SEGGER_RTT_printf(0, fmt, ...)` | 格式化上行（自带裁剪版 printf） |
| `SEGGER_RTT_WriteString(0, s)` | 整串写入 |
| `SEGGER_RTT_HasKey()` / `GetKey()` | 下行命令通道 |
| `SEGGER_RTT_SetTerminal(1)` | 多终端窗口切换 |

5. PC 端：J-Link RTT Viewer 或 TRACE32 RTT 窗口连接即可看流。

### 3. 常用终端/工具快捷键

| 工具 | 常用操作 |
|---|---|
| Tera Term | 日志回滚查看、时间戳插件、自动保存到文件 |
| J-Link RTT Viewer | Terminal 0/1 切换、缓冲大小设置、快照保存 |
| TRACE32 | RTT 窗口持续滚动；配合 `Data.SAVE` 导整段缓冲 |

## 易错点与陷阱

1. **现象：串口输出乱码。原因：波特率分频按错时钟（以为 100MHz 实际 120MHz）。对策：按 ASCLIN/LPUART 手册重算分频；先固定发 `U` 字符用示波器量位宽反推实际波特率。**
2. **现象：偶发日志"吞行"或交叠。原因：多任务/多核并发写同一 UART 无互斥。对策：发送入口加短临界区或每核独立缓冲轮转输出；AUTOSAR 下经统一 Shell/Log 模块串行化。**
3. **现象：加了打印问题就消失。原因：打印耗时改变了时序（原竞态窗口被掩盖）。对策：换 RTT 或 DMA 降低开销复现；时序敏感路径改计数器+事后 dump，不逐条打印。**
4. **现象：RTT 日志丢头几行。原因：探针连接晚于程序启动，早期数据已被环形覆盖或工具还没绑定 ControlBlock。对策：加大缓冲、探针先连再放核；或启动早期先写一个 magic 帧标记起点。**
5. **现象：RTT 缓冲写满后行为怪异。原因：NO_BLOCK_SKIP 会整行丢弃，BLOCK_IF_FIFO_FULL 会阻塞卡死实时任务。对策：日志路径必须用 SKIP 模式；BLOCK 模式仅限初始化阶段。**
6. **现象：量产车没法接探针。原因：RTT 依赖探针在线。对策：保留 UART（或经网关 DoIP/CAN 拉日志）作为量产通道，RTT 只做台架开发期。**

## 面试高频题

**Q1：为什么说 RTT 比 printf 串口开销低？**
答：printf 串口每个字节都要走外设按波特率逐位移出（115200 下 1KB 日志约 90ms），阻塞或占中断；RTT 只把数据 memcpy 进 RAM 环形缓冲（微秒级），搬运由探针经调试口后台完成，CPU 全程不停核不占外设，适合时序敏感路径。

**Q2：调试时加打印问题就消失，怎么办？**
答：典型的"观察者效应"——打印耗时改变了竞态时序。对策：一是把打印换成更低开销的 RTT 或纯计数器 + 停机后 dump；二是用硬件观察点（`Break.Set /ACCESS WRITE`）代替打印抓写现场；三是打印内容改写地址到固定内存区，事后一次性导出。

**Q3：UART、RTT、TRACE32 各自的适用场景？**
答：UART——量产/无探针环境的长期日志与现场排障；RTT——开发期高频状态观测、时序敏感代码；TRACE32——需要看变量/栈/寄存器精确现场、抓 Trap 与内存踩踏。三者互补，成熟项目三个都留。

**Q4：日志系统的最低工程要求是什么？**
答：分级可裁剪（ERR/WRN/INF/DBG 编译期开关）、带时戳与任务/核上下文、输出串行化（多任务安全）、高频路径用计数器汇总而非逐条打印、有统一前缀便于过滤。

## 延伸

- [TRACE32](01-TRACE32.md)——日志不够用时停核看精确现场；
- [DAP-JTAG-SWD](02-DAP-JTAG-SWD.md)——RTT 数据走的那几根线到底怎么工作；
- [内存泄漏与越界排查](../../../01-编程语言/2-L2进阶/内存管理/06-内存泄漏与越界排查.md)——日志+内存导出配合抓踩踏；
- [Trap定位方法](../../../02-芯片与体系结构/3-L3高级/异常与Trap/02-Trap定位方法.md)——程序跑飞时日志的最后几行是关键线索。
