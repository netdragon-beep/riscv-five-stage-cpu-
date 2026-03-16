`timescale 1ns / 1ps

module ALU(
    input [31:0] dataA,//两个操作数
    input [31:0] dataB,
    input [3:0] opcode,//op操作符号信号
    output reg[31:0] result,
    output reg con //一位条件约束信号 用于后面比较大小等操作
);

always @(*) begin
    result = 32'h0;
    con = 1'b0;

    case (opcode)
        4'b0000: begin
            result = dataA + dataB;
            con = 1'b0;  //加法
        end

        4'b1000: begin
            result = dataA - dataB;
            con = 1'b0; //减法
        end

        4'b0111: begin
            result = dataA & dataB;
            con = 1'b0;   //与
        end

        4'b0110: begin
            result = dataA | dataB;
            con = 1'b0; //或
        end

        4'b0100: begin
            result = dataA ^ dataB;
            con = 1'b0;   //异或
        end

        4'b0001: begin
            result = dataA << dataB[4:0];
            con = 1'b0; //左移
        end

        4'b0101: begin
            result = dataA >> dataB[4:0];
            con = 1'b0;//右移
        end

        4'b1101: begin
            result = $signed(dataA) >>> dataB[4:0];
            con = 1'b0;//算右
        end

        4'b0010: begin
            result = ($signed(dataA) < $signed(dataB)) ? 32'h1 : 32'h0;
            con = ($signed(dataA) < $signed(dataB)) ? 1'b1 : 1'b0;
        end  //比大小


//分支比较
        4'b0011: begin
            result = (dataA < dataB) ? 32'h1 : 32'h0;
            con = (dataA < dataB) ? 1'b1 : 1'b0;
        end

        4'b1001: begin
            result = 32'h0;
            con = (dataA == dataB) ? 1'b1 : 1'b0;
        end

        4'b1010: begin
            result = 32'h0;
            con = (dataA != dataB) ? 1'b1 : 1'b0;
        end

        4'b1011: begin
            result = 32'h0;
            con = ($signed(dataA) >= $signed(dataB)) ? 1'b1 : 1'b0;
        end

        4'b1100: begin
            result = 32'h0;
            con = (dataA >= dataB) ? 1'b1 : 1'b0;
        end
         // JALR指令
        4'b1110: begin
            result = (dataA + dataB) & (~32'h1);
            con = 1'b0;
        end
        //LUI指令
        4'b1111: begin
            result = dataB;
            con = 1'b0;
        end

        default: begin
            result = 32'h0;
            con = 1'b0;
        end
    endcase
end

endmodule