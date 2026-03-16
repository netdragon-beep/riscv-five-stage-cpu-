`timescale 1ns / 1ps

module RAM(
    input clk,
    input rst,
    input memWe,
    input [5:0] addr,
    input [31:0] writeData,
    output [31:0] readData
    );

    reg [31:0] memory [63:0];
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 64; i = i + 1) begin  //有复位信号的时候清空所有RAM里的内容
                memory[i] <= 32'b0;
            end
        end else if (memWe) begin
            memory[addr] <= writeData;   //有写入信号 就写入指定地址
        end
    end

    assign readData = memory[addr];

endmodule