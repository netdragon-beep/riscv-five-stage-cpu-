`timescale 1ns / 1ps

module ForwardingUnit(       //数据转发单元模块
    input [4:0] rs1_EX,   //取值阶段得到的第一个寄存器地址
    input [4:0] rs2_EX,   //第二个
    input [4:0] rd_MEM,   //mem阶段目标寄存器的地址
    input [4:0] rd_WB,   //wb阶段目标寄存器的地址
    input regWe_MEM,
    input regWe_WB,

    output reg [1:0] forwardA, //两个ALU的数据来源
    output reg [1:0] forwardB
);

always @(*) begin
    forwardA = 2'b00;
    forwardB = 2'b00;

    if (regWe_MEM && (rd_MEM != 5'b0) && (rd_MEM == rs1_EX)) begin  //如果MEM阶段的指令会产生EX阶段需要的数据，就进行转发
        forwardA = 2'b10;
    end else if (regWe_WB && (rd_WB != 5'b0) && (rd_WB == rs1_EX)) begin //如果WB阶段需要 就进行转发 
        forwardA = 2'b01;
    end                                                             //其他情况下就不进行转发

    if (regWe_MEM && (rd_MEM != 5'b0) && (rd_MEM == rs2_EX)) begin
        forwardB = 2'b10;
    end else if (regWe_WB && (rd_WB != 5'b0) && (rd_WB == rs2_EX)) begin   //对于另一个数据
        forwardB = 2'b01;
    end
end

endmodule