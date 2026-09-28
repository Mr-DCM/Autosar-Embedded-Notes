# 5-论文与好文

> 上级目录：[13-标准与书籍笔记](../README.md)

## 定位

论文与深度好文的**存档架**：以 AUTOSAR 工程实现类高校学位论文为主体（`学校_标题` 命名便于按课题组检索），辅以行业白皮书与工具手册。获取渠道见 [6-在线资源/02](../6-在线资源/02-电子书与论文获取渠道.md)。

## 存放状态（2026-09 清点）

本架为**索引架**：下表论文/文章 PDF 因体积**不入 git**（`.gitignore` 已排除），当前未存于本目录——完整账本见 [_本地存档清单](../_本地存档清单.md)；学位论文多可经知网/学位论文库重新获取（见 [下载渠道](../6-在线资源/02-电子书与论文获取渠道.md)）。原件归位本地后，更新清单状态列即可。

## 资源清单

### AUTOSAR 工程实现（高校学位论文）

| 分组 | 文件 | 主题 |
|---|---|---|
| 多核 OS | 同济_基于Aurix的AUTOSAR多核操作系统的实现 等 Aurix 多核系列 5 篇 | AURIX 平台多核 OS 移植与实现 |
| | 电子科技_基于AUTOSAR看门狗的服务机制研究与实现.pdf | WdgM 服务机制 |
| ECU 配置 | 浙大_基于AUTOSAR标准的ECU配置工具.pdf / 浙大_汽车电子基础软件ECU配置的关键技术研究.pdf | 配置工具与参数体系 |
| | 哈工大_AUTOSAR系统ECU配置的研究与实现.pdf | 系统配置流程 |
| 通信栈 | 电子科技_基于AUTOSAR汽车电子通信协议栈软件设计实现.pdf | Com/PduR 通信栈实现 |
| | 重庆邮电_基于 AUTOSAR 的电动汽车驱动电机 ECU.pdf | 电机 ECU 整栈应用 |
| 诊断与 Boot | 浙大_基于AUTOSAR的汽车故障诊断系统的设计与实现.pdf | Dcm/Dem 应用 |
| | 电子科技_基于HIS协议的车载Bootloader的研究与实现.pdf | HIS Flash Bootloader |
| 底层与工具 | 复旦_基于AUTOSAR规范的Flash驱动程序的研究与实现.pdf | Fee/Fls 驱动 |
| | 辽宁工业_基于MATLAB的AUTOSAR自动代码生成技术.pdf | Simulink + AUTOSAR 流程 |
| 综述与测试 | 电子科技_AUTOSAR标准与体系.pdf | 标准体系综述（入门口） |
| | 湖南大学_AUTOSAR标准一致性测试研究.pdf | 一致性测试 |
| | 浙大_参照ISO26262的安全低功耗AUTOSAR基础软件模块.pdf | 功能安全与基础软件交叉 |
| | 同济_基于AUTOSAR的车用永磁同步电机控制器实现及半实物仿真测试.pdf / 同济_基于AUTOSAR架构和Simulink模型的汽车仪表系统研制.pdf | 整系统应用案例 |

### 行业文章与工具手册

| 文件 | 主题 |
|---|---|
| CAN_XL_IP_Concepts_Hanser_automotive_202008.pdf | CAN XL IP 概念（Hanser automotive，2020-08） |
| Security_HSM_Automobil-Elektronik_201808.pdf | HSM 硬件安全模块（行业文章，配 [11 区](../../11-功能安全与信息安全/README.md)） |
| Vector Davinci官方帮助配置手册（AutoSAR）.pdf | DaVinci Configurator 帮助手册（配 [10 区](../../10-工具链与工程化/README.md)） |

## 归架约定

- 论文命名 `学校_标题.pdf`（与课题组检索习惯一致）；英文论文 `作者_年份_短标题.pdf`；
- AUTOSAR 论文入库时在文件名或本表标注**实验基于的 AUTOSAR 版本**——R4.0 与 R4.2 的结论可能相反；
- 入库标准："三个月后还会回来查"；只值得看一次的留在浏览器收藏夹即可。
