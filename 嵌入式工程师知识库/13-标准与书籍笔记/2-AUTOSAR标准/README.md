# 2-AUTOSAR标准

> 上级目录：[13-标准与书籍笔记](../README.md)

## 定位

CP AUTOSAR 官方标准的**原件架**：五个版本的全功能域 zip + R4.2.2 常用域已解包 PDF。SWS 检索手法与索引见 [7-阅读笔记/AUTOSAR规范](../7-阅读笔记/AUTOSAR规范/README.md)，官方下载见 [6-在线资源/01](../6-在线资源/01-官方标准下载指南.md)。

## 存放状态（2026-09 清点）

本架为**索引架**：各版本 zip 与解包 PDF 因体积**不入 git**（`.gitignore` 已排除），当前未存于本目录——完整账本见 [_本地存档清单](../_本地存档清单.md)；AUTOSAR 官网注册后可免费重新下载全部版本（见 [下载指南](../6-在线资源/01-官方标准下载指南.md)），恢复成本低。原件归位本地后，更新清单状态列即可。

## 版本清单

| 版本 | 形态 | 说明 |
|---|---|---|
| CP AUTOSAR R19-11 | 22 个功能域 zip（含 ReleaseDocumentation） | 年度版命名起点，工程常见的经典版本 |
| CP AUTOSAR R4.4.0 | 22 个功能域 zip | R4.x 后期版本 |
| CP AUTOSAR R4.3.1 / R4.3.0 | 功能域 zip | R4.x 中期版本 |
| CP AUTOSAR R4.2.2 | 功能域 zip + **已解包 PDF** | 工程存量最大版本，已解包 Communication/Diagnostics/ModeManagement/SystemServices/MethodologyAndTemplates 五个域 |
| AUTOSAR_SWS_CANTransportLayer.pdf | 单篇 | 从 1 号架调入的传输层 SWS（15765 在 AUTOSAR 侧的实现规范） |

## R4.2.2 已解包域速览

| 域 | 重点文档 |
|---|---|
| Communication | SWS_CANInterface / SWS_CANDriver / SWS_PDURouter / SWS_COM / SWS_SOMEIPTransformer / SWS_TcpIp 等 66 篇 |
| Diagnostics | SWS_DiagnosticCommunicationManager（Dcm）、SWS_DiagnosticEventManager（Dem）、SWS_DiagnosticLogAndTrace |
| ModeManagement | SWS_ECUStateManager（EcuM）、SWS_BSWModeManager、EXP_ModeManagementGuide |
| SystemServices | SWS_OS、SWS_COMManager、SWS_DefaultErrorTracer、TR_TimingAnalysis |
| MethodologyAndTemplates | RS_Methodology、TPS_SystemTemplate、TPS_SoftwareComponentTemplate、ECU 配置模板族 |

## 归架约定

- 新版本按 `CP AUTOSAR Rxx-xx/` 建目录，功能域 zip 不解压直存；只有"高频查阅域"才解包存 PDF；
- 同一文档跨版本共存（如 SWS_CANInterface 在 R4.2.2 与 R19-11 各一份），以版本目录区分，不互相覆盖；
- 引用规范条目必须带版本（如 "SWS_CanIf_00815 (R4.2.2)"）——版本错配是评审常见击穿点。
