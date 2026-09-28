# Python 处理 ARXML

> 一句话定位：把 DaVinci Developer / EB tresos 导出的 ARXML 当数据库查——用标准库 `xml.etree.ElementTree` 递归遍历 ECUC 容器树，批量导出 NvM / CanIf / Dcm 配置清单到 CSV，做配置评审与跨版本比对。
> 等级：L2 ｜ 前置：无

## 原理

**ARXML（AUTOSAR XML）本质是 XML + ECUC 配置模型**。配置工具导出的 arxml 里，核心结构是层层嵌套的容器（Container）：

```xml
<AR-PACKAGES>                          <!-- 包层级，可嵌套很深 -->
  <AR-PACKAGE>
    <SHORT-NAME>NvM</SHORT-NAME>
    <ELEMENTS>
      <ECUC-MODULE-CONFIGURATION-VALUES>
        <CONTAINERS>
          <ECUC-CONTAINER-VALUE>       <!-- 一个配置容器（如一个 NvM 块） -->
            <SHORT-NAME>NvmBlock_Lcfg</SHORT-NAME>          <!-- 实例短名 -->
            <DEFINITION-REF DEST="ECUC-PARAM-CONF-CONTAINER-DEF">
              /Vendor/NvM/NvMConfigSet/NvMBlockCfg</DEFINITION-REF>  <!-- 定义路径 -->
            <PARAMETER-VALUES>
              <ECUC-NUMERICAL-PARAM-VALUE>   <!-- 参数还有 TEXTUAL/BOOLEAN 两种 -->
                <DEFINITION-REF .../NvMNvBlockLength</DEFINITION-REF>
                <VALUE>64</VALUE>
              </ECUC-NUMERICAL-PARAM-VALUE>
            </PARAMETER-VALUES>
            <REFERENCE-VALUES>               <!-- 引用：指向别的容器，子容器再递归 -->
              <ECUC-REFERENCE-VALUE>
                <DEFINITION-REF .../NvMTargetBlockRef</DEFINITION-REF>
                <VALUE>/NvM/NvmBlock_Lcfg</VALUE>
              </ECUC-REFERENCE-VALUE>
            </REFERENCE-VALUES>
            <SUB-CONTAINERS>...</SUB-CONTAINERS>
          </ECUC-CONTAINER-VALUE>
        </CONTAINERS>
      </ECUC-MODULE-CONFIGURATION-VALUES>
    </ELEMENTS>
  </AR-PACKAGE>
</AR-PACKAGES>
```

三个解析要点：

1. **命名空间（Namespace）**：根元素带 `xmlns="http://autosar.org/schema/r4.0"`（版本可能是 r4.0/r4.1/r4.2…），ElementTree 会把每个 tag 变成 `{http://...}ECUC-CONTAINER-VALUE`——**直接 `find('ECUC-CONTAINER-VALUE')` 永远返回 None**。对策：要么用 `local(tag)` 剥掉前缀统一比较（`tag.endswith('}ECUC-CONTAINER-VALUE')` 技巧），避免硬编码版本号。
2. **递归找容器**：容器嵌套层级不定（包 → 模块 → 配置集 → 容器 → 子容器 → …），不要按固定路径 find，用 `root.iter()` 全树遍历 + 按 `DEFINITION-REF` 尾段（容器定义短名，如 `NvMBlockCfg`）过滤。
3. **区分两个"名字"**：`SHORT-NAME` 是配置实例名（人起的），`DEFINITION-REF` 尾段是容器/参数的"类型名"（schema 定义的）。过滤用类型名，展示用实例名。

## 代码示例/解读

### 1. 通用工具函数（四个函数吃遍所有场景）

```python
import xml.etree.ElementTree as ET

PARAM_TAGS = ("ECUC-NUMERICAL-PARAM-VALUE",    # 数值参数
              "ECUC-TEXTUAL-PARAM-VALUE",      # 文本参数
              "ECUC-BOOLEAN-PARAM-VALUE")      # 布尔参数

def local(tag):
    """剥命名空间：'{http://...}ECUC-CONTAINER-VALUE' -> 'ECUC-CONTAINER-VALUE'"""
    return tag.rsplit('}', 1)[-1]

def short_name(elem):
    """容器/元素的 SHORT-NAME（实例名，工具里看到的那个）"""
    for c in elem:
        if local(c.tag) == "SHORT-NAME":
            return c.text or ""
    return ""

def def_name(elem):
    """DEFINITION-REF 的尾段：类型名，如 .../NvMBlockCfg -> NvMBlockCfg"""
    for c in elem:
        if local(c.tag) == "DEFINITION-REF":
            return (c.text or "").rstrip('/').rsplit('/', 1)[-1]
    return ""

def iter_containers(root, def_short):
    """全树递归，产出所有"定义短名匹配"的容器（不关心层级深度）"""
    for e in root.iter():
        if e.tag.endswith('}ECUC-CONTAINER-VALUE') and def_name(e) == def_short:
            yield e

def get_param(container, want, default=""):
    """在容器子树里按参数定义短名取 VALUE（三种参数类型统一处理）"""
    for e in container.iter():
        if local(e.tag) in PARAM_TAGS and def_name(e) == want:
            for v in e:
                if local(v.tag) == "VALUE":
                    return (v.text or "").strip()
    return default

def get_ref(container, want):
    """按引用定义短名取引用目标的尾段（如被引用的 Pdu 名）"""
    for e in container.iter():
        if local(e.tag) in ("ECUC-REFERENCE-VALUE", "ECUC-INSTANCE-REFERENCE-VALUE") \
           and def_name(e) == want:
            for v in e:
                if local(v.tag) == "VALUE":
                    return (v.text or "").rstrip('/').rsplit('/', 1)[-1]
    return ""
```

### 2. 场景①：列出所有 NvMBlockCfg（评审 NvM 配置清单）

```python
def dump_nvm(root):
    rows = []
    for c in iter_containers(root, "NvMBlockCfg"):
        rows.append({
            "块名":   short_name(c),
            "块长度": get_param(c, "NvMNvBlockLength"),
            "WriteAll": get_param(c, "NvMSelectBlockForWriteAll"),
            "CRC":    get_param(c, "NvMBlockUseCrc"),
            # RAM/ROM 行为参数名以工具里的 DEFINITION-REF 为准（版本间略有出入）
            "RAM镜像": get_ref(c, "NvMRamBlockDataAddress") or \
                      get_param(c, "NvMRamBlockDataAddress"),
            "ROM目标": get_ref(c, "NvMNvramBlockIdentifier") ,
        })
    return rows
```

### 3. 场景②：导出 CanIf 接收 PDU 列表

```python
def dump_canif_rx(root):
    rows = []
    for c in iter_containers(root, "CanIfRxPduCfg"):
        rows.append({
            "Pdu名":  short_name(c),
            "CanId":  get_param(c, "CanIfRxPduCanId"),
            "DLC":    get_param(c, "CanIfRxPduDlc"),
            "HO引用": get_ref(c, "CanIfRxPduHardwareObjectRef"),
            "上抛目标": get_ref(c, "CanIfRxPduTargetPduIdRef"),
        })
    return rows   # 排查"收不到报文"时先看这张表：ID/DLC/HO 哪个配错一目了然
```

### 4. 场景③：导出 Dcm DID 表

```python
def dump_dcm_did(root):
    rows = []
    for c in iter_containers(root, "DcmDspDid"):
        did = get_param(c, "DcmDspDidId", "0")
        rows.append({
            "名称": short_name(c),
            "DID":  f"0x{int(did, 0):04X}" if did else "",   # 统一格式方便比对
            "长度": get_param(c, "DcmDspDidSize"),
            # 引用参数名（会话/安全层）以你工程的 Dcm xsd 为准，先在工具里抄准
            "会话": get_ref(c, "DcmDspDidSessionsRef"),
        })
    return rows   # 输出可直接当 22/2E 服务测试用例的输入清单
```

### 5. 完整可跑骨架：arxml_dump.py

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""arxml_dump.py —— 从 ECUC 配置 ARXML 批量导出容器参数到 CSV
用法: python arxml_dump.py -c NvMBlockCfg -p NvMNvBlockLength,NvMBlockUseCrc -o nvm.csv a.arxml
"""
import argparse, csv, glob, sys
import xml.etree.ElementTree as ET

PARAM_TAGS = ("ECUC-NUMERICAL-PARAM-VALUE", "ECUC-TEXTUAL-PARAM-VALUE",
              "ECUC-BOOLEAN-PARAM-VALUE")

def local(tag):
    return tag.rsplit('}', 1)[-1]

def short_name(elem):
    for c in elem:
        if local(c.tag) == "SHORT-NAME":
            return c.text or ""
    return ""

def def_name(elem):
    for c in elem:
        if local(c.tag) == "DEFINITION-REF":
            return (c.text or "").rstrip('/').rsplit('/', 1)[-1]
    return ""

def iter_containers(root, def_short):
    for e in root.iter():
        if e.tag.endswith('}ECUC-CONTAINER-VALUE') and def_name(e) == def_short:
            yield e

def get_param(container, want, default=""):
    for e in container.iter():
        if local(e.tag) in PARAM_TAGS and def_name(e) == want:
            for v in e:
                if local(v.tag) == "VALUE":
                    return (v.text or "").strip()
    return default

def main():
    ap = argparse.ArgumentParser(description="ARXML 容器参数批量导出")
    ap.add_argument("arxml", nargs="+", help="arxml 文件（支持通配符）")
    ap.add_argument("-c", "--container", required=True, help="容器定义短名，如 NvMBlockCfg")
    ap.add_argument("-p", "--params", default="", help="逗号分隔的参数定义短名")
    ap.add_argument("-o", "--out", default="out.csv", help="输出 CSV 路径")
    args = ap.parse_args()

    cols = [p.strip() for p in args.params.split(",") if p.strip()]
    files = []
    for f in args.arxml:                       # 展开 Windows 通配符
        files += glob.glob(f) if ("*" in f or "?" in f) else [f]

    rows = []
    for f in files:
        root = ET.parse(f).getroot()
        for c in iter_containers(root, args.container):
            row = {"file": f.replace("\\", "/").rsplit("/", 1)[-1],
                   "container": short_name(c)}
            for p in cols:
                row[p] = get_param(c, p)
            rows.append(row)

    if not rows:
        sys.exit(f"[!] 未找到容器 {args.container}：确认 -c 与 DEFINITION-REF 尾段一致")

    with open(args.out, "w", newline="", encoding="utf-8-sig") as fp:
        w = csv.DictWriter(fp, fieldnames=["file", "container"] + cols)
        w.writeheader()
        w.writerows(rows)
    print(f"[+] {len(files)} 个文件，导出 {len(rows)} 行 -> {args.out}")

if __name__ == "__main__":
    main()
```

导出的 CSV 就是配置评审清单：评审会上逐行过"块长度/CanId/DID 是否与通信矩阵、诊断需求一致"，比在 DaVinci 里一个个点开看快一个量级。

## 易错点与陷阱

1. **不处理命名空间 → find 全是 None**：最常见翻车点。用 `local()`/`endswith` 统一剥前缀，别硬编码 `r4.0`（tresos/DaVinci 导出版本可能不同）。
2. **参数类型只匹配 TEXTUAL**：同一参数可能是 NUMERICAL/BOOLEAN/TEXTUAL 三种 tag，按 `DEFINITION-REF` 尾段匹配、不要按参数元素的 tag 匹配。
3. **SHORT-NAME 与 DEFINITION-REF 混淆**：前者是实例名（人起的，可重复于不同层级），后者尾段才是"类型名"；过滤容器用后者，导出展示用前者。
4. **VALUE 都是字符串**：数值参数取出来是 `"64"` 或 `"0x40"`，用 `int(x, 0)` 转；比较大小前先转，别拿字符串比。
5. **大文件内存**：整机导出的 arxml 可能几十上百 MB；一次性 `parse()` 够用（XML 解析后内存约为文件的 3~5 倍），真扛不住换 `ET.iterparse` 流式处理并及时清空已过元素。
6. **多个 arxml 分片**：DaVinci 常按模块分文件导出（每个模块一个 arxml）；脚本要支持多文件输入，跨模块引用（如 CanIf→Com 的 Pdu）可能需要两遍扫描先建索引。
7. **参数名以工程为准**：不同 AUTOSAR 版本/供应商 xsd 的参数名有出入，别照抄本笔记的 `NvMSelectBlockForWriteAll`——先在工具里看一眼 DEFINITION-REF 抄准。

## 面试高频题

1. **为什么用 ElementTree 而不是正则/lxml？**
   答：ARXML 是结构化配置树，正则在嵌套标签前必脆；ElementTree 标准库自带、零依赖、`iter()` 递归天然适合容器树；lxml 优势在性能/XPath 2.0，内部工具通常用不上。

2. **命名空间问题怎么系统性解决？**
   答：统一在入口做 `local(tag)` 归一化（或 `endswith` 匹配），解析函数只面对裸 tag；这样对 r3/r4 各版本的命名空间都免疫。

3. **DEFINITION-REF 和 SHORT-NAME 的区别？**
   答：DEFINITION-REF 指向 schema 里的定义（类型/模板，跨工程稳定），SHORT-NAME 是当前配置实例的名字（人起的）。做过滤/匹配用前者，做展示/报告用后者。

4. **两个版本的配置要比对差异，思路是什么？**
   答：把每版导出成 `(容器路径, 参数名) -> 值` 的扁平字典，再做集合差集 + 逐键比对；容器路径用各级 SHORT-NAME 拼接保证唯一（见 [02-常用脚本索引](02-常用脚本索引.md) 第 1 条）。

## 延伸

- [02-常用脚本索引](02-常用脚本索引.md)
- [AUTOSAR 架构](../../../07-AUTOSAR架构/README.md)
- [汽车网络通讯（CanIf/DBC）](../../../05-汽车网络通讯/README.md)
- [诊断与标定（Dcm/DID）](../../../06-诊断与标定/README.md)
- [工具链与工程化](../../../10-工具链与工程化/README.md)
