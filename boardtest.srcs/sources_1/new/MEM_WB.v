`timescale 1ns / 1ps

module MEM_WB(  //访存和写回的数据传递模块
    input clk,
    input rst,

    input [31:0] pc_in,
    input [31:0] aluResult_in,
    input [31:0] memReadData_in,
    input [4:0] rd_in,
    input regWe_in,
    input isFromMem_in,
    input isFromPC4_in,

    output reg [31:0] pc_out,
    output reg [31:0] aluResult_out,
    output reg [31:0] memReadData_out,
    output reg [4:0] rd_out,
    output reg regWe_out,
    output reg isFromMem_out,
    output reg isFromPC4_out
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pc_out <= 32'h0;
        aluResult_out <= 32'h0;
        memReadData_out <= 32'h0;
        rd_out <= 5'h0;
        regWe_out <= 1'b0;
        isFromMem_out <= 1'b0;
        isFromPC4_out <= 1'b0;
    end else begin
        pc_out <= pc_in;
        aluResult_out <= aluResult_in;
        memReadData_out <= memReadData_in;
        rd_out <= rd_in;
        regWe_out <= regWe_in;
        isFromMem_out <= isFromMem_in;
        isFromPC4_out <= isFromPC4_in;
    end
end

endmodule