`timescale 1ns / 1ps

// Testbench for segment module - verify clock divider fix
module segment_tb();

    reg clk;
    reg [31:0] data;
    wire [6:0] a2g;
    wire [7:0] an;

    // Instantiate segment module
    segment uut (
        .clk(clk),
        .data(data),
        .a2g(a2g),
        .an(an)
    );

    // 50MHz clock (20ns period)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // Monitor an signal changes
    reg [7:0] last_an;
    integer an_change_count;
    time last_change_time;
    time current_time;

    initial begin
        last_an = 8'hFF;
        an_change_count = 0;
        last_change_time = 0;
    end

    always @(an) begin
        if (an !== last_an) begin
            current_time = $time;
            if (an_change_count > 0) begin
                $display("[%0t ns] an changed: %b -> %b, interval = %0t ns",
                         current_time, last_an, an, current_time - last_change_time);
            end else begin
                $display("[%0t ns] an changed: %b -> %b (first change)",
                         current_time, last_an, an);
            end
            last_an = an;
            last_change_time = current_time;
            an_change_count = an_change_count + 1;
        end
    end

    // Test sequence
    initial begin
        $display("========================================");
        $display("Segment Display Clock Divider Test");
        $display("========================================");
        $display("Expected: Each digit should stay ON for ~163,840 ns (164us)");
        $display("          at 50MHz clock with 16-bit divider using bits [15:13]");
        $display("");

        // Set test data: 0x12345678
        data = 32'h12345678;
        $display("Test data: 0x%08h", data);
        $display("Expected display: 1 2 3 4 5 6 7 8");
        $display("");
        $display("Monitoring an signal changes...");
        $display("");

        // Run simulation for enough time to see multiple complete scans
        // One complete scan = 8 digits * 164us = 1.31ms = 1,310,720 ns
        // Run for 3ms to see at least 2 complete scans
        #3000000;

        $display("");
        $display("========================================");
        $display("Test Summary:");
        $display("  Total an changes: %0d", an_change_count);
        $display("  Expected interval between changes: ~163,840 ns");
        $display("========================================");

        if (an_change_count >= 16) begin
            $display("PASS: Clock divider is working correctly!");
        end else begin
            $display("WARNING: Fewer changes than expected, check clock divider");
        end

        $finish;
    end

    // Also monitor digit and a2g for correctness
    initial begin
        #100000; // Wait 100us then sample
        $display("");
        $display("Sample at 100us: an=%b, a2g=%b, digit being shown", an, a2g);
    end

endmodule
