# 常用 iLLD 接口速查

> 一句话：CDD/裸驱里最常用外设的 iLLD 接口一页速查（Port、GTM TOM PWM、EVADC、ASCLIN、SPI、MCAN、WDT）——所有函数签名**以对应 `Ifx*.h` 头文件为准**，本表只保证"叫什么名、管什么用"。
> 等级：L2 ｜ 前置：[01-iLLD分层设计](01-iLLD分层设计.md)

## 使用前必读

- 本表基于 TC3xx 系 iLLD（随 AURIX Development Studio 交付）；不同版本接口有出入，**动手前打开对应头文件确认签名**；
- 统一用法套路：`IfxXxx_Config` + `IfxXxx_initConfig()` 填默认 → 改成员 → `IfxXxx_init()` 出句柄 → 句柄调操作（见 [01-iLLD分层设计](01-iLLD分层设计.md)）。

## 主速查表

### Port（引脚）

| 类别 | 接口（以 `IfxPort.h` 为准） | 说明 |
|---|---|---|
| 初始化 | `IfxPort_setPinMode(pin, outputMode, padDriver)` | 配输出模式/驱动强度（复用由各外设 init 或 PinMap 完成） |
| 常用操作 | `IfxPort_setPinHigh(pin)` / `IfxPort_setPinLow(pin)` / `IfxPort_togglePin(pin)` | 电平控制 |
| 常用操作 | `IfxPort_getPinState(pin)` | 读输入 |
| 关键配置 | 输出模式（推挽/开漏）、输入模式（上拉/下拉）、pad 驱动等级枚举 | 成员为枚举值，以头文件为准 |

### GTM TOM PWM

| 类别 | 接口（以 `IfxGtm_Tom_Pwm.h` 为准） | 说明 |
|---|---|---|
| 模块级 | `IfxGtm_enable(&MODULE_GTM)` | GTM 总开关（寄存器层内联） |
| 模块级 | `IfxGtm_Tom_Pwm_initModule(...)` | GTM/CMU 侧模块初始化 |
| 通道级 | `IfxGtm_Tom_Pwm_initConfig` → `IfxGtm_Tom_Pwm_initChannel` | 默认值→覆盖→生成句柄 |
| 引脚 | `IfxGtm_Tom_Pwm_initChannelPin(...)` 类接口 | 通道输出到引脚 |
| 常用操作 | `IfxGtm_Tom_Pwm_setDutyCycle` / `setFrequency` / `setDutyCycleTicks` 类 | 运行期改占空/频率 |
| 关键 Config 成员 | `tom`、`channel`、极性/模式、引脚与 pad、中断使能与优先级、周期/占空设置方式 | 成员名以头文件为准 |

（GTM 结构详见 [../GTM/README](../GTM/README.md)）

### EVADC（Enhanced Versatile ADC）

| 类别 | 接口（以 `IfxEvadc_Adc.h` 为准） | 说明 |
|---|---|---|
| 初始化 | `IfxEvadc_Adc_initModule(...)` | ADC 模块级 |
| 初始化 | `IfxEvadc_Adc_initGroup(...)` | 组级（转换模式/采样时间/触发） |
| 初始化 | `IfxEvadc_Adc_initChannel(...)` | 通道级（含输入源） |
| 常用操作 | `IfxEvadc_Adc_startScan(...)` 等扫描启动接口 | 按组/通道发起转换 |
| 常用操作 | 结果读取接口（`IfxEvadc_Adc_get*` 系列） | 查询/取结果 |
| 关键 Config 成员 | 组的转换模式（队列/扫描）、采样时间、分辨率相关、触发源 | 以头文件为准 |

### ASCLIN（UART 用法）

| 类别 | 接口（以 `IfxAsclin_Asc.h` 为准） | 说明 |
|---|---|---|
| 初始化 | `IfxAsclin_Asc_Config` + `IfxAsclin_Asc_init` | 波特率/数据位/停止位/引脚/缓冲 |
| 常用操作 | `IfxAsclin_Asc_write(driver, data, &count, timeout)` | 发送（概念：阻塞式带超时） |
| 常用操作 | `IfxAsclin_Asc_read(driver, data, &count, timeout)` | 接收 |
| 关键 Config 成员 | 波特率、rx/tx 引脚与 pad、缓冲区类型/大小、中断优先级 | 以头文件为准 |

### SPI（QSPI 硬件模块）

| 类别 | 接口（以 `IfxQspi_Spi.h` 为准） | 说明 |
|---|---|---|
| 初始化 | `IfxQspi_Spi_Config` + `IfxQspi_Spi_init` 类（模块/通道两级） | 主/从模式、波特、时钟模式 |
| 常用操作 | 收发交换接口（exchange/发送/接收系列） | 以头文件为准 |
| 关键 Config 成员 | 波特率、CPOL/CPHA、片选（通道级配置）、缓冲与优先级 | 以头文件为准 |

### MCAN（CANFD 硬件为 M_CAN）

| 类别 | 接口（以 `IfxCan*.h` 为准） | 说明 |
|---|---|---|
| 初始化 | 节点级 init 系列（`IfxCan_Node_*`） | 波特率/采样点/引脚/中断 |
| 初始化 | 滤镜配置接口 | 经典 CAN 与 CANFD 帧格式 |
| 常用操作 | 发送/读取报文接口（`IfxCan_*` 系列） | 以头文件为准 |
| 关键 Config 成员 | 节点号、波特率（仲裁/数据段）、环回模式、报文 RAM 布局相关 | 以头文件为准 |

### WDT（看门狗，经 SCU）

| 类别 | 接口（以 `IfxScuWdt.h` 为准） | 说明 |
|---|---|---|
| 初始化 | `IfxScuWdt_getCpuWatchdogPassword()` 类 | 取密码（改配置前必取） |
| 常用操作 | `IfxScuWdt_serviceCpuWatchdog()` | 喂狗（周期任务里调用） |
| 常用操作 | `IfxScuWdt_changeCpuWatchdogConfig(...)` 类 | 改超时时间（密码流程） |
| 关键概念 | CPU 看门狗与安全看门狗分离、密码访问机制、超时窗口 | 以头文件/UM 为准 |

## 与 S32K SDK 的手感对照（速查版）

| 一件事 | TC377 iLLD | S32K SDK（1xx 风格） |
|---|---|---|
| 开一路 PWM | `IfxGtm_Tom_Pwm_initConfig → initChannel → setDutyCycle` | FTM 驱动 init + PWM 更新接口 |
| 串口发一帧 | `IfxAsclin_Asc_write` | LPUART 驱动发送接口 |
| 读 ADC | init 三级 → startScan → get | ADC16 驱动转换/读取 |
| 喂狗 | `IfxScuWdt_serviceCpuWatchdog` | WDOG 驱动喂狗接口 |

## 快速上手路径

1. **AURIX Development Studio（ADS）例程**：新建工程时选择目标芯片的外设例程（UART/PWM/ADC…），例程即填好 Config 的"官方范文"，先跑通再搬到自己工程；
2. **官方 Training 文档**：英飞凌官网/myInfineon 的 AURIX Training 系列（GTM、ADC、CAN 专题），配 iLLD 源码目录 `Libraries/iLLD/...` 阅读；
3. **头文件驱动法**：拿不准就开 `Ifx*.h`，接口注释里通常有用法与参数说明；
4. 需要理解 GTM 全貌时回到本库 [GTM](../GTM/README.md) 目录。

## CDD 里用 iLLD 的 checklist

- [ ] 资源 owner 已确认：该外设/通道/引脚/中断不与 MCAL 冲突（查 EB tresos 配置）；
- [ ] 初始化次序：CDD 的 iLLD init 排在 MCAL 初始化之后，且不做模块级复位/全局时钟重配；
- [ ] `initConfig` 拿默认值再改成员，未初始化的 Config 不上生产线；
- [ ] 中断按 OS 体系登记（ISR 框架 + SRC 优先级核对），不用例程的裸 ISR 写法；
- [ ] 引脚复用只配一次，Port 归属写进设计文档；
- [ ] 运行期只碰自己的句柄，不改别人的通道寄存器；
- [ ] 保留"回退开关"：CDD 对外接口窄、内部实现可整体替换成 MCAL 方案；
- [ ] 版本受控：iLLD 与 ADS 版本、芯片型号匹配，不手改库源文件。

## 面试高频题

**Q1：iLLD 接口的统一使用套路是什么？**
答：四步套路：定义 `IfxXxx_Config` 结构 → 调 `IfxXxx_initConfig()` 填默认值 → 按需修改成员（引脚/波特率/中断优先级等）→ 调 `IfxXxx_init()` 初始化并拿到句柄，之后用句柄调运行期操作接口。切忌不跑 initConfig 直接手填 Config——漏填成员带未定义值上产线。

**Q2：在 CDD 里用 iLLD 与用 MCAL，怎么选、怎么共存？**
答：AUTOSAR 标准分层覆盖的外设走 MCAL（可移植、配置受控）；MCAL 覆盖不了或需要深度定制的外设（如特驱动芯片协议）才用 iLLD 进 CDD。共存纪律：资源 owner 先确认不与 MCAL 冲突（查 tresos 配置）；CDD 的 iLLD init 排在 MCAL 之后且不做全局复位/时钟重配；中断按 OS 体系登记；保留"整体替换回 MCAL"的退路（CDD 对外接口要窄）。

**Q3：TC377 喂狗为什么先要"取密码"？**
答：AURIX 的看门狗经 SCU 管理，配置寄存器带 ENDINIT 保护——修改（含改超时、关模块）前必须先用 `IfxScuWdt_getCpuWatchdogPassword()` 类接口按密码序列解锁，改完自动恢复保护，防止程序跑飞时误改看门狗配置。且 CPU 看门狗与安全看门狗（Safety WDT）分离，后者密码/权限更严。

**Q4：iLLD 接口签名记不准怎么办？工程上的正确做法？**
答：以随芯片包交付的 `Ifx*.h` 头文件为准——不同 iLLD/ADS 版本接口有出入，网上旧例程常对不上。做法：头文件驱动法（接口注释里有用法与参数说明）+ ADS 官方例程当"官方范文"先跑通再搬；版本受控（iLLD 与 ADS、芯片型号匹配），不手改库源文件。

## 延伸

- [iLLD分层设计](01-iLLD分层设计.md) | [iLLD与MCAL的关系](02-iLLD与MCAL的关系.md)
- [GTM](../GTM/README.md) | [TC377平台](../README.md)
- [CDD设计方法论](../../../../04-MCAL与外设驱动/2-L2进阶/CDD设计方法论/README.md)
