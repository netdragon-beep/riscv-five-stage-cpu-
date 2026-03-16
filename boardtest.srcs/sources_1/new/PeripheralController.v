`timescale 1ns / 1ps

module PeripheralController(    //外设控制器模块
     input clk,
    input rst,

    input [31:0] addr,
    input [31:0] writeData,
    input we,
    input re,
    output reg [31:0] readData,

    input [23:0] switches,
    output reg [23:0] leds,
    output [6:0] seg_a2g,
    output [7:0] seg_an,
    input [31:0] pc_in
);

    localparam ADDR_LED     = 32'h10000000;  //LED寄存器
    localparam ADDR_SWITCH  = 32'h10000004;  //开关状态寄存器
    localparam ADDR_SEG_DATA = 32'h10000008; //数码管数据寄存器
    localparam ADDR_LED_EXT = 32'h1000000c;  //LED扩展寄存器

    reg [31:0] seg_data_reg; //数码管显示数据寄存器

    segment seg_inst(
        .data(seg_data_reg),
        .clk(clk),
        .a2g(seg_a2g),
        .an(seg_an)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            leds <= 24'h0;    //LED全部清0
            seg_data_reg <= 32'h0;//数码管清0
        end else if (we) begin
            case (addr)
                ADDR_LED: begin
                    leds <= writeData[23:0];//控制24位的LED
                    $display("[%0t] LED更新: 地址=0x%08x, 数据=0x%06x", $time, addr, writeData[23:0]);
                end
                ADDR_SEG_DATA: begin
                    seg_data_reg <= writeData; //更新数码管
                    $display("[%0t] 数码管更新: 地址=0x%08x, 数据=0x%08x", $time, addr, writeData);
                end
                ADDR_LED_EXT: begin
                    // LED扩展寄存器，也可以控制LED
                    leds <= writeData[23:0];
                    $display("[%0t] LED扩展更新: 地址=0x%08x, 数据=0x%06x", $time, addr, writeData[23:0]);
                end
                default: begin
                    $display("[%0t] 警告: 未支持的外设地址 0x%08x", $time, addr);
                end
            endcase
        end
    end

    always @(*) begin
        readData = 32'h0;
        if (re) begin //只有cpu发出读使能信号的时候才进行响应
            case (addr)
                ADDR_LED: begin
                    readData = {8'h0, leds}; //LED状态读取
                end
                ADDR_SWITCH: begin
                    readData = {8'h0, switches};//LED开关状态读取
                end
                ADDR_SEG_DATA: begin
                    readData = seg_data_reg;//数码管状态读取
                end
                ADDR_LED_EXT: begin
                    readData = {8'h0, leds}; //LED扩展寄存器读取
                end
                default: begin
                    readData = 32'h0;
                end
            endcase
        end
    end

endmodule