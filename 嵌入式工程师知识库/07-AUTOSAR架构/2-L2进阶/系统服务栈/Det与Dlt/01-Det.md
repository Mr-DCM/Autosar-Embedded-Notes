# 01-Det

> 一句话定位：Det 是开发期的"BSW 错误黑匣子"——各模块 API 一发现参数/状态不对就 Det_ReportError 上报，调试器断点或串口打印即抓现行，量产一个编译开关裁成零开销。
> 等级：L1→L2 ｜ 前置：[AUTOSAR第一课-一座城的分区图](../../../00-入门导读/01-AUTOSAR第一课-一座城的分区图.md)

## 原理

### Det 的定位：开发期错误追踪

Det（Default Error Tracer）不做存储、不做诊断、不通知任何人——它只是全栈统一的**错误上报汇聚点**。BSW 模块的 API 入口检查失败时（参数非法、状态机不符、初始化未做），调用：

```c
Det_ReportError(uint16 ModuleId, uint8 InstanceId,
                uint8 ApiId, uint8 ErrorId);
```

四个参数一次说清：**哪个模块（ModuleId）、哪个实例（InstanceId）、哪个 API（ApiId）、什么错（ErrorId）**。错误码语义在各模块 SWS 的错误表里定义（如 `CANIF_E_PARAM_POINTER`）。

```plantuml
@startuml
title Det：错误上报的汇聚与出口
skinparam defaultFontName "Microsoft YaHei"
[BSW 模块 API\n(CanIf/NvM/Os…)] as API
[API 入口检查] as CHK
[Det_ReportError] as DET
[默认实现\n(空/计数)] as DEF
[集成层出口\n(任选/组合)] as OUT
API --> CHK
CHK --> DEF : 检查通过 → 正常执行
CHK --> DET : 检查失败 → 上报
DET --> OUT : ①调试器断点\n②串口/trace 打印\n③计数器/转 Dlt 日志
note right of DET : Det 本身无策略：\n怎么用这些错误，集成者说了算
end note
@enduml
```

### 与 Dem 的区别：两个"报错"别再混

| 维度 | Det（开发错误追踪） | Dem（诊断事件管理） |
|---|---|---|
| 抓什么 | **开发期错误**：参数错、时序错、状态机错（集成 bug） | **运行期故障**：传感器失效、通讯丢失、过压（产品故障） |
| 谁上报 | BSW 模块 API 入口检查 | 应用/BSW 按故障逻辑主动报 |
| 去哪里 | 调试器/串口/计数器（给开发者） | DTC 存储、UDS 19 服务（给售后/诊断仪） |
| 生命周期 | 开发期开、量产裁 | 量产必须保留 |
| 典型条目 | `DET_E_PARAM_POINTER` | `P0601 CAN 通讯丢失` |
| 是否存储 | 不存（或仅计数） | 存 NvM（快照/老化/里程） |

一句直觉：**Det 抓"代码写错了"，Dem 记"车坏了"**。

## 详解

### 开发期：两种抓现行的方法

**方法一：调试器断点（最直接）**

在 Det_ReportError（或集成的 Hook 函数）下断点，触发即停下——看调用栈直接回到出错现场：

```c
/* 集成层：把断点下在真正干活的钩子上 */
void Det_ErrorHook(uint16 mid, uint8 iid, uint8 api, uint8 err)
{
    /* 空函数，纯断点锚点 */
    volatile uint16 trap = mid;  /* 看变量防被优化 */
}

void Det_ReportError(uint16 ModuleId, uint8 InstanceId,
                     uint8 ApiId, uint8 ErrorId)
{
    Det_ErrorHook(ModuleId, InstanceId, ApiId, ErrorId);
}
```

**方法二：串口打印集成（无调试器/路试场景）**

把四个 ID 转成一条 trace 文本走串口（或 Dlt，见 [02-Dlt](02-Dlt.md)）：

```c
void Det_ErrorHook(uint16 mid, uint8 iid, uint8 api, uint8 err)
{
    (void)printf("[DET] M=%03u I=%u API=%03u E=%03u\n",
                 mid, iid, api, err);   /* 映射表把 ID 翻成名字更佳 */
}
```

路试/台架联调时 Det 消息随日志流出来，配合时间戳还原"哪个调用在什么时序下被拒"——比事后猜调用序高效得多。

### 量产裁剪：零开销

- **编译期裁**：DetEnable=FALSE（或预处理开关）时，`Det_ReportError` 宏/函数体为空——调用点还在但**零运行开销**，代码体积也缩；
- **运行期关**：DetEnable 运行时开关，便于同一版本在台架开、路试关；
- **折中留计数**：量产保留计数器实现（每 ModuleId×ApiId 一个计数字），售后分析"历史上有没有报过错"，开销极小。

典型配置梯度：Debug 版（全开+打印）→ 台架版（开+计数）→ 量产版（裁或仅计数）。

## 配置层

| 配置项 | 含义 | 典型值 | 易错点 |
|---|---|---|---|
| DetEnable | 总开关（决定上报是否生效） | 开发 TRUE / 量产 FALSE | 量产忘关：白耗 CPU（每 API 都检查） |
| Det_ErrorHook / 回调挂钩 | 错误回调（断点/打印锚点） | 集成实现 | 钩子里做重活：把 API 调用时序拖变形 |
| 各模块 DetDevErrorDetect | 模块级开发错误检测开关 | 关键模块开 | 全模块全开：CPU 被检查吃掉几个百分点 |
| ModuleId 分配表 | 模块编号（Det 分配） | 按 AUTOSAR 规范表 | 自研模块乱占号，日志翻译错位 |
| 打印映射表 | ID→名字翻译 | 数组/脚本生成 | 只打数字没映射：现场对着 SWS 查表抓瞎 |
| 量产计数模式 | 计数器替代上报 | 常开 | 计数器无溢出保护：诊断读数失真 |

## 易错点与陷阱

1. **把 Det 当故障存储用**：想从 Det 里读"DTC"——它不存储不诊断，产品故障必须走 Dem/UDS；Det 只服务开发过程。
2. **量产忘裁**：DetEnable 和全模块 DetDevErrorDetect 都开着，每个 API 调用多一轮参数检查，CPU 白烧、时序变慢，还可能引发新的时序问题；量产配置评审单列此项。
3. **钩子里做重活**：在 Det 回调里刷屏 printf/写 Flash，把出错现场后的时序完全改变——问题"一挂断点就消失"；钩子只置标志/环形缓冲。
4. **只打数字不打名字**：现场拿到一串 ID 没有映射表，查错效率暴跌；维护 ID→名字映射（生成脚本随配置发布）。
5. **跨核 Det 汇聚无序**：多核各自上报，日志时间线交错难读；按核打标签或分通道输出。
6. **Det 报错但没人看**：台架日志里 Det 消息常年堆积无人分析，真正要紧的参数错被噪声淹没；每日构建日志扫描 Det 计数列为质量门禁。

## 面试高频题

- **Q：Det 和 Dem 的区别？**
  A：Det 抓开发期错误（BSW API 参数/状态检查失败，给开发者，可裁剪）；Dem 管运行期故障（产品级 DTC 存储、UDS 读取、快照老化，量产保留）；一个抓"代码写错"，一个记"车坏了"。
- **Q：Det_ReportError 的四个参数是什么？**
  A：ModuleId（哪个模块）、InstanceId（哪个实例）、ApiId（哪个 API）、ErrorId（什么错误）；错误码语义查各模块 SWS 错误表。
- **Q：量产版 Det 怎么处理才是"零开销"？**
  A：编译期裁剪（DetEnable=FALSE，宏展开为空）；若需售后观测可留计数器实现，开销为每 API 一次数组自增。
- **Q：开发期怎么高效利用 Det？**
  A：在集成 Hook 上下断点抓调用栈；或接串口/Dlt 打印带时间戳，联调时序类问题（"某 API 在错误状态被调用"）一抓一个准。

## 延伸

- [02-Dlt](02-Dlt.md)：Det 出口的日志化与远程抓取；
- [Hook](../Os/04-Hook.md)：ErrorHook 报 OS 错误的同款思路；
- [WdgM 监督实体与checkpoint](../WdgM/01-监督实体与checkpoint.md)：另一类"开发期可观测"机制；
- [AUTOSAR第一课-一座城的分区图](../../../00-入门导读/01-AUTOSAR第一课-一座城的分区图.md)：Det 在服务栈中的位置。
