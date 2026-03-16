`timescale 1ns / 1ps

module IF_ID(    //取指令和译码转换模块
    input clk,
    input rst,
    input stall,
    input flush,
    input [31:0] pc_in,
    input [31:0] instruction_in,
    output reg [31:0] pc_out,
    output reg [31:0] instruction_out
);

always @(posedge clk) begin
    if (rst) begin        //如果有复位信号就清0
        pc_out <= 32'h0;
        instruction_out <= 32'h0;
    end else if (flush) begin  //如果有流水线气泡就清0输出
        pc_out <= 32'h0;
        instruction_out <= 32'h0;
    end else if (!stall) begin     //如果没有暂停就正常传递数据
        pc_out <= pc_in;
        instruction_out <= instruction_in;
    end
end  //否则暂停

endmodule