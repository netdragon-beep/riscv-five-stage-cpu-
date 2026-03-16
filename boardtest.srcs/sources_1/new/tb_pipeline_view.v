`timescale 1ns / 1ps

module tb_pipeline_view;

    reg clk;
    reg [23:0] switches;
    wire [23:0] leds;
    wire [6:0] seg_a2g;
    wire [7:0] seg_an;

    SoC_top uut (
        .clk(clk),
        .indata(switches),
        .outdata(leds),
        .a2g(seg_a2g),
        .an(seg_an)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        switches = 24'h000000;
        #500;
        #5000;
        $finish;
    end

endmodule
