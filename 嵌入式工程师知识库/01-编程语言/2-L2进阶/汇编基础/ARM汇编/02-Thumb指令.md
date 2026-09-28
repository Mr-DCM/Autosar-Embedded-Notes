# Thumb 指令速览与反汇编阅读

> 一句话定位：Cortex-M 只有 Thumb/Thumb-2 一种指令集——这篇把工程反汇编里最常撞见的指令一次认全，并给一段"C 代码 → 反汇编逐行注释"的实操，练出看懂 objdump 和调试器反汇编窗口的手感。
> 等级：L2 ｜ 前置：[01-寄存器与模式](01-寄存器与模式.md)

## 原理

**Thumb-2（Cortex-M4/M7，ARMv7-M）是 16/32 位混合编码**：

- 大部分常用指令有 16 位"短编码"（操作数限低寄存器、立即数位宽小），省 flash；
- 装不下 16 位的（32 位立即数、宽偏移访存、位域操作、DSP 指令）自动用 32 位"宽编码"；
- 指令流按半字对齐，解码器看前几位判断 16 还是 32 位——所以**同一指令序列里两种宽度混排**，反汇编里 `.n`（narrow）/`.w`（wide）后缀只是宽度提示，不是语义差异。
- 没有 ARM 经典指令集状态：EPSR 的 T 位恒为 1（见 [01-寄存器与模式](01-寄存器与模式.md)），跳转目标 bit[0] 必须为 1。

为什么要混合？纯 16 位 Thumb-1 功能残缺（无条件执行、立即数小、不能桶形移位访存），纯 32 位太费空间——Thumb-2 兼得密度与能力。

## 代码示例/解读

### 1. 工程里最常出现的指令速览（带注释）

```asm
; ---- 数据搬运 ----
movs  r0, #0          ; r0 = 0；s 后缀 = 更新 APSR 标志位（16 位编码）
movw  r0, #0x1234     ; r0 低 16 位 = 0x1234（高 16 位不动，32 位编码）
movt  r0, #0x5678     ; r0 高 16 位 = 0x5678 → 组合后 r0 = 0x56781234
ldr   r0, =0x12345678 ; 伪指令！汇编器转成 ldr r0,[pc,#imm] + literal pool 常量

; ---- 访存 ----
ldr   r1, [r0, #8]    ; r1 = *(u32*)(r0+8)，结构体成员访问的样子
ldr   r1, [r0, r3, lsl #2] ; r1 = *(u32*)(r0 + r3*4)，C 数组取 base[i]
str   r1, [r0], #4    ; *r0 = r1 后 r0 += 4（后增量，拷贝循环常客）
push  {r4-r11, lr}    ; 函数序言：压 callee-saved + 返回地址
pop   {r4-r11, pc}    ; 函数尾声：直接把 LR 弹进 PC 完成返回

; ---- 分支与条件 ----
cbz   r1, 1f          ; r1==0 则向前跳到标号 1（只能前跳、近距离、低寄存器）
cbnz  r1, 2f          ; r1!=0 则跳——编译器最爱用它翻译 if(p) / if(flag)
ittee eq              ; IT 块：接下来 4 条按条件执行（见下）
b     label           ; 无条件跳转
bl    func            ; 调用：返回地址进 LR
bx    lr              ; 按寄存器返回（bit[0] 必须为 1）

; ---- 开关中断与特殊寄存器 ----
cpsid i               ; PRIMASK=1，关所有可配置优先级中断
cpsie i               ; PRIMASK=0，开中断（i=PRIMASK，f=FAULTMASK）
mrs   r0, control     ; 读特殊寄存器（CONTROL/IPSR/PRIMASK/PSP...）到通用寄存器
msr   basepri, r0     ; 写特殊寄存器
dsb                   ; 数据同步屏障：之前的访存必须完成才继续
isb                   ; 指令同步屏障：冲刷流水线（改 VTOR/开 MPU 后必加）

; ---- 调试与低功耗 ----
bkpt  #0              ; 断点：触发调试器接管；无调试器时进 fault 类异常
wfi                   ; 等中断休眠：任意中断（含被 PRIMASK 掩的）可唤醒
```

### 2. 32 位立即数装载的三种方式对比

```asm
; 方式一：movw+movt，两条 32 位指令，纯代码、无数据依赖
movw r0, #0x9ABC      ; 低 16 位
movt r0, #0x1234      ; 高 16 位 → r0 = 0x12349ABC

; 方式二：ldr 伪指令，一条指令 + 池子里的一个字
ldr  r0, =0x12349ABC  ; 汇编器在附近 literal pool 放常量，展开为 ldr r0,[pc,#N]
                      ; 池子必须在 pc 相对 ±4KB 内；跨 section 时汇编器自动插池

; 方式三：地址/符号装载（日常最常见）
ldr  r0, =g_counter   ; 取全局变量地址，之后 ldr r1,[r0] 读值
```

选型直觉：立即数参与运算用 movw/movt；只是要个地址/大常量、池子方便时用 `ldr =`。

### 3. IT 块（If-Then）：没有它的条件执行就得跳转

```asm
; C: if (a == b) x = 1; else x = 2;
cmp   r0, r1          ; 比较，更新标志
ite   eq              ; If-Then-Else：下 2 条，第 1 条 eq 时执行，第 2 条 ne 时执行
moveq r2, #1          ; eq 成立 → r2=1
movne r2, #2          ; eq 不成立 → r2=2（ne = eq 的反面）
; 规则：it 后最多跟 3 条（itt/ite/ittt/itee/... 共 4 层），
;      T 对应原条件，E 对应反条件，与指令后缀必须一致；
;      块内一般只放简单指令，别放跳转/复杂指令，具体限制看工具链文档。
```

### 4. 实操：看懂一段 objdump

先造一段 C（`demo.c`）：

```c
int sum10(const int *p)      /* 求和 10 个 int */
{
    int s = 0;
    for (int i = 0; i < 10; i++)
        s += p[i];
    return s;
}
```

`arm-none-eabi-gcc -mcpu=cortex-m4 -O1 -c demo.c` 后 `arm-none-eabi-objdump -d demo.o`，典型输出（不同 GCC 版本细节略有差异）：

```asm
00000074 <sum10>:                     ; 函数入口：objdump 用 <名字> 标出
  74:   b508        push    {r3, lr}  ; 压 lr 保返回地址；捎带 r3 凑 8 字节栈对齐
  76:   2300        movs    r3, #0    ; r3 = i = 0
  78:   2200        movs    r2, #0    ; r2 = s = 0
  7a:   58c1        ldr     r1, [r0, r3, lsl #2]  ; r1 = p[i]（i*4 字节偏移）
  7c:   1851        adds    r1, r2, r1            ; r1 = s + p[i]
  7e:   3301        adds    r3, #1                ; i++
  80:   2b0a        cmp     r3, #10               ; i 与 10 比，更新标志
  82:   1c0a        adds    r2, r1, #0            ; s = r1（顺手清标志，无分支）
  84:   d3fa        bcc.n   7a <sum10+0x6>        ; 无符号小于 → 跳回循环头
  86:   1c10        adds    r0, r2, #0            ; 返回值搬到 r0（AAPCS）
  88:   bc08        pop     {r3, pc}              ; 弹栈，pc=lr 完成返回
```

读法三步：

1. **先看地址列和字节列**：`74:` 是偏移地址；后面 `b508` 是 2 字节（16 位编码），若看到 8 位十六进制（如 `f8df 1234`）就是 32 位编码。
2. **再认入口/出口**：`push {…, lr}` 与 `pop {…, pc}` 之间就是函数体；`bl` 的目标是被调函数。
3. **对照 C 的控制流**：`cmp + bcc` = `for` 的边界判断；`cbz/cbnz` = `if (p)`；`ldr =sym` + `ldr [r0]` = 读全局变量。

### 5. literal pool 长什么样

```asm
0000009c <get_counter>:
  9c:   4803        ldr     r0, [pc, #12]   ; PC=本条地址+4=0xa0，目标 0xa0+12=0xac
  9e:   6800        ldr     r0, [r0]        ; 取地址处的值
  a0:   4770        bx      lr              ; 返回
  ...
000000ac:           .word   0x20000000      ; g_counter 的地址（池子）
```

看到 `ldr rX, [pc, #imm]` 就往地址列后面翻——池子里的 `.word` 就是那个"立即数/地址"。链接重定位后 objdump 会把 `.word` 标成 `<g_counter>`。

### 6. 反汇编从哪来

- 命令行：`arm-none-eabi-objdump -d -S app.elf > app.lst`（`-S` 混入源码，前提开 `-g`）；
- S32DS / vscode-cortex-debug：调试界面的 Disassembly 窗口，可从源码行"跳到对应指令"；
- ARM Compiler（armclang）：`fromelf -c app.elf`；
- 只有 .bin 没有 elf：`objdump -D -b binary -m arm -M force-thumb app.bin` 强制按 Thumb 解。

## 易错点与陷阱

1. **`ldr r0, =X` 是伪指令不是指令**：真实产物是 pc 相对加载 + literal pool；池子距离超限（±4KB）时汇编器自动补池，手写汇编把池子挪远了会报错或数据错。
2. **movw/movt 顺序**：先低后高。movt 不会清低 16 位，指望 movt 单独装全 0 常数必错。
3. **movs 的 s**：会改标志位。在依赖标志的 cmp 与条件跳转之间插一条 movs，标志就被破坏了（IT 块内尤其致命）。
4. **cbz/cbnz 只能向前跳、范围有限、只支持低寄存器**：手写长距离判零得用 `cmp`+`beq`。
5. **IT 块最多 4 条**且条件后缀必须与 itxyz 的 T/E 排列严格一致，写错汇编器直接报错（手写要警觉）；块内放跳转类指令有很多限制，别炫技。
6. **cpsid i 关不掉 NMI/HardFault**；BASEPRI 设 0 等于没设；关中断临界区要考虑嵌套（先读后恢复，见 [01-寄存器与模式](01-寄存器与模式.md)）。
7. **wfi 被掩中断也能唤醒**（PRIMASK=1 时中断不执行 ISR 但可以结束休眠）——"睡了但没进 ISR"不是玄学，是设计行为，细节看 ARMv7-M ARM 的 WFI 说明。
8. **把 `.n/.w` 当不同指令**：只是宽度提示；同一源码不同优化级别可能选不同宽度。

## 面试高频题

1. **为什么 Cortex-M 上没有 `bx` 切换到 ARM 状态？**
   答：ARMv7-M 只实现 Thumb/Thumb-2 执行状态，EPSR 的 T 位恒为 1；`bx` 到 bit[0]=0 的地址不是切状态，而是触发 INVSTATE UsageFault。

2. **装 32 位立即数有哪些办法？各适合什么场景？**
   答：movw+movt（两条指令、无数据依赖，适合参与运算的常数）；`ldr =`（一条指令 + literal pool，适合取地址/大常量）；带移位的 mov/mvn 只能装位重复型立即数。

3. **IT 块解决什么问题？使用规则？**
   答：Thumb-1 时代条件执行只能靠分支，短小 if-else 开销大；IT 块让最多 4 条指令带条件执行、免跳转。规则：itxyz 的 T/E 排列须与指令条件后缀一一对应，块内限制放跳转等指令。

4. **cpsid i 与 msr basepri 的区别？**
   答：cpsid i 置 PRIMASK，屏蔽全部可配置优先级异常；basepri 按优先级阈值屏蔽，可保留高优先级中断响应——RTOS 内核常用后者缩短关中断对时敏中断的影响。M0+ 无 BASEPRI。

5. **bkpt 和 wfi 各用于什么场景？**
   答：bkpt 是软件断点，正常由调试器接管，无调试器时进入异常（可用于 assert 兜底）；wfi 是低功耗等中断，idle 任务/低功耗状态的标配，任何中断（含被掩的）都能唤醒。

## 延伸

- [01-寄存器与模式](01-寄存器与模式.md)
- [03-启动文件startup解读](03-启动文件startup解读.md)
- [volatile 的正确使用](../../寄存器编程/01-volatile的正确使用.md)
- [读写时序与屏障](../../寄存器编程/04-读写时序与屏障.md)
- [ARM Cortex-M 体系结构](../../../../02-芯片与体系结构/1-L1基础/ARM-Cortex-M/README.md)
