# Dcm配置

> 上级目录：[06-诊断与标定](../../README.md)
> 主等级：L2

## 定位

DSL/DSD/DSP 分层、DID 路由、会话与安全配置。

## 计划笔记

- [x] 01-DSL-DSD-DSP分层.md
- [x] 02-DID路由.md
- [x] 03-会话与安全配置.md

## 已完成笔记

| 序号 | 标题 | 等级 | 前置 | 一句话定位 |
|---|---|---|---|---|
| 01 | [DSL-DSD-DSP分层](01-DSL-DSD-DSP分层.md) | L2 | [从诊断仪的一次连接说起](../../00-入门导读/01-从诊断仪的一次连接说起-诊断全景.md) | 总机—分机台—业务员三层职责、22 请求穿三层 sequence、DslBuffer/DspBuffer、三类静态表与 MainFunction 周期模型 |
| 02 | [DID路由](02-DID路由.md) | L2 | [01-DSL-DSD-DSP分层](01-DSL-DSD-DSP分层.md) + [SID22-读DID](../../1-L1基础/UDS协议/SID22-读DID.md) | DID→数据源三通道（RTE/Dem/NvM）、DcmDspDid 三层引用链、读写分离与连读、四道门禁 NRC 判定 |
| 03 | [会话与安全配置](03-会话与安全配置.md) | L2 | [01-DSL-DSD-DSP分层](01-DSL-DSD-DSP分层.md) | 三会话/锁 0-1-2 权限矩阵、S3Server 保活、P2/P2* 与 0x78 挂起时序、切会话跌锁 0 副作用 |

---

维护约定：笔记命名 `序号-主题.md`；真实截图放 `_images/`；流程/时序/状态/架构图用 PlantUML 内嵌正文，规范见 [图表规范与模板](../../../00-总览/图表规范与模板.md)。
