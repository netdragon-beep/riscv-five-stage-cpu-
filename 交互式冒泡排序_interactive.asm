
.org 0x00004000
.text

_start:
    # 初始化栈指针和基地址
    lui sp, 0x00001
    lui x1, 0x00000
    lui x20, 0x10000
    addi x20, x20, 8         # 数码管地址
    lui x21, 0x10000         # LED地址
    lui x22, 0x10000
    addi x22, x22, 4         # 开关地址

    # 初始化状态
    addi x9, x0, 0

    # 预加载掩码
    addi x3, x0, 1
    slli x3, x3, 11          # SW[11]掩码
    addi x4, x0, 1
    slli x4, x4, 10          # SW[10]掩码
    addi x8, x0, 1
    slli x8, x8, 12          # SW[12]掩码

system_init:
    # 系统运行指示灯
    lui x26, 0x00800
    sw x26, 0(x21)
    jal x31, medium_delay

    # 等待输入状态
    lui x26, 0x00900
    sw x26, 0(x21)

reset_input:
    addi x23, x0, 0          # 输入计数清零
    addi x25, x0, 0          # LED进度清零
    addi x9, x0, 0

    # 内存初始化为0xF
    addi x26, x0, 0xF
    sw x26, 0(x1)
    sw x26, 4(x1)
    sw x26, 8(x1)
    sw x26, 12(x1)
    sw x26, 16(x1)
    sw x26, 20(x1)
    sw x26, 24(x1)
    sw x26, 28(x1)

    # 数码管显示"-"
    addi x26, x0, -1
    sw x26, 0(x20)

    # 设置等待输入LED
    lui x26, 0x00900
    sw x26, 0(x21)

wait_all_switches_release:
    lw x24, 0(x22)
    and x26, x24, x4
    bne x26, x0, wait_all_switches_release
    and x26, x24, x3
    bne x26, x0, wait_all_switches_release
    and x26, x24, x8
    bne x26, x0, wait_all_switches_release

input_loop:
    lw x24, 0(x22)

    # 检查清除按钮
    and x26, x24, x3
    beq x26, x0, check_switch_conflict
    jal x31, check_clear_hold
    beq x26, x0, input_loop
    j reset_input

check_switch_conflict:
    # 检查排序按钮
    and x26, x24, x8
    beq x26, x0, check_digit_switches

    # 检查是否输入满8位
    addi x26, x0, 8
    beq x23, x26, start_sorting
    jal x31, error_flash
    j input_loop

check_digit_switches:
    andi x26, x24, 0x3FF
    beq x26, x0, input_loop

    # 统计打开的开关数量
    addi x27, x0, 0
    addi x28, x0, 0
    addi x29, x0, 10

count_switches:
    andi x5, x26, 1
    add x27, x27, x5
    srli x26, x26, 1
    addi x28, x28, 1
    blt x28, x29, count_switches

    # 只允许一个开关打开
    addi x28, x0, 1
    beq x27, x28, single_switch_ok
    jal x31, error_flash
    j input_loop

single_switch_ok:
    lw x24, 0(x22)
    andi x26, x24, 0x3FF

    # 解码开关编号
    addi x27, x0, 0

decode_loop:
    andi x28, x26, 1
    bne x28, x0, decode_done
    srli x26, x26, 1
    addi x27, x27, 1
    addi x28, x0, 10
    blt x27, x28, decode_loop
    j input_loop

decode_done:
    # 等待确认按钮上升沿

wait_confirm:
    lw x24, 0(x22)
    and x26, x24, x3
    bne x26, x0, input_loop
    and x26, x24, x4

    # 边沿检测
    bne x9, x0, update_prev_state
    beq x26, x0, update_prev_state
    j confirm_input

update_prev_state:
    beq x26, x0, set_prev_zero
    addi x9, x0, 1
    j wait_confirm
set_prev_zero:
    addi x9, x0, 0
    j wait_confirm

confirm_input:
    addi x9, x0, 1

    # 保存数字到内存
    slli x28, x23, 2
    add x28, x28, x1
    sw x27, 0(x28)

    # 更新LED进度
    addi x26, x0, 1
    sll x26, x26, x23
    or x25, x25, x26
    lui x26, 0x00900
    or x26, x26, x25
    sw x26, 0(x21)

    # 更新数码管
    jal x31, update_display
    addi x23, x23, 1
    jal x31, confirm_flash

wait_confirm_release:
    lw x24, 0(x22)
    and x26, x24, x4
    beq x26, x0, confirm_released
    andi x28, x24, 0x3FF
    bne x28, x0, wait_confirm_release

    # 警告: 先关闭数字开关
    addi x26, x0, -1
    sw x26, 0(x21)

wait_confirm_close_warning:
    lw x24, 0(x22)
    and x26, x24, x4
    bne x26, x0, wait_confirm_close_warning

    # 恢复正常状态
    lui x26, 0x00900
    or x26, x26, x25
    sw x26, 0(x21)
    addi x9, x0, 0
    j check_input_count

confirm_released:
    addi x9, x0, 0

wait_digit_release:
    lw x24, 0(x22)
    andi x26, x24, 0x3FF
    bne x26, x0, wait_digit_release

check_input_count:
    addi x26, x0, 8
    blt x23, x26, input_loop

    # 输入完成
    lui x26, 0x00800
    or x26, x26, x25
    sw x26, 0(x21)

# 等待开始排序
wait_sort_start:
    lw x24, 0(x22)
    and x26, x24, x3
    beq x26, x0, check_sort_button
    jal x31, check_clear_hold
    bne x26, x0, reset_input

check_sort_button:
    lw x24, 0(x22)
    and x26, x24, x8
    beq x26, x0, wait_sort_start

# 开始排序
start_sorting:
    lui x26, 0x00A00
    sw x26, 0(x21)

    # 加载数据
    lw x10, 0(x1)
    lw x11, 4(x1)
    lw x12, 8(x1)
    lw x13, 12(x1)
    lw x14, 16(x1)
    lw x15, 20(x1)
    lw x16, 24(x1)
    lw x17, 28(x1)

    jal x31, display_array

    # 冒泡排序
    addi x18, x0, 0

outer_loop:
    addi x30, x0, 0
    addi x19, x0, 7
    sub x19, x19, x18

inner_loop:
    jal x31, compare_and_swap
    addi x30, x30, 1
    blt x30, x19, inner_loop
    addi x18, x18, 1
    addi x26, x0, 7
    blt x18, x26, outer_loop

# 排序完成
sort_complete:
    lui x26, 0x00C00
    ori x26, x26, 0xFF
    sw x26, 0(x21)
    jal x31, display_array
    jal x31, complete_flash

# 结束状态
end_state:
    lw x24, 0(x22)
    and x26, x24, x3
    beq x26, x0, end_state
    jal x31, check_clear_hold
    bne x26, x0, system_init
    j end_state

# 检查清除按钮持续按住
check_clear_hold:
    addi sp, sp, -4
    sw x31, 0(sp)
    addi x26, x0, 50

clear_hold_loop:
    jal x31, short_delay
    lw x24, 0(x22)
    and x27, x24, x3
    beq x27, x0, clear_not_held
    addi x26, x26, -1
    bne x26, x0, clear_hold_loop

    addi x26, x0, 1
    lw x31, 0(sp)
    addi sp, sp, 4
    jalr x0, x31, 0

clear_not_held:
    addi x26, x0, 0
    lw x31, 0(sp)
    addi sp, sp, 4
    jalr x0, x31, 0

# 错误闪烁
error_flash:
    addi sp, sp, -8
    sw x31, 0(sp)
    sw x5, 4(sp)
    addi x5, x0, 3

error_flash_loop:
    addi x26, x0, -1
    sw x26, 0(x21)
    jal x31, medium_delay
    sw x0, 0(x21)
    jal x31, medium_delay
    addi x5, x5, -1
    bne x5, x0, error_flash_loop

    lui x26, 0x00900
    or x26, x26, x25
    sw x26, 0(x21)

    lw x5, 4(sp)
    lw x31, 0(sp)
    addi sp, sp, 8
    jalr x0, x31, 0

# 确认闪烁
confirm_flash:
    addi sp, sp, -4
    sw x31, 0(sp)

    lui x26, 0x00900
    or x26, x26, x25
    ori x26, x26, 0x100
    sw x26, 0(x21)
    jal x31, medium_delay

    lui x26, 0x00900
    or x26, x26, x25
    sw x26, 0(x21)

    lw x31, 0(sp)
    addi sp, sp, 4
    jalr x0, x31, 0

# 完成闪烁
complete_flash:
    addi sp, sp, -4
    sw x31, 0(sp)
    addi x5, x0, 5

complete_flash_loop:
    lui x26, 0x00C00
    ori x26, x26, 0xFF
    sw x26, 0(x21)
    jal x31, long_delay

    lui x26, 0x00800
    sw x26, 0(x21)
    jal x31, long_delay

    addi x5, x5, -1
    bne x5, x0, complete_flash_loop

    lui x26, 0x00C00
    ori x26, x26, 0xFF
    sw x26, 0(x21)

    lw x31, 0(sp)
    addi sp, sp, 4
    jalr x0, x31, 0

# 更新数码管显示
update_display:
    addi sp, sp, -4
    sw x31, 0(sp)

    lw x5, 0(x1)
    lw x6, 4(x1)
    lw x7, 8(x1)
    lw x28, 12(x1)

    slli x26, x5, 28
    slli x27, x6, 24
    or x26, x26, x27
    slli x27, x7, 20
    or x26, x26, x27
    slli x27, x28, 16
    or x26, x26, x27

    lw x5, 16(x1)
    lw x6, 20(x1)
    lw x7, 24(x1)
    lw x28, 28(x1)

    slli x27, x5, 12
    or x26, x26, x27
    slli x27, x6, 8
    or x26, x26, x27
    slli x27, x7, 4
    or x26, x26, x27
    or x26, x26, x28

    sw x26, 0(x20)

    lw x31, 0(sp)
    addi sp, sp, 4
    jalr x0, x31, 0

# 显示数组
display_array:
    slli x28, x10, 28
    slli x27, x11, 24
    or x28, x28, x27
    slli x27, x12, 20
    or x28, x28, x27
    slli x27, x13, 16
    or x28, x28, x27
    slli x27, x14, 12
    or x28, x28, x27
    slli x27, x15, 8
    or x28, x28, x27
    slli x27, x16, 4
    or x28, x28, x27
    or x28, x28, x17
    sw x28, 0(x20)
    jalr x0, x31, 0

# 比较并交换
compare_and_swap:
    addi sp, sp, -4
    sw x31, 0(sp)

    beq x30, x0, compare_01
    addi x27, x0, 1
    beq x30, x27, compare_12
    addi x27, x0, 2
    beq x30, x27, compare_23
    addi x27, x0, 3
    beq x30, x27, compare_34
    addi x27, x0, 4
    beq x30, x27, compare_45
    addi x27, x0, 5
    beq x30, x27, compare_56
    addi x27, x0, 6
    beq x30, x27, compare_67

    lw x31, 0(sp)
    addi sp, sp, 4
    jalr x0, x31, 0

compare_01:
    blt x10, x11, no_swap_01
    add x27, x10, x0
    add x10, x11, x0
    add x11, x27, x0
    jal x31, show_swap
    jal x31, display_array
no_swap_01:
    lw x31, 0(sp)
    addi sp, sp, 4
    jalr x0, x31, 0

compare_12:
    blt x11, x12, no_swap_12
    add x27, x11, x0
    add x11, x12, x0
    add x12, x27, x0
    jal x31, show_swap
    jal x31, display_array
no_swap_12:
    lw x31, 0(sp)
    addi sp, sp, 4
    jalr x0, x31, 0

compare_23:
    blt x12, x13, no_swap_23
    add x27, x12, x0
    add x12, x13, x0
    add x13, x27, x0
    jal x31, show_swap
    jal x31, display_array
no_swap_23:
    lw x31, 0(sp)
    addi sp, sp, 4
    jalr x0, x31, 0

compare_34:
    blt x13, x14, no_swap_34
    add x27, x13, x0
    add x13, x14, x0
    add x14, x27, x0
    jal x31, show_swap
    jal x31, display_array
no_swap_34:
    lw x31, 0(sp)
    addi sp, sp, 4
    jalr x0, x31, 0

compare_45:
    blt x14, x15, no_swap_45
    add x27, x14, x0
    add x14, x15, x0
    add x15, x27, x0
    jal x31, show_swap
    jal x31, display_array
no_swap_45:
    lw x31, 0(sp)
    addi sp, sp, 4
    jalr x0, x31, 0

compare_56:
    blt x15, x16, no_swap_56
    add x27, x15, x0
    add x15, x16, x0
    add x16, x27, x0
    jal x31, show_swap
    jal x31, display_array
no_swap_56:
    lw x31, 0(sp)
    addi sp, sp, 4
    jalr x0, x31, 0

compare_67:
    blt x16, x17, no_swap_67
    add x27, x16, x0
    add x16, x17, x0
    add x17, x27, x0
    jal x31, show_swap
    jal x31, display_array
no_swap_67:
    lw x31, 0(sp)
    addi sp, sp, 4
    jalr x0, x31, 0

# 显示交换动画
show_swap:
    addi sp, sp, -8
    sw x31, 0(sp)
    sw x5, 4(sp)

    lui x26, 0x00A00
    lui x27, 0x00080
    or x26, x26, x27
    sw x26, 0(x21)

    lui x5, 0x5
    addi x5, x5, -480
swap_delay_on:
    jal x31, short_delay
    addi x5, x5, -1
    bne x5, x0, swap_delay_on

    lui x26, 0x00A00
    sw x26, 0(x21)

    lui x5, 0x5
    addi x5, x5, -480
swap_delay_off:
    jal x31, short_delay
    addi x5, x5, -1
    bne x5, x0, swap_delay_off

    lw x5, 4(sp)
    lw x31, 0(sp)
    addi sp, sp, 8
    jalr x0, x31, 0

# 延时函数
short_delay:
    addi x26, x0, 0x100
short_delay_loop:
    addi x26, x26, -1
    bne x26, x0, short_delay_loop
    jalr x0, x31, 0

medium_delay:
    addi sp, sp, -4
    sw x31, 0(sp)
    addi x5, x0, 100
medium_delay_loop:
    jal x31, short_delay
    addi x5, x5, -1
    bne x5, x0, medium_delay_loop
    lw x31, 0(sp)
    addi sp, sp, 4
    jalr x0, x31, 0

long_delay:
    addi sp, sp, -4
    sw x31, 0(sp)
    addi x5, x0, 500
long_delay_loop:
    jal x31, short_delay
    addi x5, x5, -1
    bne x5, x0, long_delay_loop
    lw x31, 0(sp)
    addi sp, sp, 4
    jalr x0, x31, 0
