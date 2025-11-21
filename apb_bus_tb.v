// Testbench for apb_bus
`timescale 1ns/1ps

module apb_bus_tb;
    reg clk;
    reg reset;
    reg [7:0] data_in;
    wire [7:0] data_out;

    apb_bus uut (
        .clk(clk),
        .reset(reset),
        .data_in(data_in),
        .data_out(data_out)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period (100MHz)
    end

    initial begin
        $dumpfile("apb_bus.vcd");
        $dumpvars(0, apb_bus_tb);
        reset = 1;
        data_in = 8'h00;
        #20 reset = 0;
        #10 data_in = 8'h05;
        #10 data_in = 8'h0A;
        #10 data_in = 8'hFF;
        #10 data_in = 8'h00;
        #10 reset = 1;
        #10 reset = 0;
        #10 data_in = 8'h42;
        #50 $finish;
    end

    initial begin
        $monitor("Time=%0t: data_in=%h, data_out=%h, reset=%b", $time, data_in, data_out, reset);
    end

endmodule
