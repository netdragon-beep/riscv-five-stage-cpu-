`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2023/05/24 17:32:23
// Design Name:
// Module Name: segment
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


module segment(
    input [31:0] data,
    input clk,
    output reg [6:0] a2g,  //7段数码管显示
    output reg [7:0] an    //8位数码管
    );                     //数码管模块

    // 降低扫描速度
    
    reg [15:0] clk_divider = 16'b0;
    wire [2:0] status;

    // 计数器的高3位为扫描状态
    assign status = clk_divider[15:13];

    reg[3:0] digit;

 
    always @(posedge clk)
        clk_divider <= clk_divider + 1'b1;

   always @(*)
    case(status)
        3'b000:begin digit=data[31:28]; an=8'b01111111;end  //数码管
        3'b001:begin digit=data[27:24]; an=8'b10111111;end
        3'b010:begin digit=data[23:20]; an=8'b11011111;end
        3'b011:begin digit=data[19:16]; an=8'b11101111;end
        3'b100:begin digit=data[15:12]; an=8'b11110111;end
        3'b101:begin digit=data[11:8];  an=8'b11111011;end
        3'b110:begin digit=data[7:4];   an=8'b11111101;end
        3'b111:begin digit=data[3:0];   an=8'b11111110;end
        default:begin digit=data[31:28]; an=8'b11111111;end
    endcase

   
   //
   // EGO1开发板 7段数码管编码 (共阳极, 0=亮, 1=灭)
   // 物理布局:     gggg       位序: a2g[6:0] = {g,f,e,d,c,b,a}
   //              b    f
   //               aaaa
   //              c    e
   //               dddd
   always @(*)
    case(digit)
    
        4'h0:a2g=7'b0000001;
   
        4'h1:a2g=7'b1001111;
   
        4'h2:a2g=7'b0010010;
       
        4'h3:a2g=7'b0000110;
   
        4'h4:a2g=7'b1001100;
   
        4'h5:a2g=7'b0100100;
      
        4'h6:a2g=7'b0100000;

        4'h7:a2g=7'b0001111;
 
        4'h8:a2g=7'b0000000;
 
        4'h9:a2g=7'b0000100;
        
        4'hA:a2g=7'b0001000;
  
        4'hB:a2g=7'b1100000;
   
        4'hC:a2g=7'b0110001;
 
        4'hD:a2g=7'b1000010;
 
        4'hE:a2g=7'b0110000;
       
        4'hF:a2g=7'b1111110;  // 只亮a作为"-"
        default:a2g=7'b1111111;  
    endcase
endmodule
