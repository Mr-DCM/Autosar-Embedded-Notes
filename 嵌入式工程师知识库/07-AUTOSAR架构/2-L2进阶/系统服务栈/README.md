# 系统服务栈

> 上级目录：[07-AUTOSAR架构](../../README.md)
> 主等级：L2

## 定位

Os/EcuM/BswM/WdgM/Det/Dlt 服务栈模块。

## 子目录

| 目录 | 定位 |
|---|---|
| [Os](Os/README.md) | 任务与调度、事件与资源、Alarm 与 ScheduleTable、Hook、多核。 |
| [EcuM](EcuM/README.md) | flex vs fixed、上下电时序、唤醒源。 |
| [BswM](BswM/README.md) | 模式仲裁与规则配置。 |
| [WdgM](WdgM/README.md) | 监督实体与 checkpoint、失效响应。 |
| [Det与Dlt](Det与Dlt/README.md) | Det 错误追踪、Dlt 日志。 |

---

维护约定：笔记命名 `序号-主题.md`；真实截图放 `_images/`；流程/时序/状态/架构图用 PlantUML 内嵌正文，规范见 [图表规范与模板](../../../00-总览/图表规范与模板.md)。
