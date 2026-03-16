`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/05/24 17:30:39
// Design Name: 
// Module Name: clkdiv
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module clkdiv(
    input clk,                 //这个是一个时钟分频器
    output newclk
    );
    reg[4:0] data=5'b0;
    always @(posedge clk)
         data<=data+1'b1;

    assign newclk=data[0];  // 50MHz分屏
endmodule
