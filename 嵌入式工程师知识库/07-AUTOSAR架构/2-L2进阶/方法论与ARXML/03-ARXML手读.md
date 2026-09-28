# 03-ARXML手读

> 一句话定位：拿一段真实的 CanIf/Os 配置，从"打开文件两眼一黑"练到"三招定位任意配置"——缩进层级怎么找、SHORT-NAME/DEFINITION-REF/VALUE 三板斧怎么搜、ADMIN-DATA 里藏着谁改的，最后留一道手读练习。
> 等级：L2 ｜ 前置：[容器与参数](02-容器与参数.md)

工具 GUI 看配置是"单点查询"，手读 ARXML 是"全量巡视"。场景很现实：客户丢来一个 5MB 的 `.arxml` 问"你们这版改了啥"；服务器上的配置比本地新，怀疑有人偷改；生成的 C 代码里一个值很怪，要回溯到配置源头——这些时候没有工程环境，只有文件和文本编辑器。

## 原理

### 缩进层级找法：先 MODULE-CONFIGS，再容器树

一份 ECUC arxml 的骨架永远是这个顺序，先在脑子里装好"地层图"：

```
<AUTOSAR ...schema 声明...>
  <AR-PACKAGES>                       ← 第一层：包结构
    <AR-PACKAGE>
      <SHORT-NAME>CanIf</SHORT-NAME>  ← 模块名（值树根，如 /CanIf/...）
      <ELEMENTS>
        <ECUC-MODULE-CONFIGURATION-VALUES>   ← 模块配置总入口
          <SHORT-NAME>CanIf</SHORT-NAME>
          <DEFINITION-REF ...>/AUTOSAR/EcucDefs/CanIf</DEFINITION-REF>
          <CONTAINERS>
            <ECUC-CONTAINER-VALUE>CanIfGeneral ...</ECUC-CONTAINER-VALUE>   ← 分组抽屉
            <ECUC-CONTAINER-VALUE>CanIfInitCfg ...                          ← 分组抽屉
              <SUB-CONTAINERS>
                <ECUC-CONTAINER-VALUE>CanIfTxPduCfg_EngSpd ...              ← 多重实例
                  <PARAMETER-VALUES> ... / <REFERENCE-VALUES> ...           ← 叶子
              </SUB-CONTAINERS>
          </CONTAINERS>
  <ADMIN-DATA>                        ← 附录：工具与修订信息
</AUTOSAR>
```

找法口诀：**`ECUC-MODULE-CONFIGURATION-VALUES` 定模块 → `CONTAINERS/SUB-CONTAINERS` 下容器树 → `PARAMETER-VALUES/REFERENCE-VALUES` 是叶子**。缩进一层=树深一层；折叠所有 `<PARAMETER-VALUES>` 之类的大块，先看容器骨架，再展开目标分支——5MB 文件也能十秒内定位到模块。

### 快速定位三招（搜索关键词）

| 招 | 搜什么 | 解决什么问题 |
|---|---|---|
| ① 搜 `SHORT-NAME` | 实例名，如 `CanIfTxPduCfg_EngSpd` | 已知"是哪条配置"（GUI 里看到过名字/报文代号），直接跳到节点 |
| ② 搜 `DEFINITION-REF` 尾段 | 定义名，如 `/CanIfTxPduCanId<` | 只知道"什么类型的参数"（如所有 CanId 参数），一网打尽同类 |
| ③ 搜 `VALUE` | 具体值，如 `>291<` | 反查："生成代码里的 291 是从哪个参数来的" |

三招组合拳示例：生成代码里见 `0x123`（291）→ 搜 `>291<` 命中数处 → 看命中行的父节点 `DEFINITION-REF` 尾段是不是 `CanIfTxPduCanId` → 顺 SHORT-NAME `CanIfTxPduCfg_EngSpd` 认出是哪条报文。闭环。

## 详解

### 走读：一段 Os 配置

```
<ECUC-CONTAINER-VALUE>
  <SHORT-NAME>TaskEt_10ms</SHORT-NAME>              ← ① 实例名：10ms 任务
  <DEFINITION-REF DEST="ECUC-PARAM-CONF-CONTAINER-DEF">
    /AUTOSAR/EcucDefs/Os/OsTask</DEFINITION-REF>    ← ② 抽屉类型：Os 的 Task 定义
  <PARAMETER-VALUES>
    <ECUC-NUMERICAL-PARAM-VALUE>
      <SHORT-NAME>OsTaskActivation</SHORT-NAME>
      <DEFINITION-REF .../OsTaskActivation</DEFINITION-REF>
      <VALUE>1</VALUE>                              ← ③ 单次激活排队数=1
    </ECUC-NUMERICAL-PARAM-VALUE>
    ...
  </PARAMETER-VALUES>
  <REFERENCE-VALUES>
    <ECUC-REFERENCE-VALUE>
      <SHORT-NAME>OsTaskScheduleRef</SHORT-NAME>
      <VALUE-REF>/Os/OS/SchTbl_10ms</VALUE-REF>     ← ④ 它挂在哪个调度表
    </ECUC-REFERENCE-VALUE>
  </REFERENCE-VALUES>
</ECUC-CONTAINER-VALUE>
```

一眼读出四件事：这是 `TaskEt_10ms` 任务；激活排队 1 次；挂在 `SchTbl_10ms` 调度表上；整段属于 Os 模块值树。手读的目标就是练成这样"扫一眼出结论"。

### ADMIN-DATA 与工具信息

文件尾/头部的 `<ADMIN-DATA>` 记录生成工具与版本（`<SW-Tool>`、工具版本、时间戳），tresos 导出的文件常带 `LANGUAGE`/`SDG` 工具扩展段。用途两说：

- **溯源**：这份文件是哪个工具哪一版生成的？手工编辑过的文件常丢/改这段；
- **警惕**：ADMIN-DATA 说"工具 A 生成"不代表此后没人手改——只能作线索，不能作证据（证据要靠 diff，见 [04-diff-review技巧](04-diff-review技巧.md)）。

### 手读练习：找出某个 CanTxPdu 的 ID 配置

任务：客户报"EngineSpeed 帧疑似 ID 配错"，文件是 `CanIf.arxml` + `Can.arxml`。步骤：

1. 打开 `CanIf.arxml`，搜 `SHORT-NAME` 含 `EngSpd` → 命中 `CanIfTxPduCfg_EngSpd` 容器；
2. 展开其 `PARAMETER-VALUES`：读 `CanIfTxPduCanId = 291`（十进制，即 0x123）、`CanIfTxPduCanIdType = EXTENDED_CAN`；
3. 交叉验证：打开 `Com.arxml` 搜同一报文名，看 IPdu 的 ID；再对通讯矩阵表（DBC/Excel）核对 0x123 是否等于矩阵规定值——三方对齐才算数；
4. 顺带检查 `REFERENCE-VALUES` 里 `CanIfTxPduRefCanTxPdu` 指向的 Can 驱动对象是否存在（链断则 ID 再对也发不出去）。

> 练习答案模板：报文名 → CanIf 实例名 → CanId 值与类型 → Can 驱动引用 → 与矩阵比对结论。这五步就是配置工程师的"读配置基本法"。

## 配置层/工程关联

- 编辑器武装：VS Code + XML 插件（折叠/格式化/大纲视图），大纲视图=免费的小型配置浏览器；超过 10MB 的文件先格式化再搜，命中率高得多；
- tresos 侧对应操作：GUI 里选中参数右键"Show in XML/View Definition"能直接跳到这段 arxml——GUI 与文件互为索引；
- 多文件分片工程：模块可能一个模块一个 arxml（CanIf.arxml、Can.arxml...），跨模块引用（VALUE-REF）要跨文件追——用编辑器多标签+路径搜索追链；
- 版本线索：DEFINITION-REF 的路径风格与文件头 schema 能粗判 AUTOSAR 版本年代（R4.x vs R19-11+，见 [版本演进](../../1-L1基础/架构总览/03-版本演进.md)）。

## 易错点与陷阱

1. **十进制读成十六进制**：`<VALUE>291</VALUE>` 是十进制 291（0x123），不是 0x291——手读报错里一半的"ID 对不上"源于此。
2. **只搜 VALUE 不看父节点**：同样的 `>1<` 满屏都是，必须确认命中处的 DEFINITION-REF 尾段与容器名才是你要的那个"1"。
3. **忽略 DEST 属性差异**：`DEST="ECUC-CONTAINER-VALUE"` 与 `DEST="ECUC-INTEGER-PARAM-DEF"` 指向的东西完全不同（值树 vs 定义树），搜索时带上 DEST 能过滤一半噪音。
4. **以为文件里有的就是生效值**：tresos 工程的最终生效值可能是多层叠加结果（见 [ECU配置结构](01-ECU配置结构.md)）；手读单文件只看到"这一层写了什么"，交付评审以工具导出的 effective 配置为准。
5. **在原始导出文件上直接做文本编辑**：没锁列/没配 XML 校验的手改极易破坏结构（标签不闭合、DEST 写错），改完必须工具回读校验。

## 面试高频题

1. 给你一个 5MB 的 ECUC arxml，怎么快速找到某条 Can Tx PDU 的 ID 配置？（考察三招+层级找法）
   答：先按地层图缩骨架：搜 `ECUC-MODULE-CONFIGURATION-VALUES` 定位 CanIf 模块 → 沿 CONTAINERS/SUB-CONTAINERS 折叠看容器树；再用三招定位：搜 SHORT-NAME（实例名如 CanIfTxPduCfg_EngSpd）直达节点，或搜 DEFINITION-REF 尾段（/CanIfTxPduCanId）抓同类参数，或搜 VALUE（>291<）反查来源；最后展开 PARAMETER-VALUES 读值并注意十进制（291=0x123）。
2. SHORT-NAME、DEFINITION-REF、VALUE-REF 在定位中各扮演什么角色？
   答：SHORT-NAME 是实例名/路径坐标（按名字直达、也是被引用的目标）；DEFINITION-REF 尾段标明"这是哪类参数"（过滤同名噪音、确认语义）；VALUE-REF 是跨节点/跨模块的指针（沿它追 CanIf→Can 驱动的链路，断链即发不出去）。三者组合=名字直达+身份确认+链路追踪。
3. 手读发现 CanIf 的 CanId 与通讯矩阵不一致，你的排查顺序是什么？
   答：①核对进制（文件里是十进制，291≠0x291，一半"不一致"源于此）；②看父节点 DEFINITION-REF 确认没抓错参数；③跨文件对账：Com.arxml 的 IPdu、Can.arxml 的驱动对象、DBC/矩阵三方比对；④确认手读的文件层是否是生效层（tresos 多层叠加，以 effective 配置为准）；⑤仍不一致则按配置变更流程修正并 diff 留痕。
4. ADMIN-DATA 有什么用？为什么不能只靠它判断文件是否被手改？
   答：ADMIN-DATA 记录生成工具与版本（SW-Tool/版本/时间戳），可做溯源线索、粗判文件出身。但它只是"出生证明"——生成之后的手改不会更新它，所以判断是否被改要以两版文件的 diff 为证据，ADMIN-DATA 只能作线索不能作证据。

## 延伸

- [容器与参数](02-容器与参数.md)：本篇搜索三板斧的语法依据
- [04-diff-review技巧](04-diff-review技巧.md)：从"读一份"到"比两份"
- [ECU配置结构](01-ECU配置结构.md)：文件分层叠加——为什么单文件不等于全部真相
- [如何查SWS](../../1-L1基础/SWS阅读法/01-如何查SWS.md)：读出参数后，行为含义去 SWS 配置规范核对
- [调度表](../SchM与调度/01-调度表.md)：走读 Os 的 Counter/Task/ScheduleTable 容器树
