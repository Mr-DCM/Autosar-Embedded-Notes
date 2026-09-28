# 嵌入式Linux

> 上级目录：[08-操作系统](../../README.md)
> 主等级：L2→L3

## 定位

进阶方向：设备树、字符设备、Platform 驱动、移植。核心叙事是"Linux 概念 ↔ 你熟悉的 MCU/AUTOSAR 概念"对照：设备树 vs 静态配置、字符设备 vs 外设驱动、内核模块 vs 固件单体、启动三段式 vs EcuM 启动流。

## 计划笔记

- [x] 01-Linux基础.md
- [x] 02-设备树.md
- [x] 03-字符设备驱动.md
- [x] 04-Platform驱动.md
- [x] 05-内核模块.md
- [x] 06-系统移植.md
- [x] 07-Buildroot与Yocto.md

## 已完成

| 笔记 | 等级 | 一句话 |
|---|---|---|
| [01-Linux基础.md](01-Linux基础.md) | 【L2→L3】 | 三件套启动接力（U-Boot→内核→init）对照 MCU 启动流 + host/sysroot/实操三板斧 |
| [02-设备树.md](02-设备树.md) | 【L2→L3】 | 节点/属性/compatible 匹配链路 + dts/dtsi/dtb 关系——启动期数据 vs 编译期静态配置 |
| [03-字符设备驱动.md](03-字符设备驱动.md) | 【L2→L3】 | file_operations/主次设备号/copy_to_user + syscall/ioctl/sysfs 三路对比——驱动即文件 |
| [04-Platform驱动.md](04-Platform驱动.md) | 【L2→L3】 | 总线-设备-驱动三角撮合、probe 时序、devm_ 资源托管——配置驱动的初始化自动化 |
| [05-内核模块.md](05-内核模块.md) | 【L2→L3】 | insmod/modprobe/模块参数/符号导出 vs MCU 固件单体 + 内核态编程军规 |
| [06-系统移植.md](06-系统移植.md) | 【L2→L3】 | 四步流水线逐级点亮（U-Boot→内核→dts→rootfs）+ 卡点排障地图 |
| [07-Buildroot与Yocto.md](07-Buildroot与Yocto.md) | 【L2→L3】 | 构建系统双雄分工 + AGL 车载生态、座舱 Linux vs 车控 AUTOSAR 的域控分工 |

---

维护约定：笔记命名 `序号-主题.md`；真实截图放 `_images/`；流程/时序/状态/架构图用 PlantUML 内嵌正文，规范见 [图表规范与模板](../../../00-总览/图表规范与模板.md)。
