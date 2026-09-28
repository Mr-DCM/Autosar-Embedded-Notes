# 07-Buildroot与Yocto

> 一句话定位：嵌入式 Linux 的"整机产线"——从源码自动产出工具链、U-Boot、内核、dtb、rootfs 直至可烧写镜像；Buildroot 以简单取胜，Yocto 以分层定制见长（车载 AGL 等发行版都长在它上面）——对照 MCU 世界，它们扮演的是"Tresos 生成配置 + CI 整包编译 + 产线烧录文件"三合一的角色。
> 等级：L2→L3 ｜ 前置：[06-系统移植](06-系统移植.md)

## 太长不看

- 为什么要构建系统：手工拼三件套（06 篇）在"几十个软件包 × 交叉编译 × 依赖管理 × 可复现"面前必然失控——构建系统用**声明式配置 + 全量从源码构建**换取可复现（reproducible）产物。
- 两者一句话分工：**Buildroot = 一个 make 工程出镜像，简单直接，适合原型与中小系统；Yocto = 元数据（recipe/layer）驱动的构建框架，分层组合、发行版定制，适合量产与生态（AGL 就基于它）**。
- Yocto 三要素：**recipe（一个包怎么编：源/依赖/任务）、layer（一类功能的配方集合，可叠加覆盖）、image（最终镜像的目标组合）**——"layer 叠 layer 改 behavior"是它的核心心智模型。
- 车载生态认门牌：**AGL（Automotive Grade Linux，基于 Yocto，座舱/IVI 方向）**、量产座舱域控还常见 Android Automotive/QNX 混搭；Yocto 在仪表/网关/T-Box 的 Linux BSP 里几乎是事实标准。
- 为何"座舱用 Linux、车控用 AUTOSAR"：**算力与生态 vs 实时与确定**——HMI/多媒体要 GPU 与海量中间件（Linux 强），动力底盘要 µs 级确定性与安全认证（AUTOSAR MCU 强）；域控架构（SoC+MCU 双芯）就是两个世界的物理拼缝，SOA（SOME/IP/DDS）是它们之间的桥。
- **工程深入场景**：真做量产 BSP 要吃透 layer 优先级、license 合规、OTA 打包；本篇目标是能读懂工程结构、知道"改一个包该动哪里"。

## 核心概念

```plantuml
@startuml
title 构建系统全景：输入到镜像（对照 MCU 工具链）
skinparam defaultFontName "Microsoft YaHei"
package "输入（你写的部分）" {
  [defconfig\n板级选择与包开关] as CFG
  [board overlay/\n设备树、内核补丁、配置文件] as OVL
}
package "Buildroot 或 Yocto" {
  [交叉工具链\n（可自产或外部）] as TC
  [源码包\n（下载/本地 git）] as SRC
  [按依赖拓扑\n逐包编译+安装到 staging] as BUILD
  [打包 rootfs\n+ 生成镜像/SDK] as IMG
}
CFG --> BUILD
OVL --> IMG
TC --> BUILD
SRC --> BUILD
BUILD --> IMG
IMG --> [产物：\nboot.img + rootfs.img\n+ 可分发 SDK] as OUT
note bottom of BUILD : MCU 对照：Tresos 生成配置 +\nIDE 全量编译 + 产线镜像打包\n——这里全部自动化且全源码可溯
@enduml
```

## 详解

### Buildroot：一个 make 工程

- 使用节奏：`make xxx_defconfig`（选板/选方案）→ `make menuconfig`（开包、改内核/U-Boot 版本、选文件系统类型）→ `make`（全量构建）→ `output/images/` 拿镜像；
- 位置约定：你的设备树、配置文件、自制应用放 **board overlay 目录**，包的下载地址/编译方式写在 package 目录的 `Config.in + xxx.mk`；
- 适合：中小型系统、原型验证、学习——全流程一天能入门，代价是定制深了以后 makefile 逻辑开始纠缠。

### Yocto：layer 与 recipe 的世界

- 三层心智模型：

| 概念 | 是什么 | 类比 |
|---|---|---|
| recipe（.bb） | "一个包怎么构建"的配方：源从哪来、依赖谁、执行哪些任务（fetch/configure/compile/install） | 一个模块的构建脚本+依赖声明 |
| layer（层） | 配方与配置的集合（BSP 层、发行版层、自研层），可叠加、可覆盖下层 | AUTOSAR 的"分层 + 项目覆盖包" |
| image（镜像目标） | 声明最终镜像里装哪些包组 | 产线要刷的"整机软件包配置清单" |

- 核心命令节奏：`bitbake <image>` 构建整镜像；`bitbake <recipe> -c compile -f` 强制重编单包；`devtool modify <包>` 拉出源码改——**改东西先想"该落在哪一层"**，BSP 相关进 BSP 层，自研应用进自研层，永远不要直接改底层 meta 里的文件；
- SDK 输出：一条命令产出带正确 sysroot 的交叉工具链（01 篇的 sysroot 就是它生成的），交给应用团队免于装全套构建环境。

### 两者对比表

| 维度 | Buildroot | Yocto/BitBake |
|---|---|---|
| 学习曲线 | 一天入门 | 一周起步 |
| 包管理 | 每次全量重编，无二进制包库 | 可产出/复用 rpm/deb 包，增量能力强 |
| 定制机制 | menuconfig + overlay 目录 | layer 叠加、bbappend 覆盖 |
| 工具链 | 默认自产，也可外部 | 自产 + 多工具链支持，SDK 一等公民 |
| 生态 | 社区包数量有限 | OE 生态海量配方、厂商 BSP 全线支持 |
| 典型用户 | 原型、中小系统、教学 | 量产 BSP、车载/工业发行版（AGL） |

### 车载 Linux 生态认门牌

- **AGL（Automotive Grade Linux）**：Linux 基金会主导、基于 Yocto 的车载发行版，主攻 IVI/座舱（音频、蓝牙、导航 HMI），提供规范化的服务框架；
- 量产座舱域控的典型软件栈：Hypervisor 上跑 Linux/Android（IVI）+ QNX（仪表）+ RTOS/AUTOSAR（车控备份核）——**Linux 不是整车"唯一的 OS"，而是"座舱那一格"的 OS**；
- **域控与 SOA**：中央计算 + 区域控制的架构下，服务化通信（SOME/IP、DDS）把"功能"从"ECU 固件"解耦成"网络服务"——Linux 侧的中间件（vsomeip 等）与 MCU 侧 AUTOSAR 的 SoAd/SOMEIP-SD 说着同一种协议，这正是两个世界工程师协作的接口面；
- 车控（动力/底盘/车身安全件）仍留在 AUTOSAR MCU 上：实时性确定、内存静态、认证体系成熟——Linux 侧补实时（PREEMPT_RT）也只够"软实时"，替代不了 µs 级硬实时。

### 为何座舱域控用 Linux，而 MCU 用 AUTOSAR（一句话版）

| 需求维度 | 座舱/IVI | 车控 ECU |
|---|---|---|
| 负载类型 | GPU 渲染、多媒体编解码、网络应用 | 周期控制、硬实时中断 |
| 生态需求 | 海量中间件/开源栈（图形、蓝牙、浏览器） | 认证过的 BSW 栈、配置工具链 |
| 实时要求 | 100ms 级"人感流畅"即可 | µs~ms 级确定性，错过即事故 |
| 安全认证 | ASIL-B 上下（配合 MCU 兜底） | ASIL-C/D |
| 结论 | Linux（生态+算力） | AUTOSAR OS（确定+认证） |

两个世界的工程师协作面：**MCU 出实时与安全，Linux 出体验与生态，SOME/IP/Ethernet 把两者缝起来**——懂两边的对照表，就是跨界的竞争力。

## 易错点与陷阱

1. **现象：第一次 Yocto 构建跑了几个小时还在下载。原因：全源码构建是设计使然——从工具链到每个包都从源码来（网络与磁盘开销巨大）**。对策：用好下载缓存（DL_DIR）与共享 sstate 缓存（公司级 NFS/HTTP mirror）；别试图绕过，可复现性正是这样换来的。
2. **现象：直接改了 poky/meta 里的文件，下次换层/升级全没了。原因：违反"不碰底层、用 bbappend/自建 layer 覆盖"的铁律**。对策：BSP 改动进 BSP layer，应用进自研 layer，用 `bitbake-layers show-layers` 理清优先级与覆盖关系。
3. **现象：Buildroot 改了一个包的源码，make 后镜像没变化。原因：构建系统按指纹缓存，直接改 output/ 下的源码不会触发重编**。对策：`make <pkg>-dirclean` 或 `make <pkg>-rebuild` 明确重编；正规做法是把补丁/自有源放进 package 定义里。
4. **现象：把开发机上的 .so 直接塞进 rootfs，板上 segfault。原因：库是 x86 架构或 ABI 不匹配**。对策：所有 rootfs 内容必须来自构建系统产出（它保证架构一致）；自查用 `file` 看架构——手工塞文件本来就是被构建系统反对的操作。
5. **现象：内核/设备树改了老半天，Yocto 一直用旧源。原因：SRCREV 没指向新提交或没 bump PV/PR，源码缓存未失效**。对策：git 方式引用时更新 SRCREV；`bitbake -c cleanall linux-xxx` 后重建；理解"配方说了算，不是文件系统里有什么说了算"。
6. **现象：以为上了 Linux 就能跑 AGL 做车控。原因：AGL 定位是 IVI/座舱发行版，不含 ASIL-D 车控实时栈**。对策：架构上走"SoC（Linux/AGL）+ 安全 MCU（AUTOSAR）+ SOME/IP 桥"的分工，实时与安全职责留在 MCU 侧。

## 面试高频题

**Q：Buildroot 和 Yocto 怎么选？**
答：看系统规模与生命周期——原型/中小型系统/学习用 Buildroot：一个 make 工程出镜像，简单直接；量产 BSP/需要发行版定制/多产品线共享配方用 Yocto：layer 机制天然支持"基础层+项目层"的组合复用，可产出二进制包与 SDK，生态（OE、厂商 BSP、AGL）都在它上面。代价是学习曲线陡、构建慢；无论哪个，"全源码可复现构建"都是它们优于手工拼装的根本理由。

**Q：Yocto 的 layer 机制解决什么问题？**
答：解决"多方交付物如何组合与覆盖"：SoC 厂商发 BSP layer、板厂发板级 layer、产品团队发自研 layer，各层 recipe/bbappend 按优先级叠加，同名文件高优先级覆盖低优先级——谁都不用改别人的代码。类比 AUTOSAR：基础栈厂商交付 BSW + 项目用配置工具覆盖参数，layer 就是"代码级的覆盖包机制"，让上游可以独立升级。

**Q：为什么车控不用 Linux、座舱不用 AUTOSAR？**
答：需求错配——车控要 µs 级确定性、静态内存、成熟的 ASIL-D 认证工具链，这正是 AUTOSAR OS（OSEK 血统）的设计目标，Linux 分时调度与动态内存天然不满足；座舱要 GPU 图形、多媒体、网络生态与快速迭代的应用，MCU 的算力与中间件生态撑不住，Linux/Android 的开放生态才是主场。域控"高性能 SoC + 安全 MCU"双芯架构让两者各守本职，SOME/IP/以太网做桥——这是当前主流的物理答案。

**Q：构建系统为什么坚持"从源码全量构建"，而不是直接用二进制包？**
答：三个理由——①可复现：任何时点能从源码重建出完全一致的镜像（安全审计、缺陷追溯的前提，车规尤其在意供应链可溯）；②裁剪与定制：嵌入式要按字节省空间，源码级配置项（Kconfig、patch）才能裁到位；③license 与安全合规：源码清单（SBOM 的基础）天然可枚举，漏洞响应能定位到包与版本。交叉编译的一致性（全链同工具链）也最容易在全源码流水线里保证。

## 延伸

- [AUTOSAR 架构 L3 高级](../../../07-AUTOSAR架构/3-L3高级/README.md)：座舱/车控分工另一侧的深水区（RTE、多核、SecOC）；
- [AUTOSAR 架构总览](../../../07-AUTOSAR架构/README.md)：MCU 侧"配置生成 + 分层交付"与 layer 机制的呼应；
- [06-系统移植](06-系统移植.md)：构建系统产出的三件套，正是手工移植流程的自动化对象；
- [01-Linux基础](01-Linux基础.md)：sysroot/工具链概念——SDK 输出的就是它；
- [项目实战](../../../12-项目实战/README.md)：把两边知识落到工程模板的入口。
