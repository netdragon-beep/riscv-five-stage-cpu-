`timescale 1ns / 1ps

module ID_EX(
    input clk,
    input rst,
    input flush,
    input stall,

    input [31:0] pc_in,      //整指令译码阶段和指令执行阶段的数据转化
    input [31:0] readData1_in,
    input [31:0] readData2_in,
    input [31:0] imm_in,
    input [4:0] rs1_in,
    input [4:0] rs2_in,
    input [4:0] rd_in,
    input [3:0] aluOp_in,
    input regWe_in,
    input memWe_in,
    input isFromMem_in,
    input isFromPC4_in,
    input bIsImm_in,
    input bIs20bImm_in,
    input [1:0] pcSource_in,
    input [2:0] funct3_in,       
    input isBranch_in,         

    output reg [31:0] pc_out,
    output reg [31:0] readData1_out,
    output reg [31:0] readData2_out,
    output reg [31:0] imm_out,
    output reg [4:0] rs1_out,
    output reg [4:0] rs2_out,
    output reg [4:0] rd_out,
    output reg [3:0] aluOp_out,
    output reg regWe_out,
    output reg memWe_out,
    output reg isFromMem_out,
    output reg isFromPC4_out,
    output reg bIsImm_out,
    output reg bIs20bImm_out,
    output reg [1:0] pcSource_out,
    output reg [2:0] funct3_out,     
    output reg isBranch_out          
);

always @(posedge clk) begin
    if (rst || flush) begin    //清0逻辑
        pc_out <= 32'h0;
        readData1_out <= 32'h0;
        readData2_out <= 32'h0;
        imm_out <= 32'h0;
        rs1_out <= 5'h0;
        rs2_out <= 5'h0;
        rd_out <= 5'h0;
        aluOp_out <= 4'h0;
        regWe_out <= 1'b0;
        memWe_out <= 1'b0;
        isFromMem_out <= 1'b0;
        isFromPC4_out <= 1'b0;
        bIsImm_out <= 1'b0;
        bIs20bImm_out <= 1'b0;
        pcSource_out <= 2'b00;
        funct3_out <= 3'b0;     
        isBranch_out <= 1'b0;    // 复位时清零
    end else if (!stall) begin  // 只有在没有暂停时才传递数据
        pc_out <= pc_in;
        readData1_out <= readData1_in;
        readData2_out <= readData2_in;    //数据转化的接口对应
        imm_out <= imm_in;
        rs1_out <= rs1_in;
        rs2_out <= rs2_in;
        rd_out <= rd_in;
        aluOp_out <= aluOp_in;
        regWe_out <= regWe_in;
        memWe_out <= memWe_in;
        isFromMem_out <= isFromMem_in;
        isFromPC4_out <= isFromPC4_in;
        bIsImm_out <= bIsImm_in;
        bIs20bImm_out <= bIs20bImm_in;
        pcSource_out <= pcSource_in;
        funct3_out <= funct3_in;     
        isBranch_out <= isBranch_in; 
    end
end

endmodule
