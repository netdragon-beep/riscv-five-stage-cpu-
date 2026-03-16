`timescale 1ns / 1ps

module EX_MEM(
    input clk,         //指令的执行阶段到存储器的访问阶段
    input rst,
    input flush,

    input [31:0] pc_in,
    input [31:0] aluResult_in,
    input [31:0] readData2_in,  //寄存器的第二个数据
    input [31:0] imm_in,        
    input [4:0] rd_in,
    input regWe_in,
    input memWe_in,
    input isFromMem_in,   //数据来源于存储器的使能信号
    input isFromPC4_in,   
    input [1:0] pcSource_in,

    output reg [31:0] pc_out,
    output reg [31:0] aluResult_out,
    output reg [31:0] readData2_out,
    output reg [31:0] imm_out, 
    output reg [4:0] rd_out,
    output reg regWe_out,
    output reg memWe_out,
    output reg isFromMem_out,
    output reg isFromPC4_out,
    output reg [1:0] pcSource_out
);

always @(posedge clk) begin
    if (rst || flush) begin
        pc_out <= 32'h0;
        aluResult_out <= 32'h0;
        readData2_out <= 32'h0;
        imm_out <= 32'h0;            
        rd_out <= 5'h0;              //初始化
        regWe_out <= 1'b0;
        memWe_out <= 1'b0;
        isFromMem_out <= 1'b0;
        isFromPC4_out <= 1'b0;
        pcSource_out <= 2'b00;
    end else begin
        pc_out <= pc_in;
        aluResult_out <= aluResult_in;
        readData2_out <= readData2_in;
        imm_out <= imm_in;          
        rd_out <= rd_in;
        regWe_out <= regWe_in;           //信号传递
        memWe_out <= memWe_in;
        isFromMem_out <= isFromMem_in;
        isFromPC4_out <= isFromPC4_in;
        pcSource_out <= pcSource_in;
    end
end

endmodule