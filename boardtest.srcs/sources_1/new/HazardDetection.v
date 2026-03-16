`timescale 1ns / 1ps

module HazardDetection(
    input [4:0] rs1_ID,
    input [4:0] rs2_ID,   //冒险检测模块
    input [4:0] rd_EX,
    input isFromMem_EX,  //EX阶段的指令是否从存储器读取数据
    input [6:0] opcode_ID,  //增加一个操作码输入信号


    output reg stall,   //流水线停顿信号
    output reg flush_IFID,  //清空IF-ID流水线寄存器
    output reg flush_IDEX  //清空ID/EX流水线寄存器
);

always @(*) begin
    stall = 1'b0;
    flush_IFID = 1'b0;
    flush_IDEX = 1'b0;

    // 需要停顿流水线等待数据
    // 必须插入气泡否则会无限stall
    if (isFromMem_EX && (rd_EX != 5'b0) &&
        ((rd_EX == rs1_ID) || (rd_EX == rs2_ID))) begin
        stall = 1'b1;
        flush_IDEX = 1'b1;   
    end

 
end

endmodule