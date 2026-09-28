# 02-LDF

> 一句话定位：LDF 是 LIN 网的数据库——除了"谁发什么信号"，它还必须回答 CAN 不用回答的问题："**每个帧头几点几分由谁发出**"（调度表）。
> 等级：L2 ｜ 前置：[01-DBC](01-DBC.md)

## 原理

DBC 与 LDF 最本质的分野来自总线机制：CAN 是事件驱动的自由竞争（谁先仲裁谁上），所以 DBC 只需要描述"内容"；LIN 是主从调度的时间触发（主节点按调度表轮询，从节点被点名才说话），所以 LDF 除了内容还要描述"**时间**"——调度表（Schedule Table）是 LDF 独有的灵魂节区。

```plantuml
@startuml
title LDF 双核心：帧定义（内容）+ 调度表（时间）共同决定总线行为
skinparam defaultFontName "Microsoft YaHei"
package "LDF" {
  [节点/信号/帧定义\n(LIN protocol/speed/nodes/\nsignals/frames)] as CONTENT
  [调度表\n(schedules: 按序执行的表项\n+ 每项延时)] as SCHED
}
CONTENT --> SCHED : 表项引用帧 ID
SCHED --> "LIN 主节点软件\n(何时发帧头)" as MASTER
CONTENT --> "LIN 从节点配置\n(哪个 ID 该我应答、怎么排信号)" as SLAVE
MASTER --> SLAVE : 调度表轮询驱动全部通信
@enduml
```

## 详解

### LDF 文件骨架

```text
LIN_description_file;
LIN_protocol_version = "2.2";
LIN_language_version = "2.2";
LIN_speed = 19.2 kbps;                 // 波特率（kbps）

Nodes {                                // 节点：主节点 + 从节点
  Master: CtlMaster, 0.01, 10 ;        // 名字, 时基(ms), 抖动容限(ms)
  Slaves: WindowCtrl, RainSensor, MirrorUnit ;
}

Signals {                              // 信号：位数与初值
  WindowPos: 8, 0;                     // 名字: 长度(bit), 发布值(初值)
  RainLevel: 4, 0;
}

Frames {                               // 帧：谁发布、帧 ID、长度、信号排布
  WindowState: 0x10, CtlMaster, 2 {    // 帧名: 帧ID, 发布者, 字节数
    MasterReq, 0..7;                   // (示意)信号名, 起始位
    WindowPos, 8..15;
  }
  SensorData: 0x11, RainSensor, 1 {
    RainLevel, 0..3;
  }
}

Node_attributes {                      // 从节点属性（时间容差等）
  RainSensor {
    LIN_protocol = "2.2";
    configured_NAD = 0x02;
    ...
  }
}

Schedule_tables {                      // 调度表：通信的时间剧本
  NormalPolling {                      // 表名
    WindowState delay 20 ms;           // 轮询帧 WindowState，槽宽 20ms
    SensorData delay 20 ms;
  }
  DiagMasterReq { MasterReq delay 10 ms; }
  DiagSlaveResp { SlaveResp delay 10 ms; }
  Sleep { MasterReq delay 10 ms; }     // Go-to-Sleep 等
}
```

读 LDF 的顺序：先看 `Nodes`（谁主谁从）→ 再看 `Frames`（每个帧谁发布、装什么信号）→ 最后看 `Schedule_tables`（这些帧按什么顺序、什么槽宽轮询）。**帧不进调度表就永远不会上总线**——这是 DBC 思维转 LDF 时最容易漏的一步。

### 调度表为什么是 LDF 独有

- **CAN**：DBC 里的周期属性（GenMsgCycleTime）只是"建议周期"，实际由各 ECU 自己的 Com 定时器保证，总线上谁先谁后是仲裁结果；
- **LIN**：从节点没有发送主动权，一切节奏由主节点的调度表决定。周期 = 该帧表项在调度表里的**出现频率 × 调度表循环时间**；响应时间也由表项的 `delay`（槽宽）兜底——槽宽必须 ≥ 帧传输时间（break+sync+ID+数据+校验和）+ 容差。

所以 LIN 的"周期抖动"不是电气问题而是**调度设计问题**：把慢信号排进快表浪费带宽，把快信号排进慢表延迟超标——改周期不是改数字，是重排调度表。

### LDF 解析流程直觉

拿到 LDF 后工具（与脑）这样走：

1. 解析协议版本与速率（决定帧时间预算，19.2kbps 一帧 8 字节约 8~10ms）；
2. 建"信号→帧→发布者/订阅者"的内容索引（等价于 DBC 的 BO_/SG_）；
3. 展开调度表：算出每帧的实际轮询周期与最坏响应时间（周期 = 表项间隔，响应 = 槽宽内帧时间）；
4. 一致性检查：帧是否被调度、槽宽是否够、主从时间容差（time_out 等）是否匹配。

### 与 LIN 配置工具链的关联

- **Vector 链**：CANoe.LIN 载入 LDF 直接仿真主节点/从节点（没硬件也能跑全網逻辑）；LINconde/Davinci 类工具从 LDF 生成主节点调度代码；
- **AUTOSAR 链**：EB tresos 等以 LDF 为输入生成 LinIf（含调度表状态机）与 LinDrv 配置——LDF 的 `Schedule_tables` 直接映射为 LinIf 的调度表容器，`Node_attributes` 映射从节点参数；
- **从节点小 MCU**：常由供应商工具从 LDF（或 NCF）生成帧/信号解析表，配合 LinTp/Dcm（见 [02-LinTp](../../2-L2进阶/传输层/02-LinTp.md)）。

## 配置层

| LDF 节区/项 | 含义 | 典型值 | 易错点 |
|---|---|---|---|
| LIN_speed | 总线速率 | 19.2 kbps（低速场景 9.6） | 与硬件 UART 配置不一致→帧错误 |
| Master 时基/抖动 | 调度粒度与抖动容差 | 时基 0.01~0.1ms | 时基过大→槽宽失真 |
| Frames 帧 ID | 帧标识（0~59 数据帧区） | 按矩阵分配 | 0x3C/0x3D 诊断帧被占用→诊断瘫痪 |
| 信号起始位 | 帧内 bit 布局 | 0..N | 主从两端布局不一致→解出鬼值（同 DBC） |
| delay 槽宽 | 表项时间预算 | ≥帧传输时间+余量 | 槽宽不够→响应被下一表项打断 |
| 调度表切换 | 表间迁移（正常/诊断/睡眠） | 按状态机 | 诊断会话中切走→LinTp 腰斩 |
| Node_attributes NAD | 从节点诊断地址 | 0x01~0x0F | 与 LinTp/Dcm 配置不一致 |

## 易错点与陷阱

1. **帧定义了却没进调度表**：从节点万事俱备，主节点永远不点名——信号"存在但从不更新"；改 LDF 时两处要联动。
2. **槽宽按理想帧时间配满**：没留抖动与错误帧重试余量，负载一波动就超时；槽宽预算按"帧时间×1.3~1.4"起步。
3. **调度表切换时机设计错**：正常表↔诊断表↔睡眠表的迁移条件（如收到诊断首帧切诊断表）漏分支，多帧诊断中途掉回正常表，LinTp 直接超时断链。
4. **主从两端 LDF 版本不一致**：供应商从节点用的是旧版 LDF（信号挪位/槽宽不同），联调"偶发错值"；LDF 与 DBC 一样要进版本管理、双向评审。
5. **忽略 Node_attributes 时间容差**：从节点响应慢于主节点 timeout 配置（或反之），表现为周期性无响应帧；时间参数主从必须成对核对。

## 面试高频题

- **Q：LDF 与 DBC 最核心的差异？**
  A：调度表。DBC 只描述内容（报文/信号），时间由各 ECU 自己保证；LIN 从节点无发送主动权，LDF 必须用调度表规定"主节点何时发哪个帧头"，帧的周期与响应时间都由调度表算出。
- **Q：LIN 里某信号周期 50ms 是怎么实现的？**
  A：不是从节点定时发，而是调度表里让该帧的表项以 50ms 间隔出现（或所在调度表循环 50ms 含该表项一次）；改周期=重排调度表。
- **Q：调度表槽宽（delay）怎么定？**
  A：≥ 帧完整传输时间（break+sync+ID+数据+校验和，由波特率算出）+ 主从抖动与重试余量；理想值贴边配是经典翻车点。
- **Q：LDF 在 AUTOSAR 工具链里落到哪些配置？**
  A：调度表→LinIf 的调度容器；帧/信号→LinIf/LinTp 与 Com 的 PDU/Signal 映射；Node_attributes→从节点诊断与时间参数。

## 延伸

- [01-DBC](01-DBC.md)：内容描述的对偶物与对比基准；
- [03-通讯矩阵ARXML](03-通讯矩阵ARXML.md)：LDF/DBC 如何汇入全网络矩阵；
- [LIN](../LIN/README.md)：帧头/响应、调度与校验和的总线层原理；
- [02-LinDrv接口契约](../../../04-MCAL与外设驱动/2-L2进阶/CanDrv与LinDrv/02-LinDrv接口契约.md)：调度表落到驱动层的形态；
- [02-LinTp](../../2-L2进阶/传输层/02-LinTp.md)：0x3C/0x3D 在调度表里的地位。

---

维护约定：笔记命名 `序号-主题.md`；真实截图放 `_images/`；流程/时序/状态/架构图用 PlantUML 内嵌正文，规范见 [图表规范与模板](../../../00-总览/图表规范与模板.md)。
