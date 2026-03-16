`timescale 1ns / 1ps

module ROM(
    input [11:0] addr,    //PC 0x4000–0x7FFF
    output [31:0] data
    );

    // 32 位存储器 16KB 指令空间
    reg [31:0] memory [4095:0];

    initial begin
        $readmemh("E:/englishpath/boardtest/boardtest.srcs/sources_1/new/insData.txt", memory);
    end

    assign data = memory[addr];

endmodule
