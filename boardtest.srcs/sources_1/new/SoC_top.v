`timescale 1ns / 1ps

module SoC_top(
    input clk,
    input [23:0] indata,
    output [23:0] outdata,
    output [6:0] a2g,
    output [7:0] an
);

    wire clk_new;
    wire rst;

    // CPU 指令接口 
    wire [31:0] cpu_inst_addr;
    wire [31:0] cpu_inst_data;

    // CPU 数据接口
    wire [31:0] cpu_data_addr;
    wire [31:0] cpu_data_writeData;
    wire cpu_data_we;
    wire cpu_data_re;
    wire [31:0] cpu_data_readData;
    wire [31:0] cpu_pc;

    // RAM 接口
    wire ram_we;
    wire [13:0] ram_addr;
    wire [31:0] ram_writeData;
    wire [31:0] ram_readData;

    // ROM 接口 
    wire [11:0] rom_addr;
    wire [31:0] rom_readData;

    // 将 CPU 指令地址转换为 ROM 地址
    // PC 范围: 0x4000-0x8000, ROM 地址 = (PC - 0x4000) >> 2
    assign rom_addr = (cpu_inst_addr - 32'h00004000) >> 2;
    assign cpu_inst_data = rom_readData;

    // 外设接口
    wire [31:0] peripheral_addr;
    wire [31:0] peripheral_writeData;
    wire peripheral_we;
    wire peripheral_re;
    wire [31:0] peripheral_readData;

    // 添加上电复位逻辑
    reg [4:0] reset_counter = 5'b0;
    reg rst_signal = 1'b1;

    always @(posedge clk_new) begin
        if (reset_counter < 20) begin
            reset_counter <= reset_counter + 1'b1;
            rst_signal <= 1'b1;  // 复位有效
        end else begin
            rst_signal <= 1'b0;  // 复位释放
        end
    end

    assign rst = rst_signal;

    clkdiv cd(
        .clk(clk),
        .newclk(clk_new)
    );

    CPU_SoC cpu_inst(
        .clk(clk_new),
        .rst(rst),
        // 指令接口 
        .inst_addr(cpu_inst_addr),
        .inst_data(cpu_inst_data),
        // 数据接口
        .data_addr(cpu_data_addr),
        .data_writeData(cpu_data_writeData),
        .data_we(cpu_data_we),
        .data_re(cpu_data_re),
        .data_readData(cpu_data_readData),
        .pc_out(cpu_pc)
    );

    BusController bus_ctrl(
        .clk(clk_new),
        .rst(rst),
        // 数据端口连接
        .cpu_addr(cpu_data_addr),
        .cpu_writeData(cpu_data_writeData),
        .cpu_memWe(cpu_data_we),
        .cpu_memRe(cpu_data_re),
        .cpu_readData(cpu_data_readData),
        // RAM 连接
        .ram_we(ram_we),
        .ram_addr(ram_addr),
        .ram_writeData(ram_writeData),
        .ram_readData(ram_readData),
        // ROM
        .rom_addr(),  
        .rom_readData(32'h0),  
        // 外设连接
        .peripheral_addr(peripheral_addr),
        .peripheral_writeData(peripheral_writeData),
        .peripheral_we(peripheral_we),
        .peripheral_re(peripheral_re),
        .peripheral_readData(peripheral_readData)
    );

    RAM ram_inst(
        .clk(clk_new),
        .rst(rst),
        .memWe(ram_we),
        .addr(ram_addr[5:0]),  // 用低6位作为RAM地址cpu_addr[7:2]
        .writeData(ram_writeData),
        .readData(ram_readData)
    );

      ROM rom_inst (
        .addr(rom_addr),
        .data(rom_readData)
    );

    PeripheralController peripheral_ctrl(
        .clk(clk_new),
        .rst(rst),
        .addr(peripheral_addr),
        .writeData(peripheral_writeData),
        .we(peripheral_we),
        .re(peripheral_re),
        .readData(peripheral_readData),
        .switches(indata),
        .leds(outdata),
        .seg_a2g(a2g),
        .seg_an(an),
        .pc_in(cpu_pc)
    );

endmodule
