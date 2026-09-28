# 02-EB-tresos

> 一句话定位：Elektrobit 家的 BSW 配置生成器——插件式模块管理 + 向导式填参 + 命令行批处理生成，S32K 阵营（S32DS 里可一键调起）的配置主力。
> 等级：L2 ｜ 前置：[01-从敲下编译到烧进板子-工具链全景](../../00-入门导读/01-从敲下编译到烧进板子-工具链全景.md)

## 原理

EB tresos Studio 的骨架是**Eclipse + 插件**：每个 BSW 模块（Com、PduR、CanIf、EcuC……）是一个插件，插件自带三样东西——**schema（参数定义与约束）、编辑器（向导式界面）、Generator（生成模板）**。装了哪个模块插件，才能配哪个模块；Import 工程时缺插件就是第一个报错点。

配置的存储与展现分离：**磁盘上是 ARXML（每个模块一个文件夹一份 .arxml），界面上是向导表单**。校验通过后 Generator 按模板批量吐 C 代码——和 DaVinci 是同一类"图纸机"（对照 [DaVinci-Configurator](01-DaVinci-Configurator.md)），差别在生态：tresos 与 NXP S32K 走得近，S32DS 里集成了 tresos 入口，MCAL 配置（EB tresos 系的 mcal 配置器）与 BSW 配置能串成一条链。

```plantuml
@startuml
title EB tresos：插件式配置与双模式生成
skinparam defaultFontName "Microsoft YaHei"
rectangle "S32DS\n(集成入口)" as S32DS
rectangle "tresos Studio\nGUI 模式" as GUI
rectangle "tresos_cmd.bat\n命令行模式" as CMD
database "模块插件\nschema+编辑器+Generator" as PLUG
file "工程配置\n模块文件夹内 .arxml" as CFG
rectangle "校验" as VAL
folder "生成产物\nBSW Cfg.c/.h" as OUT

S32DS --> GUI : 菜单一键调起
GUI --> PLUG : 按需启停模块
CMD --> CFG : import 工程+generate
PLUG --> CFG
CFG --> VAL
VAL --> OUT : 0 error 放行
OUT --> CI 流水线 : 夜间批量生成
@enduml
```

两个关键直觉：**GUI 和命令行跑的是同一套核心**（GUI 里干的一切，命令行都能复现，CI 才接得进去）；**一个模块一个 ARXML 文件**（diff 与多人协作天然按模块分块）。

## 详解

### 1. 插件式模块管理

| 操作 | 在哪 | 直觉 |
|---|---|---|
| Import 工程 | File → Import | 把已有 ECU 配置工程拉进来；缺模块插件先装 |
| 模块使能/关闭 | 工程属性 → Modules | 裁剪 BSW：不用 SecOC 就整个关掉，不生成代码 |
| 加模块 | 同上勾选 | 勾上后工程里多一个模块文件夹 + 默认 .arxml |
| 插件版本核对 | Help → About / 模块属性 | schema 版本与配置文件版本对不上=报错源头 |

### 2. 向导式参数编辑

- 每个模块打开是**向导页签**：先 Overview（模块状态、Validation 入口、Generator 入口），再按章节展开容器树；
- 表格里改参数，红叉即时校验（值域），黄叹号是跨模块 Warning；
- 与 DaVinci 同一棵"容器树"底层模型，概念见 [容器与参数](../../../07-AUTOSAR架构/2-L2进阶/方法论与ARXML/02-容器与参数.md)；
- **Calculate/Validate 按钮**：改动跨模块后先跑一次校验再生成，别跳步。

### 3. Generator 批量生成

- 单模块生成：模块 Overview → Generate；全工程生成：工程右键 → Generate（多模块按依赖顺序批量跑）；
- 生成目录在工程属性里配（Output/Generated 目录），**生成物不手改**的原则两家工具通用；
- 生成日志逐模块列出文件清单，失败模块的报错要回到 Validation 列表定位。

### 4. 命令行模式（CI 的钥匙）

| 事项 | 说明 |
|---|---|
| 入口 | `tresos_cmd.bat`（Windows；批处理模式，不弹 GUI） |
| 典型命令 | 导入 workspace→ 打开工程→ 计算→ 校验→ 生成，一条脚本串完 |
| 用途 | 夜间构建自动重生成 BSW 代码，保证库里的 ARXML 与代码一致 |
| 注意 | 命令行对插件版本、workspace 路径敏感，CI 机器要装同版本工具+插件 |

### 5. 与 S32DS/NXP S32K 的集成

- S32DS（Eclipse 系）装 NXP 提供的集成插件后，工程里有 AUTOSAR 配置入口**一键调起 tresos**，改完生成直接回到 S32DS 编译；
- S32K 的 MCAL 配置（时钟/引脚/中断，EB 提供的 pinmap 等）与 tresos BSW 配置是配套关系：MCAL 管"芯片级"，tresos 管"BSW 级"，两边版本要配套；
- TC377 阵营常用 DaVinci（见上一篇），双平台工程师的肌肉记忆：**换平台换的是工具皮肤，不变的是"ARXML→校验→生成→编译"四拍**。

## 实操/配置

### 1. 从零打开一个 S32K BSW 工程

1. 装 EB tresos Studio + NXP S32K 的 BSW 插件包（版本跟着 S32DS 集成说明走）；
2. `File → Import` 导入工程（或从模板新建），缺插件的报错先按提示补齐；
3. 工程属性 → Modules：核对需要的模块都勾了（Com/PduR/CanIf/EcuC/OS…）；
4. 逐模块向导里填参 → 点 Validate；
5. `右键工程 → Generate`，看输出日志 0 error；
6. 回 S32DS 编译，生成物进构建。

### 2. 命令行批量生成（供 CI）

| 步骤 | 动作 | 要点 |
|---|---|---|
| 1 | 写批处理脚本调 `tresos_cmd.bat` | 固定 workspace 与工程路径 |
| 2 | import/clean 工程配置 | 从版本库拉最新 ARXML |
| 3 | calculate + validate | 非 0 退出码即失败，CI 拦截 |
| 4 | generate 全工程 | 生成物时间戳写日志 |
| 5 | 触发下游编译 | 与构建系统（Make/CMake）串接 |

### 3. 校验错误定位三板斧

1. **看 Validation 列表第一行**：后面的错误多是第一条的连坐，修完第一条再刷新；
2. **双击错误跳容器**：跳到具体参数位置，对照 schema 描述看值域；
3. **跨模块引用错**（如 PduR 找不到 CanIf 的 Pdu）：先到被引用模块确认定义存在，再回来刷校验。

## 易错点与陷阱

1. **现象：Import 后整个工程红、模块打不开。原因：CI/同事机器缺对应模块插件，或插件版本低于配置 schema 版本。对策：工程 README 固定插件清单与版本；Import 报错信息里看缺哪个模块，装齐再开。**
2. **现象：GUI 里生成成功，CI 命令行报错。原因：命令行环境的 workspace、插件、路径与 GUI 不一致。对策：CI 机器照 GUI 机器配一整套同版本；脚本里先校验插件版本再生成。**
3. **现象：模块勾掉了，编译还报它的符号。原因：生成物没清理，旧代码还躺在输出目录参与编译。对策：重新 Generate 前清输出目录，或在工程属性里配覆盖策略；构建脚本加 clean 步骤。**
4. **现象：改完参数 Validate 绿，板上行为没变。原因：忘了 Generate，或 S32DS 侧增量编译没带上新生成物。对策：Validate→Generate→重编三连拍固化；核对生成文件时间戳与 map。**
5. **现象：校验报几十条错不知从哪下手。原因：上游数据（通讯矩阵/MCAL）变更引发的连坐错。对策：只修"源头类"错误（缺定义/非法值），刷一次再看剩余；一次只动一个模块。**
6. **现象：工具升级后工程满屏 warning。原因：schema 版本升级带来的默认值/新校验规则变化。对策：升级单独开分支做迁移，跑全量校验对比报告，别混在功能改动里提交。**

## 面试高频题

**Q1：EB tresos 怎么接入 CI/自动化构建？**
答：用 `tresos_cmd.bat` 批处理模式：脚本串"导入工程→校验→生成"，非零退出码即失败；生成产物交给下游构建系统编译。关键是 CI 机器装与开发机同版本的工具与模块插件，并把 ARXML 作为唯一配置源码进版本库。

**Q2：tresos 的"模块插件"机制解决什么问题？**
答：解耦与裁剪——每个 BSW 模块的参数定义（schema）、编辑界面、生成模板封装成插件，按需安装启停；不用整个 BSW 全家桶铺开，工程里只配用到的模块，生成的代码也只含用到的部分，RAM/Flash 与维护面都可控。

**Q3：S32DS 和 EB tresos 是什么关系？**
答：分工协作——S32DS 是 NXP 的 IDE（编译/调试/烧录），tresos 是 EB 的 AUTOSAR BSW 配置生成器；NXP 提供集成插件让 S32DS 里一键调起 tresos，改配置、生成 BSW 代码后回到 S32DS 编译。S32K 的 MCAL 配置器也是 EB 系，与 tresos 配套管芯片级配置。

**Q4：校验通过但运行时配置没生效，怎么排查？**
答：沿生成链路查四点：Generate 是否真的跑了（输出目录时间戳）→ 生成物是否参与编译（构建日志/map 里找符号）→ 烧的映像是不是最新（.hex 时间戳）→ 运行时读配置生效点（如 Com 周期在总线上实测）。任何一拍断了都是"看起来改了"。

## 延伸

- [DaVinci-Configurator](01-DaVinci-Configurator.md)——Vector 阵营同位工具，双平台对照着看；
- [配置diff-review](03-配置diff-review.md)——tresos 自带 Compare 的正确用法；
- [ECU配置结构](../../../07-AUTOSAR架构/2-L2进阶/方法论与ARXML/01-ECU配置结构.md)——模块/容器/参数的底层模型；
- [通讯矩阵ARXML](../../../05-汽车网络通讯/1-L1基础/通讯数据库/03-通讯矩阵ARXML.md)——Com/PduR 配置的上游输入；
- [脚本索引](../辅助脚本沉淀/01-脚本索引.md)——ARXML 批处理与报表脚本沉淀目录。
