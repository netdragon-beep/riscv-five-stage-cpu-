`timescale 1ns / 1ps

module BusController(    //总线控制器
    input clk,
    input rst,

    input [31:0] cpu_addr,   //cpu发出的地址
    input [31:0] cpu_writeData,  //cpu发出的数据
    input cpu_memWe,
    input cpu_memRe,
    output reg [31:0] cpu_readData,//写入cpu的数据

    output reg ram_we,
    output reg [13:0] ram_addr,    //RAM的
    output reg [31:0] ram_writeData,
    input [31:0] ram_readData,

    output reg [13:0] rom_addr,
    input [31:0] rom_readData,   //rom的

    output reg [31:0] peripheral_addr,
    output reg [31:0] peripheral_writeData,
    output reg peripheral_we,                      //外设的
    output reg peripheral_re,
    input [31:0] peripheral_readData
);

    wire sel_ram, sel_peripheral;

    // 修改了一下架构ROM不再通过数据总线访问，只需要RAM和外设译码
    assign sel_ram = (cpu_addr >= 32'h00000000) && (cpu_addr < 32'h00004000);
    assign sel_peripheral = (cpu_addr >= 32'h10000000) && (cpu_addr < 32'h10001000);

    always @(*) begin
        ram_addr = cpu_addr[15:2];
        rom_addr = 14'h0;  // ROM不再通过总线控制器访问
        peripheral_addr = cpu_addr;
    end

    always @(*) begin
        ram_we = 1'b0;
        peripheral_we = 1'b0;
        ram_writeData = 32'h0;      //初始化所有写使能信号
        peripheral_writeData = 32'h0;

        if (cpu_memWe) begin
            if (sel_ram) begin
                ram_we = 1'b1;
                ram_writeData = cpu_writeData;         //Rom不能写
            end else if (sel_peripheral) begin
                peripheral_we = 1'b1;
                peripheral_writeData = cpu_writeData;
            end
        end
    end

    always @(*) begin
        peripheral_re = 1'b0;
        cpu_readData = 32'h0;               // 这段是读取

        // 数据总线只处理RAM和外设读取
        // ROM通过独立的指令总线访问
        if (cpu_memRe) begin
            if (sel_ram) begin
                cpu_readData = ram_readData;
            end else if (sel_peripheral) begin
                peripheral_re = 1'b1;
                cpu_readData = peripheral_readData;
            end
        end
    end

endmodule