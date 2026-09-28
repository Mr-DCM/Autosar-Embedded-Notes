# 构造析构与 vtable 开销

> 一句话定位：搞清"对象怎么被造出来、怎么被拆掉、虚函数到底多花了什么"，并用 C 函数指针表写出与之等价的代码——这是 C 工程师看懂 C++ 的最短路径。
> 等级：L2 ｜ 前置：[03-函数指针与回调](../../../1-L1基础/指针专题/03-函数指针与回调.md)

## 原理

**构造/析构顺序铁律**：

- 构造：基类先于成员、成员按**声明序**（不是初始化列表序）、构造函数体最后执行。
- 析构：完全逆序——析构函数体先执行，成员按声明逆序析构，基类最后。
- 构造期间"对象还没长成"：基类构造函数里调用虚函数不会下落到派生类版本（此时 vptr 还指着基类的 vtable），这是与直觉最大的偏差。

**vtable（虚函数表）机制**：

- 编译器为每个**含虚函数的类**生成一张静态表（放 Flash），表项是各虚函数地址；
- 每个对象开头隐含一个 vptr 指向所属类的表；
- 虚调用 = 取对象 vptr → 查表槽位 → 间接跳转。

这和 C 里"结构体 + 函数指针表"的手工多态**在机器码层面等价**：vptr ≈ 结构体里手工放的操作表指针，vtable ≈ const 函数指针数组，虚调用 ≈ `obj->ops->read(obj)`。区别只在：C++ 由编译器自动插表、自动传 `this`、并在继承时自动复制/覆盖表项；C 里全靠手写，漏一项就是空指针调用。

```plantuml
@startuml
title 虚函数对象内存布局与调用链（Cortex-M，32 位）
skinparam defaultFontName "Microsoft YaHei"
package "RAM : SpiDriver 对象" {
  [vptr --> 指向 SpiDriver 的 vtable]
  [reg_ : 外设基址]
}
package "Flash : vtable for SpiDriver" {
  [槽0 : &SpiDriver::Read]
  [槽1 : &IDriver::~IDriver]
}
[调用方] --> vptr : 1. ldr 取 vptr
vptr --> [槽0 : &SpiDriver::Read] : 2. 按槽位取地址
[槽0 : &SpiDriver::Read] --> [SpiDriver::Read 函数体] : 3. blx 间接跳转
note over [RAM : SpiDriver 对象], [Flash : vtable for SpiDriver] : 等价于 C 里：\nstruct SpiDriver { const DriverOps* ops; volatile uint32_t* reg; };\n调用：obj->ops->read(obj)
@enduml
```

## 代码示例

同一套"硬件抽象接口"的 C 与 C++ 双版本对照：

```cpp
// ================= C++ 版：IDriver 接口 -> SPI/CAN 实现 =================
class IDriver {                       // 纯虚接口类（≈ C 的 ops 结构体定义）
public:
    virtual uint8_t  Read()  = 0;
    virtual void     Write(uint8_t v) = 0;
    virtual ~IDriver() = default;     // 虚析构：经基类指针 delete 才走派生析构
};

class SpiDriver final : public IDriver {
public:
    explicit SpiDriver(volatile uint32_t* reg) : reg_(reg) {}  // 构造只赋值
    uint8_t Read()        override { return static_cast<uint8_t>(reg_[0]); }
    void    Write(uint8_t v) override { reg_[0] = v; }
private:
    volatile uint32_t* reg_;          // 声明序：reg_ 先于 count_ 构造
    uint32_t           count_ = 0;
};

class CanDriver final : public IDriver { /* 同构，略 */ };

// 上层代码只见接口，与具体总线解耦：
void Poll(IDriver& d) { d.Write(d.Read()); }   // 虚调用两次

// ================= C 版：函数指针表手工多态 =================
/* driver.h —— 接口（≈ 纯虚类） */
typedef struct DriverOps {
    uint8_t (*read) (void* self);
    void    (*write)(void* self, uint8_t v);
} DriverOps;

typedef struct Driver {               /* ≈ IDriver 基类：只有 vptr */
    const DriverOps* ops;
} Driver;

typedef struct SpiDriver {            /* ≈ 派生类：基类部分 + 自己的成员 */
    Driver             base;          /* 必须放第一个成员，指针才能安全互转 */
    volatile uint32_t* reg;
    uint32_t           count;
} SpiDriver;

static uint8_t Spi_Read(void* self) {
    SpiDriver* me = (SpiDriver*)self;
    return (uint8_t)me->reg[0];
}
static void Spi_Write(void* self, uint8_t v) {
    ((SpiDriver*)self)->reg[0] = v;
}
/* ≈ vtable：一张静态 const 表，放 Flash */
static const DriverOps kSpiOps = { Spi_Read, Spi_Write };

void SpiDriver_Init(SpiDriver* me, volatile uint32_t* reg) {
    me->base.ops = &kSpiOps;          /* 手工"设置 vptr" */
    me->reg      = reg;
    me->count    = 0u;
}

/* 上层调用：obj->ops->read(obj) —— 与 C++ 虚调用同一套机器码 */
void Poll_C(Driver* d) { d->ops->write(d, d->ops->read(d)); }
```

对照结论：

| 维度 | C++ 虚函数 | C 函数指针表 |
|---|---|---|
| 表的生成 | 编译器自动 | 手写 static const 数组 |
| this/self 传递 | 自动 | 手工传 `void*` 并强转 |
| 漏实现检查 | 纯虚函数=0 强制实现 | 漏填 = 运行时空指针跳转 |
| 覆盖/继承 | override 关键字编译期校验 | 手工复制整表再改个别项 |
| 运行时开销 | vptr 4B/对象 + 间接跳转 | 完全相同（ops 指针 + 间接跳转） |

## 易错点与陷阱

- **初始化列表顺序陷阱**：成员实际按**声明序**构造，初始化列表写得再花也改不了；若成员初始化互相依赖且列表序 ≠ 声明序，GCC `-Wreorder` 会告警，别忽略。
- **基类构造函数里调虚函数**：不下落（dispatch）到派生版本——此时对象还是"半个"，vptr 指向基类表。想强制子类定制构造行为，用"构造后显式 Init()"模式。
- **缺虚析构**：`IDriver* p = new SpiDriver(...); delete p;` 若 `~IDriver()` 非虚，只执行基类析构（在 MCU 上 new 本就被禁，但对象若经 placement/静态工厂管理同样踩坑）。接口类一律 `virtual ~IDriver() = default;`。
- **构造函数里做硬件动作**：全局对象的构造发生在 `main` 前（`__libc_init_array`），此时时钟/栈环境未必就绪；构造只赋值，寄存器操作放显式 `Init()`，见 [02-开销分析](../嵌入式C++实践/02-开销分析.md)。
- **C 结构体里 base 不放第一位**：`Driver* ↔ SpiDriver*` 的互转就不再是"零偏移强转"，老代码里到处 `(Driver*)&spi.base` 极易漏写。
- **`final` 忘加**：`final` 既封死继承，又给编译器去虚化（devirtualization）机会——单态调用点可直接内联，等于白捡的性能。

## 面试高频题

1. **构造函数可以是虚函数吗？为什么？**
   答：不可以。虚调用依赖对象里已有的 vptr，而 vptr 正是在构造过程中才被设置的——"鸡生蛋"死循环。析构则必须（在多态删除场景下）是虚的。
2. **说说 C++ 对象的构造顺序。**
   答：最底层基类 → 按继承层次向上 → 每层成员按**类内声明序** → 最后构造函数体；析构严格逆序。基类构造期虚调用不下落是顺序规则的直接推论。
3. **虚函数和 C 函数指针表比，运行时到底贵在哪？**
   答：不贵——两者同构（表指针 + 间接跳转）。真正的差距在维护性：C++ 编译期校验签名/覆盖/漏实现，C 靠人肉纪律；以及 C++ 编译器可借 `final`/LTO 去虚化内联，C 的函数指针同样难以内联。
4. **一个含 3 个虚函数的类，实例化 100 个对象，多占多少 RAM？**
   答：vtable 只有 1 张（Flash，约 3×4=12 字节起）；RAM 增量 = 100 × 4 字节 vptr（Cortex-M32 位），与虚函数个数无关——vptr 每对象一个，不是每虚函数一个。

## 延伸

- [02-开销分析](../嵌入式C++实践/02-开销分析.md)：map 文件验证虚函数/异常/静态构造开销的实操
- [01-哪些特性适合MCU](../嵌入式C++实践/01-哪些特性适合MCU.md)：虚函数"限接口层使用"的取舍依据
- [RAII 在嵌入式中的应用](../RAII与资源管理/01-RAII在嵌入式中的应用.md)：构造/析构顺序铁律的正面应用
