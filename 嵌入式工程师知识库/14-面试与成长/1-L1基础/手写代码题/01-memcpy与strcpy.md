# 01-memcpy与strcpy

> 一句话定位：白板第一题——两行函数签名背后考的是 void* 造型、逐字节拷贝、返回值语义与内存重叠的敏感度，写挂任何一处都会被追问到 C 标准的未定义行为。
> 等级：L1 ｜ 前置：[面试是知识库的期末考试](../../00-入门导读/01-面试是知识库的期末考试.md)

## 题目描述

**题 A（strcpy）**：实现标准库函数 `char *strcpy(char *dest, const char *src);`——把 src 指向的字符串（含结尾 `\0`）复制到 dest，返回 dest。

**题 B（memcpy）**：实现标准库函数 `void *memcpy(void *dest, const void *src, size_t n);`——从 src 拷贝 n 个字节到 dest，返回 dest。

白板时限：各 5 分钟，写完口头回答"memcpy 遇到内存重叠会怎样？"

## 手写参考实现

```c
#include <stddef.h>   /* size_t */

/* 题 A：strcpy —— 逐字符拷贝，直到拷完 '\0' 为止 */
char *my_strcpy(char *dest, const char *src)
{
    char *ret = dest;                 /* 先留底：返回值必须是原始 dest */

    while ((*dest++ = *src++) != '\0') /* 拷一个字符，判断它是不是 '\0' */
    {
        ;                              /* 经典写法：赋值表达式本身产出判断值 */
    }
    return ret;                        /* 支持链式调用 strcpy(a, strcpy(b, c)) */
}

/* 题 B：memcpy —— n 是字节数，与 '\0' 无关 */
void *my_memcpy(void *dest, const void *src, size_t n)
{
    unsigned char       *d = (unsigned char *)dest; /* 按字节操作必须用 char* */
    const unsigned char *s = (const unsigned char *)src;

    if ((NULL == dest) || (NULL == src))
    {
        return NULL;                   /* 防御：空指针直接退出（标准库是 UB，工程上要防） */
    }

    while (n-- > 0U)                   /* 先判断 n>0，再自减：边界 n=0 时不进循环 */
    {
        *d++ = *s++;
    }
    return dest;
}

/* 追问标配：memmove —— 处理重叠区域的标准答案 */
void *my_memmove(void *dest, const void *src, size_t n)
{
    unsigned char       *d = (unsigned char *)dest;
    const unsigned char *s = (const unsigned char *)src;

    if (d < s)                         /* 目标在前：从低到高正向拷，安全 */
    {
        while (n-- > 0U)
        {
            *d++ = *s++;
        }
    }
    else if (d > s)                    /* 目标在后：从高到低倒着拷，避免覆盖未读数据 */
    {
        d += n;
        s += n;
        while (n-- > 0U)
        {
            *--d = *--s;
        }
    }
    else
    {
        /* d == s：同一地址，什么都不用做 */
    }
    return dest;
}
```

## 考点解析

1. **void* 的用法**：`void*` 不能解引用、不能做算术运算（GNU 扩展除外），必须先转成 `unsigned char*` 再逐字节操作——用 `char` 而非 `int` 是因为拷贝单位是字节，且 `unsigned` 避免符号扩展干扰；
2. **strcpy 的 while 条件**：`(*dest++ = *src++) != '\0'` 一行同时完成拷贝、指针推进、终止判断三件事——考官想看的就是你敢不敢写这行，以及能不能讲清它；
3. **返回值为什么是 dest**：标准库大量函数返回目标指针以支持链式表达（`strcat(strcpy(buf, "a"), "b")`）；嵌入式 MISRA 风格下返回值常被丢弃，但签名必须对；
4. **memcpy 不管 `\0`**：n 是字节数，拷 0 字节合法（直接返回）；拷的内容里有没有 `\0` 与它无关——与 strcpy 的"哨兵字符终止"是两种范式；
5. **重叠是 memcpy 的雷区**：C 标准规定 memcpy 的 src/dest 不得重叠，重叠即未定义行为（UB）。重叠场景必须用 memmove——它靠"判断方向、必要时倒着拷"保证先读后写。这与 NvM/Fee 显式同步里"备份后再写"是同一种先读后写直觉（[07 区内存栈](../../../07-AUTOSAR架构/2-L2进阶/内存栈/02-写队列与显隐同步.md)）。

## 常见写挂点

| 写挂点 | 现场表现 | 纠正 |
|---|---|---|
| 直接 `*dest = *src` 不推进指针 | 死循环写满一块内存 | `*d++ = *s++` 或显式下标循环 |
| 忘拷结尾 `\0`（strcpy 用 for 按长度拷） | 目标字符串没有终止符，后续 strlen 越界 | while 以拷到 `\0` 为止，判断写在拷贝之后 |
| memcpy 里没转 char* 就解引用 void* | 编译直接报错，白板上属于当场挂 | 先造型 `unsigned char*` |
| `while (n-- > 0)` 写成 `while (--n > 0)` | n=1 时一次都不拷、n=0 时下溢成 SIZE_MAX | 先比较后自减（`n-- > 0`） |
| 用 memcpy 回答重叠问题说"没问题" | 暴露没读过标准，UB 概念缺失 | 承认 UB，给出 memmove 方案 |
| 返回 src 或不写 return | 签名与实现不符 | 返回原始 dest |

## 变形追问

- **Q：为什么 strcpy 危险？怎么防？**——无长度检查，dest 空间不足即缓冲区溢出。防法：用 `strncpy`/`snprintf`，且 strncpy 也要注意"源超长时目标无 `\0`"的坑（自己补终止符）；
- **Q：restrict 关键字知道吗？**——C99 起标准库签名是 `void *memcpy(void * restrict s1, const void * restrict s2, size_t n);`，restrict 是编译器承诺"这两块不重叠"，是"重叠即 UB"的形式化表达；
- **Q：怎么写一个更快的 memcpy？**——按字长拷贝：先按字节对齐到 4/8 字节边界，再整字（uint32_t/uint64_t）搬运，尾部剩余字节单拷；更深的答案涉及 DMA（[04 区 DMA 专题](../../../04-MCAL与外设驱动/3-L3高级/DMA专题/01-DMA原理.md)）；
- **Q：dest 和 src 部分重叠，my_memcpy 哪步出错？**——正向逐字节拷时，若 dest 落在 src+n 范围内，前面的写入会污染尚未读取的源数据——所以 memmove 倒着拷；
- **Q：MISRA C 怎么看这几段代码？**——隐式指针转换、`!= '\0'` 建议显式写 `(char)` 比较、函数出口单一化；工程版要加 NULL 检查与圈复杂度控制（[01 区 MISRA 高频违规条目](../../../01-编程语言/2-L2进阶/代码规范与MISRA-C/03-高频违规条目解析.md)）。

## 延伸

- 上一篇：[面试是知识库的期末考试](../../00-入门导读/01-面试是知识库的期末考试.md)
- 下一篇：[02-位操作题](02-位操作题.md)
- 地基回炉：[01 区/指针与数组](../../../01-编程语言/1-L1基础/指针专题/01-指针与数组.md)、[01 区/常见笔试题（指针）](../../../01-编程语言/1-L1基础/指针专题/05-常见笔试题.md)、[01 区/五大内存区](../../../01-编程语言/2-L2进阶/内存管理/01-五大内存区.md)
- 题库配套：[01-C语言与嵌入式基础](../../2-L2进阶/汽车电子面试题库/01-C语言与嵌入式基础.md)（问答版）

---

维护约定：笔记命名 `序号-主题.md`；真实截图放 `_images/`；流程/时序/状态/架构图用 PlantUML 内嵌正文，规范见 [图表规范与模板](../../../00-总览/图表规范与模板.md)。
