# LED 闪烁可见性修复建议

## 问题描述

当前交换动画 LED[19] 的闪烁时间太短（1.28μs），在实际 FPGA 板上人眼无法看见。

## 时间分析

| 参数 | 当前值 | 人眼需求 | 差距 |
|------|--------|----------|------|
| 延迟周期 | 0x40 (64) | 约 500,000 | 7800x 太快 |
| 延迟时间 | 1.28μs | 10-50ms | 8000x 太快 |
| CPU频率 | 50MHz | - | - |

**结论**: 需要增加延迟约 **8000倍** 才能让人眼看清闪烁。

---

## 修复方案

### 方案1: 修改 short_delay 延迟时间（推荐用于实际板级调试）

**目标延迟**: 30ms（舒适的可见闪烁）

**计算**:
```
需要周期数 = 30ms / 20ns = 1,500,000 cycles = 0x16E360
```

**修改位置**: `交互式冒泡排序_interactive.asm` 第 642 行

**原代码**:
```assembly
short_delay:
    addi x26, x0, 0x40        # 64 cycles
short_delay_loop:
    addi x26, x26, -1
    bne x26, x0, short_delay_loop
    jalr x0, x31, 0
```

**修改为** (30ms可见版本):
```assembly
short_delay:
    # 30ms延迟，用于实际FPGA板
    lui x26, 0x0017           # x26 = 0x17000 = 94,208
    addi x26, x26, 0x360      # x26 = 94,208 + 864 = 95,072 ≈ 1.9ms
    # 注：由于立即数限制，这里设置约2ms，调用15次 ≈ 30ms
short_delay_loop:
    addi x26, x26, -1
    bne x26, x0, short_delay_loop
    jalr x0, x31, 0
```

**或更简单的可见版本** (100ms):
```assembly
short_delay:
    lui x26, 0x0050           # x26 = 0x50000 = 327,680 cycles
    # 327,680 × 20ns ≈ 6.5ms
short_delay_loop:
    addi x26, x26, -1
    bne x26, x0, short_delay_loop
    jalr x0, x31, 0

# 然后在 show_swap 函数中调用多次
show_swap:
    addi sp, sp, -4
    sw x31, 0(sp)

    lui x26, 0x00A00
    lui x27, 0x00080
    or x26, x26, x27
    sw x26, 0(x21)

    # 增加延迟次数
    addi x5, x0, 10           # 调用10次 short_delay
swap_delay_loop:
    jal x31, short_delay
    addi x5, x5, -1
    bne x5, x0, swap_delay_loop

    lui x26, 0x00A00
    sw x26, 0(x21)

    lw x31, 0(sp)
    addi sp, sp, 4
    jalr x0, x31, 0
```

---

### 方案2: 保持仿真速度，添加可配置延迟（推荐）

在汇编代码开头添加一个延迟倍数配置：

```assembly
# 配置区：延迟倍数
# DELAY_MULTIPLIER: 1 = 仿真速度, 10000 = 实际板级可见速度
.eqv DELAY_MULTIPLIER 1    # 仿真时用1，FPGA板用10000
```

然后修改 short_delay:

```assembly
short_delay:
    lui x26, %hi(DELAY_MULTIPLIER)
    addi x26, x26, %lo(DELAY_MULTIPLIER)
    slli x26, x26, 6          # × 64 (0x40)
short_delay_loop:
    addi x26, x26, -1
    bne x26, x0, short_delay_loop
    jalr x0, x31, 0
```

**使用方法**:
- 仿真时: 保持 `DELAY_MULTIPLIER = 1`
- FPGA板: 修改为 `DELAY_MULTIPLIER = 10000`

---

### 方案3: 使用 medium_delay（最快实现）

直接把 `show_swap` 函数中的 `short_delay` 改为 `medium_delay`:

**修改位置**: `交互式冒泡排序_interactive.asm` 第 629 行

```assembly
show_swap:
    addi sp, sp, -4
    sw x31, 0(sp)

    lui x26, 0x00A00
    lui x27, 0x00080
    or x26, x26, x27
    sw x26, 0(x21)

    jal x31, medium_delay     # 改为 medium_delay (约6.4μs)
                              # 或者多次调用
    addi x5, x0, 5000         # 调用5000次
delay_visible:
    jal x31, medium_delay
    addi x5, x5, -1
    bne x5, x0, delay_visible

    lui x26, 0x00A00
    sw x26, 0(x21)

    lw x31, 0(sp)
    addi sp, sp, 4
    jalr x0, x31, 0
```

**延迟计算**:
- `medium_delay` = 5 × `short_delay` = 5 × 1.28μs = 6.4μs
- 调用 5000 次 = 5000 × 6.4μs = 32ms ✅ **人眼可见**

---

## 推荐实施步骤

### 对于当前仿真验证（不需要修改）：
✅ **保持现状** - 仿真速度快，已验证排序逻辑正确

### 对于实际FPGA板部署：
1. 修改 `short_delay` 的初始值 `0x40` → `0x50000` (第642行)
2. 在 `show_swap` 中增加延迟循环次数
3. 重新编译汇编代码
4. 烧录到FPGA板观察效果

---

## 预期效果

| 场景 | LED[19]闪烁 | 排序时间 | 适用 |
|------|------------|----------|------|
| 当前（仿真） | 1.28μs ❌ 看不见 | 108μs | ✅ 快速验证逻辑 |
| 修复后（FPGA） | 30ms ✅ 清晰可见 | 约5秒 | ✅ 实际演示 |

---

## 总结

**您的观察完全正确**！当前设计在仿真中工作正常，但在实际FPGA板上LED[19]闪烁太快，人眼无法察觉。

**建议**:
- **仿真阶段**: 保持现状（快速验证）
- **FPGA部署**: 增加延迟至少 10,000 倍

这是一个经典的 **仿真 vs 实际硬件** 的差异案例！
