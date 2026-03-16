# 五级流水线 RISC-V CPU

一个基于 Verilog 的五级流水线 RISC-V CPU 教学/课程项目，包含 Vivado 工程文件、核心 RTL、约束文件以及部分仿真文件。

## 项目特点

- 五级流水线 CPU 结构
- 包含冒险检测与数据前递模块
- SoC 顶层集成 ROM、RAM、外设控制和数码管显示
- 保留 Vivado 工程，可直接打开 `boardtest.xpr`

## 开发环境

- Vivado 2025.1
- FPGA Part: `xc7a100tfgg484-1`

## 仓库结构

```text
boardtest.xpr
boardtest.srcs/
  sources_1/new/      # 核心 RTL 与 insData.txt
  constrs_1/new/      # XDC 约束
  sim_1/new/          # 仿真文件
compile_asm.bat       # 汇编程序转 insData.txt 的辅助脚本
交互式冒泡排序_interactive.asm
```

## 主要模块

- `SoC_top.v`: 顶层模块
- `CPU_SoC.v`: CPU 与片上系统接口
- `CPU.v`: 五级流水线 CPU
- `HazardDetection.v`: 冒险检测
- `ForwardingUnit.v`: 数据前递
- `ROM.v` / `RAM.v`: 指令与数据存储
- `PeripheralController.v`: 外设控制

## 使用方式

### 1. 打开工程

在 Vivado 中打开：

```text
boardtest.xpr
```

综合/实现顶层模块为：

```text
SoC_top
```

### 2. 更新 ROM 程序

默认程序数据位于：

```text
boardtest.srcs/sources_1/new/insData.txt
```

如果需要从汇编重新生成，可使用：

```text
compile_asm.bat
```

脚本会读取：

```text
交互式冒泡排序_interactive.asm
```

并输出新的 `insData.txt`。

### 3. 运行仿真

当前工程默认仿真顶层为：

```text
tb_pipeline_view
```

## 说明

- 仓库已排除 Vivado 生成目录与综合/仿真产物。
- 该仓库当前保留的是适合开源展示和二次使用的最小工程集合。
- 若后续补充更多 testbench，建议同步更新 `boardtest.xpr`。
