# 04 malloc 原理与碎片

> 一句话定位：malloc 不是魔法，它本质是"带块头的空闲链表 + 合并/分裂"——看懂这套机制，碎片化、重复 free、野指针的根因就一目了然。
> 等级：L2 ｜ 前置：[02-栈与堆](02-栈与堆.md)

## 原理

### 1. 块头（block header）+ 空闲链表

glibc 的 ptmalloc、newlib 的 malloc、FreeRTOS 的 heap_4 都大同小异：每块内存前面都有一个**块头**，记录这块的大小和是否空闲。用户拿到的指针是块头**之后**的地址，块头对用户透明。

一个最简化的块头（实际还会有 prev 指针、魔数 magic、对齐填充）：

```c
typedef struct BlockHeader {
    uint32 size;             /* 含块头本身的整块大小 */
    uint32 isFree;           /* 1=空闲, 0=已分配 */
    struct BlockHeader *next;/* 空闲链表后继 */
    struct BlockHeader *prev;/* 空闲链表前驱（双向便于合并） */
} BlockHeader;
```

堆初始化时是一整块空闲内存，块头登记它的大小，作为空闲链表唯一节点。`malloc(64)` 时遍历空闲链表找一块够大的，从前面切出"块头+64+对齐"的小块返回，剩余部分（若够大）分裂成新空闲块挂回链表。

```plantuml
@startuml
title malloc/free 的空闲链表操作
skinparam defaultFontName "Microsoft YaHei"
package "堆内存（含块头）" {
  rectangle "Header A\nfree=1 size=200" as A
  rectangle "Header B\nfree=0 size=80" as B
  rectangle "Header C\nfree=1 size=120" as C
  A -[hidden]right-> B
  B -[hidden]right-> C
}
note over A : 用户指针指向\nHeader 之后
A --> C : 空闲链表（跳过 B）
C --> A : prev
@enduml
```

### 2. malloc 时发生了什么

1. 把请求大小加上块头大小，向上对齐到对齐倍数（如 8 字节），得到 `needSize`。
2. 遍历空闲链表，找第一个 `size >= needSize` 的块（first-fit）或最小够用的块（best-fit）。
3. 若该块剩余空间够再切一个最小块，**分裂**：前半标 `free=0` 返回给用户，后半建新块头标 `free=1` 挂回链表。否则整块标 `free=0` 返回（内部产生碎片）。
4. 找不到足够大的块：返回 NULL（或调用 `sbrk` 向系统要更多内存，ECU 上通常没有这个后端）。

### 3. free 时发生了什么

1. 从用户指针往前回退一个块头大小，读出块头。
2. 标 `free=1`。
3. 检查**物理相邻**的前后块是否也空闲，若是则**合并**（coalesce）成一个大块，从链表中摘除被合并的块。合并是防止碎片化的关键。
4. 重新挂回空闲链表。

合并是 free 的灵魂——只 free 不合并，堆会越来越碎。FreeRTOS 的 heap_4 支持合并，heap_2 不支持（适合"分配大小固定、永不碎片"场景）。

### 4. 内部碎片 vs 外部碎片

| 类型 | 含义 | 典型成因 |
|---|---|---|
| 内部碎片 | 块内被请求大小占用、剩余对齐/最小块规则浪费的部分 | malloc(3) 实际给 8 字节块，浪费 5 |
| 外部碎片 | 块之间分散的小空闲块，总和够但单块不够 | 反复 alloc/free 不同大小，留下不连续小孔 |

ECU 长期运行下外部碎片是致命的：总量还够，但某个 200 字节请求因为找不到连续 200 字节空闲块而失败。**合并只能缓解，无法根治外部碎片**——只要请求大小不均匀，长期下必然产生不可复用的小孔。

### 5. free 野指针 / 重复 free 的后果

- **野指针 free**：`free(p)` 后 `p` 仍指向原块。若再访问 `*p`，读到的是块头被改写后的数据（已被 free 标记、可能已合并），行为未定义；若再 `free(p)`，块头被当空闲块再次合并，链表结构被破坏，下次 malloc 行为诡异甚至死机。
- **重复 free**：同一指针 free 两次。第二次 free 把"已空闲"的块再合并一次，链表出现环路或重叠，后续 malloc 返回重叠内存，两处写入互相踩。
- **未分配指针 free**：把栈上变量地址、字符串字面量地址 free，块头读取是垃圾，链表立刻崩。

防御手段：free 后立即 `p = NULL;`（再 free NULL 是合法空操作）；自定义 allocator 在块头加 magic number 校验。但 ECU 工程的终极防御是**根本不用 malloc**。

### 6. 嵌入式替代：静态分区池

针对"同类对象频繁创建销毁"场景，定长内存池（fixed-size pool）是最优解：

- 一块大数组预先切好 N 个等大块，每块带 inUse 标志。
- alloc：遍历找 inUse=0 的块，置 1 返回。O(N)，N 小时近乎 O(1)。
- free：置 inUse=0。无需合并、无需块头链表。
- **永不碎片**：块大小一致，不存在"小块插不进大请求"。
- 失败可预测：池满就返回 NULL，可上报 Dem 而非崩溃。

CanTp 的多会话缓冲、NM 报文重传队列、Diag 临时缓冲都适合用池。

## 代码示例

```c
#include "Std_Types.h"

/* --- 定长内存池：永不碎片、O(1) 分配 --- */
typedef struct {
    uint8  data[8];        /* 报文数据 */
    uint8  dlc;            /* 数据长度 */
} CanMsg;

#define MSG_POOL_SIZE   16u
typedef struct {
    CanMsg msg[MSG_POOL_SIZE];
    uint8  inUse[MSG_POOL_SIZE];
} CanMsgPool;

static CanMsgPool g_MsgPool;       /* .bss，编译期分配 */

void CanMsgPool_Init(void)
{
    uint16 i;
    for (i = 0u; i < MSG_POOL_SIZE; i++)
    {
        g_MsgPool.inUse[i] = 0u;
    }
}

CanMsg *CanMsgPool_Alloc(void)
{
    uint16 i;
    CanMsg *p = NULL_PTR;
    for (i = 0u; i < MSG_POOL_SIZE; i++)
    {
        if (g_MsgPool.inUse[i] == 0u)
        {
            g_MsgPool.inUse[i] = 1u;
            p = &g_MsgPool.msg[i];
            break;
        }
    }
    return p;                      /* 池满返回 NULL，调用方决定丢包还是上报 Dem */
}

void CanMsgPool_Free(CanMsg *p)
{
    uint16 i;
    if (p != NULL_PTR)
    {
        /* 计算所属块索引，校验指针确实落在池内 */
        uint32 offset = (uint32)((uint8 *)p - (uint8 *)&g_MsgPool.msg[0]);
        if ((offset % sizeof(CanMsg)) == 0u)
        {
            i = (uint16)(offset / sizeof(CanMsg));
            if (i < MSG_POOL_SIZE)
            {
                g_MsgPool.inUse[i] = 0u;
            }
        }
    }
}

/* --- 防 double-free：free 后置 NULL（MISRA 推荐） --- */
void Safe_Free(CanMsg **pp)
{
    if ((pp != NULL_PTR) && (*pp != NULL_PTR))
    {
        CanMsgPool_Free(*pp);
        *pp = NULL_PTR;            /* 再 free 就是空操作，不会破坏链表 */
    }
}
```

## 易错点与陷阱

1. **malloc 失败不检查就用**：`p = malloc(n); p->x = 1;`，p 为 NULL 时直接写空指针。ECU 上必须检查并上报。
2. **free 后继续用指针**：use-after-free，读到被改写的块头或合并后的数据，行为诡异难复现。
3. **重复 free**：链表结构破坏，后续 malloc 返回重叠内存。free 后立即置 NULL 是最简防御。
4. **大小不匹配**：`malloc(10)` 却 `memcpy(p, src, 100)`，堆越界踩了下一块的头，free 时崩溃。ECU 上越界往往延时发作。
5. **ISR 里调 malloc/free**：malloc 的链表操作非线程安全，需锁；中断里不能阻塞。一律禁止。
6. **以为"只 alloc 不 free 就不会碎"**：长期运行下哪怕只 alloc，不同大小请求也会让空闲链表越来越碎。根治是不用 malloc。

## 面试高频题

**Q1：malloc 怎么知道要 free 多少？**
答：块头。malloc 返回的指针前面有块头记录了整块大小，free 回退一个块头偏移就能读到大小。所以用户绝不能改写返回指针前面的字节。

**Q2：内部碎片和外部碎片区别？哪个在 ECU 更致命？**
答：内部碎片是块内对齐/最小块浪费；外部碎片是块间小孔不可复用。ECU 长期运行下外部碎片更致命——总量够但单块不够，分配失败不可逆。

**Q3：free 时为什么要合并相邻空闲块？**
答：防止外部碎片。不合并的话，反复 alloc/free 会让堆全是小空闲块，下次大请求失败。合并把相邻空闲块拼成大块，提高复用率。

**Q4：重复 free 同一指针会怎样？**
答：第二次 free 把已空闲的块再合并一次，链表出现环路或重叠，后续 malloc 返回重叠内存，两处写入互踩，行为难复现。free 后置 NULL 是最简防御。

**Q5：ECU 里怎么替代 malloc？**
答：静态分配（编译期定长数组）+ 定长内存池。池里块大小一致，永不碎片，O(1) 分配，失败可预测上报 Dem。CanTp 会话缓冲、NM 重传队列都适合用池。

**Q6：为什么 free(NULL) 是合法的，而 free(野指针) 会崩？**
答：C 标准规定 free(NULL) 是空操作。野指针指向非堆内存，free 回退读块头读到的是垃圾，链表立刻被破坏。

## 延伸

- [栈与堆](02-栈与堆.md)：堆碎片化在 ECU 是大忌的整体论述。
- [AUTOSAR MemMap 机制](05-AUTOSAR-MemMap机制.md)：内存池缓冲如何在 AUTOSAR 工程里精确落段。
- [内存泄漏与越界排查](06-内存泄漏与越界排查.md)：堆越界破坏块头后的排查手段。
