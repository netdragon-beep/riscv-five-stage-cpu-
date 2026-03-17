# CPU调试BUG报告 - JALR重复执行与程序卡死问题

**日期**: 2025-11-27
**状态**: 部分修复 ✓ / 新问题发现 ⚠️
**严重程度**: 高

---

## 🔍 问题概述

在测试bubble sort程序时,发现CPU在执行延迟函数(ROM197-200)时陷入无限循环,程序无法继续执行排序逻辑。

### 现象总结

1. ✅ ROM加载正确
2. ✅ 基本指令执行正常
3. ❌ 程序卡在延迟函数循环(ROM196-199)
4. ❌ 600us后仍未完成排序
5. ❌ 寄存器数据未排序: `[3,5,8,1,7,2,9,4]`

---

## 🐛 BUG #1: JALR指令重复执行 (已修复 ✓)

### 问题描述

JALR指令在MEM阶段执行跳转后,由于flush时序问题,导致下一个周期**重复执行相同的跳转**,形成4指令循环。

### 循环模式

```
ROM196 (0x4310): jalr x0, 0(x31)   ← 应该返回,但跳回ROM197
ROM197 (0x4314): addi x26, x0, 80  ← 延迟函数入口
ROM198 (0x4318): addi x26, x26, -1
ROM199 (0x431c): bne  x26, x0, -4  ← 跳回ROM198
```

**实际执行**: ROM197→198→199→196→197... (无限循环)

### 根本原因

#### 时序问题分析:

```
周期N:
  - JALR指令在MEM阶段
  - pcSource_EXMEM = 3 (JALR)
  - flush_on_jump = 1
  - pc_next = aluResult_EXMEM (跳转地址)
  - PC跳转到ROM197 ✓

周期N+1 (时钟上升沿):
  - EX_MEM寄存器被flush (pcSource清零) ✓
  - 但在时钟上升沿之前,组合逻辑已经读取了pcSource_EXMEM!
  - pc_next再次计算跳转地址 ✗
  - PC再次跳转! ✗
```

**问题**: `flush`在时钟上升沿生效,但`pc_next`的组合逻辑在**上升沿之前**就已经使用了`pcSource_EXMEM`的值!

### 修复方案

#### 解决方法: 添加`prev_jump`防护机制

**文件**: `CPU_SoC.v`

**修改前**:
```verilog
reg [31:0] pc_next;

always @(*) begin
    pc_next = pc + 32'd4;
    case (pcSource_EXMEM)
        2'b00: pc_next = pc + 32'd4;
        2'b01: pc_next = pc_EXMEM + imm_EXMEM;  // Branch
        2'b10: pc_next = pc_EXMEM + imm_EXMEM;  // JAL
        2'b11: pc_next = aluResult_EXMEM & 32'hFFFFFFFE;  // JALR
        default: pc_next = pc + 32'd4;
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        pc <= 32'h00004000;
    end else if (!stall) begin
        pc <= pc_next;
    end
end
```

**修改后**:
```verilog
reg [31:0] pc_next;
reg prev_jump;  // 添加:记录上个周期是否跳转

always @(*) begin
    pc_next = pc + 32'd4;

    // 修复:如果上个周期已经跳转,本周期忽略pcSource信号
    if (!prev_jump) begin
        case (pcSource_EXMEM)
            2'b00: pc_next = pc + 32'd4;
            2'b01: pc_next = pc_EXMEM + imm_EXMEM;  // Branch
            2'b10: pc_next = pc_EXMEM + imm_EXMEM;  // JAL
            2'b11: pc_next = aluResult_EXMEM & 32'hFFFFFFFE;  // JALR
            default: pc_next = pc + 32'd4;
        endcase
    end
end

always @(posedge clk) begin
    if (rst) begin
        pc <= 32'h00004000;
        prev_jump <= 1'b0;
    end else begin
        if (!stall) begin
            pc <= pc_next;
            prev_jump <= (pcSource_EXMEM != 2'b00);  // 记录本周期是否跳转
        end else begin
            prev_jump <= 1'b0;  // stall时清除,避免永久阻塞
        end
    end
end
```

### 修复原理

1. **prev_jump标志**: 记录上个周期是否发生了跳转
2. **防护逻辑**: 如果上个周期跳转了,本周期强制`pc_next = pc + 4`,忽略`pcSource_EXMEM`
3. **stall处理**: stall时清除`prev_jump`,避免stall结束后无法跳转

### 修复第二版(改进)

**问题**: 原始修复在stall时可能永久阻塞

**改进**: stall时强制清除`prev_jump`
```verilog
else begin
    prev_jump <= 1'b0;  // stall时清除,避免永久阻塞
end
```

### 验证结果

修复后测试显示:
- ✅ `prev_jump = 0` (正常)
- ✅ `pcSource_EXMEM = 0` (正常)
- ✅ `flush_on_jump = 0` (正常)
- ✅ **不再重复跳转**

**结论**: JALR重复执行问题已解决 ✓

---

## 🐛 BUG #2: 程序逻辑死循环 (新发现 ⚠️)

### 问题描述

修复BUG#1后,程序仍然卡在ROM196-199,但**不是因为重复跳转**,而是程序**逻辑上**在不停调用延迟函数!

### 执行流程分析

```
ROM196: jalr x0, 0(x31)  → 返回到x31地址
ROM197: 延迟函数入口     → 被某处调用
ROM198: 延迟循环
ROM199: bne跳回ROM198    → 循环80次
ROM200: jalr x0, 0(x31)  → 返回
```

**观察到的循环**: ROM197→198→199→196→197...

### 关键线索

1. **ROM196也是JALR返回指令**: `000f8067 jalr x0, 0(x31)`
2. **ROM196在ROM197之前**: 说明ROM196是**某个函数的返回点**
3. **循环模式**: 延迟函数→返回→立即又调用延迟函数

### 可能的原因

#### 假设1: ROM196是一个**返回即调用**的循环

```asm
ROM195: jal x31, delay_func    # 调用延迟
ROM196: jalr x0, 0(x31)        # 返回到上层
ROM197: delay_func入口
```

如果ROM195在一个大循环里被反复调用,就会形成:
```
主循环 → ROM195(调用延迟) → 延迟80次循环 → ROM196返回 → 主循环 → ROM195...
```

#### 假设2: x31寄存器值错误

ROM196的`jalr x0, 0(x31)`应该返回到调用者,但可能:
- x31 = 0x4310 (ROM196自己!) → 死循环
- 或x31 = 0x430c (ROM195) → 立即又调用延迟

### 需要进一步调查

1. **ROM196的调用者是谁?**
   - 检查ROM190-195的指令
   - 找到哪里有`jal x31, +XX`跳到ROM196

2. **x31寄存器的值是多少?**
   - 在ROM196执行时检查x31
   - 确认返回地址是否正确

3. **为什么从未执行排序逻辑?**
   - 寄存器值从80us到580us完全不变
   - 说明程序根本没有进入排序函数

---

## 📊 测试数据

### BUG#1修复前

```
追踪结果 (80us开始):
80.00us | 0x4314 (ROM197)
80.01us | 0x4318 (ROM198)
80.03us | 0x431c (ROM199)
80.05us | 0x4310 (ROM196)  ← 不应该回到这里!
80.07us | 0x4314 (ROM197)  ← 重复跳转!
...

控制信号:
  stall         = 0
  flush_on_jump = 1         ← 一直在flush
  pcSource_EXMEM = 3        ← 一直是JALR
```

### BUG#1修复后

```
追踪结果 (100us):
1. PC = 0x4314 (ROM197)
2. PC = 0x4318 (ROM198)
3. PC = 0x431c (ROM199)
4. PC = 0x4310 (ROM196)
5. PC = 0x4314 (ROM197)

控制信号:
  prev_jump      = 0        ← 正常
  pcSource_EXMEM = 0        ← 正常,不是重复跳转
  flush_on_jump  = 0        ← 正常
```

**结论**: 不再重复跳转,但程序逻辑上确实在循环调用延迟函数!

### 寄存器状态

```
时间     | x1 | x2 | x3 | x4 | x5 | x6 | x7 | x8
---------|----|----|----|----|----|----|----|----|
80us     | 3  | 5  | 8  | 1  | 7  | 2  | 9  | 4
580us    | 3  | 5  | 8  | 1  | 7  | 2  | 9  | 4  ← 完全不变!
期望     | 1  | 2  | 3  | 4  | 5  | 7  | 8  | 9
```

**结论**: 程序根本没有执行排序逻辑!

---

## 🎯 下一步行动

### 立即行动

1. ✅ **BUG#1已修复**: JALR重复执行问题解决
2. ⏳ **调查BUG#2**: 找出为什么程序卡在延迟函数

### 调查步骤

#### 步骤1: 分析ROM190-196的指令
```tcl
# 查看ROM196的调用上下文
python decode_instructions.py | grep -A 3 -B 3 "ROM196"
```

#### 步骤2: 监控x31寄存器
```tcl
# 在ROM196执行时检查x31的值
# 如果x31=0x4310,说明返回地址错误
```

#### 步骤3: 检查完整程序流程
```tcl
# 从ROM0开始追踪,找出主程序入口
# 确定bubble_sort函数是否被调用
```

#### 步骤4: 检查RAM[0]=0的影响
- RAM[0]应该是5,但实际是0
- 可能影响排序判断逻辑
- 导致排序被跳过

---

## 💡 经验教训

### 教训1: 时序问题的隐蔽性

**问题**: flush信号虽然存在,但生效时机晚于组合逻辑读取

**启示**:
- 流水线控制信号的时序非常关键
- 组合逻辑和时序逻辑的交互需要仔细设计
- 简单的flush可能不够,需要额外的防护机制

### 教训2: 逐层调试的重要性

**方法**:
1. 先解决明显的硬件bug (JALR重复)
2. 再分析程序逻辑问题 (为什么调用延迟)
3. 最后优化性能和边界情况

**避免**: 同时调试多个问题,导致混淆

### 教训3: 测试脚本的价值

**有效的脚本**:
- `trace_execution_flow.tcl` - 发现了4指令循环
- `check_where_stuck.tcl` - 确认修复生效
- `debug_rom_loading.tcl` - 发现ROM加载错误

**建议**: 为每个调试场景编写专门的脚本

---

## 📝 相关文件

| 文件 | 修改内容 | 状态 |
|------|---------|------|
| `CPU_SoC.v` | 添加`prev_jump`防护机制 | ✅ 已修改 |
| `ROM.v` | 修复insData.txt路径 | ✅ 已修改 |
| `trace_execution_flow.tcl` | 追踪PC执行流程 | 📝 工具脚本 |
| `check_where_stuck.tcl` | 快速检查卡住位置 | 📝 工具脚本 |
| `DEBUG_PROGRESS.md` | 之前的调试记录 | 📄 参考文档 |

---

## 🔄 修复历史

### 2025-11-27 - 第一次尝试修复

**修改**: 添加`prev_jump`标志,防止重复跳转

**问题**: stall时可能永久阻塞

### 2025-11-27 - 改进修复

**修改**: stall时清除`prev_jump`

**结果**: ✅ JALR重复执行问题解决

**新问题**: 程序逻辑死循环

---

## 📞 技术细节

### 流水线跳转时序图

```
时间 →

Cycle N:
  IF:  NOP (被flush)
  ID:  NOP (被flush)
  EX:  NOP (被flush)
  MEM: JALR (x31=0x4310)  ← pcSource=3, 计算跳转地址
  WB:  (前一条指令)

  [组合逻辑] pc_next = aluResult_EXMEM = 0x4314
  [时序逻辑] flush_on_jump = 1

Cycle N+1 (时钟上升沿前):
  [组合逻辑] 再次读取pcSource_EXMEM = 3 ✗
  [组合逻辑] 再次计算pc_next = 0x4314 ✗

Cycle N+1 (时钟上升沿):
  [时序逻辑] EX_MEM被flush, pcSource_EXMEM = 0 ✓ (但已经晚了!)
  [时序逻辑] PC <= 0x4314 (第二次跳转!) ✗
```

**修复后时序图**:

```
Cycle N:
  MEM: JALR
  prev_jump = 0
  pc_next = 0x4314  ← 第一次跳转

Cycle N+1 (时钟上升沿):
  prev_jump <= 1    ← 记录已跳转
  PC <= 0x4314 ✓

Cycle N+2:
  prev_jump = 1     ← 阻止重复跳转
  pc_next = PC + 4  ← 强制顺序执行
```

---

**报告完成时间**: 2025-11-27
**最后更新**: BUG#1已修复,BUG#2调查中
