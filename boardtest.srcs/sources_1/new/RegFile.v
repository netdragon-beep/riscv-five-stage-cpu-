`timescale 1ns / 1ps

module RegFile(
    input clk, //时钟信号
    input rst, //复位信号
    input regWe,  //写入信号
    input [4:0] readReg1,
    input [4:0] readReg2,
    input [4:0] writeReg,
    input [31:0] writeData,
    output [31:0] readData1,
    output [31:0] readData2
    );

    reg [31:0] regs [31:0];
    integer i;

    always @(posedge clk or posedge rst) begin //时钟上升的时候i+1
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 32'b0;
            end                                   //吧寄存器全部赋值为0
        end else if (regWe && writeReg != 5'b0) begin
            regs[writeReg] <= writeData;  // 不允许写入到0寄存器
        end
    end

   
    // 如果同一周期内有写入操作，且写入寄存器=读取寄存器，则直接转发writeData
    assign readData1 = (readReg1 == 5'b0) ? 32'b0 :
                       (regWe && writeReg == readReg1 && writeReg != 5'b0) ? writeData :
                       regs[readReg1];
    assign readData2 = (readReg2 == 5'b0) ? 32'b0 :
                       (regWe && writeReg == readReg2 && writeReg != 5'b0) ? writeData :
                       regs[readReg2];
                       //如果到了目标寄存器并且有写入信号 就进行写入

endmodule