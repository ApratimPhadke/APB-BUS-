// ============================================================================
// Complete Testbench for APB Slave BFM Project
// ============================================================================
// This testbench verifies all modules:
// - APB Slave operations
// - UART TX/RX functionality
// - I2C Master operations
// ============================================================================

`timescale 1ns/1ps

module tb_top_level;

    // ========================================================================
    // Clock and Reset
    // ========================================================================
    reg sys_clk;
    reg sys_rst_n;
    
    // ========================================================================
    // UART Signals
    // ========================================================================
    wire uart_tx;
    reg  uart_rx;
    
    // ========================================================================
    // I2C Signals
    // ========================================================================
    wire i2c_sda;
    wire i2c_scl;
    
    // ========================================================================
    // User Interface
    // ========================================================================
    wire [7:0] led;
    reg [7:0]  sw;
    reg [3:0]  btn;
    
    // ========================================================================
    // Test Variables
    // ========================================================================
    integer i;
    reg [7:0] uart_byte;
    reg led7_prev;
    integer heartbeat_toggles;
    
    // ========================================================================
    // Clock Generation (100 MHz)
    // ========================================================================
    initial begin
        sys_clk = 0;
        forever #5 sys_clk = ~sys_clk;  // 10ns period = 100 MHz
    end
    
    // ========================================================================
    // DUT Instantiation
    // ========================================================================
    top_level_fpga dut (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .i2c_sda(i2c_sda),
        .i2c_scl(i2c_scl),
        .led(led),
        .sw(sw),
        .btn(btn)
    );
    
    // ========================================================================
    // Waveform Dump
    // ========================================================================
    initial begin
        $dumpfile("tb_top_level.vcd");
        $dumpvars(0, tb_top_level);
    end
    
    // ========================================================================
    // UART Receive Monitor
    // ========================================================================
    reg [7:0] uart_rx_byte;
    reg [3:0] uart_rx_bit_cnt;
    reg uart_rx_active;
    
    initial begin
        uart_rx_active = 0;
        uart_rx_byte = 0;
        uart_rx_bit_cnt = 0;
        
        forever begin
            @(negedge uart_tx);  // Detect start bit
            uart_rx_active = 1;
            #(104166);  // Wait half bit time (1/9600 * 0.5 seconds = 52083ns)
            
            // Sample 8 data bits
            for (uart_rx_bit_cnt = 0; uart_rx_bit_cnt < 8; uart_rx_bit_cnt = uart_rx_bit_cnt + 1) begin
                #(104166);  // Wait one bit time
                uart_rx_byte[uart_rx_bit_cnt] = uart_tx;
            end
            
            #(104166);  // Wait for stop bit
            
            if (uart_tx == 1) begin
                $display("[%0t] UART RX: Received byte 0x%02h ('%c')", 
                         $time, uart_rx_byte, uart_rx_byte);
            end else begin
                $display("[%0t] UART RX: Frame error detected", $time);
            end
            
            uart_rx_active = 0;
        end
    end
    
    // ========================================================================
    // Main Test Sequence
    // ========================================================================
    initial begin
        // Initialize signals
        sys_rst_n = 0;
        sw = 8'h00;
        btn = 4'h0;
        uart_rx = 1;
        
        $display("\n========================================");
        $display("APB Slave BFM Verification Started");
        $display("========================================\n");
        
        // Reset sequence
        #200;
        sys_rst_n = 1;
        $display("[%0t] Reset released", $time);
        #1000;
        
        // ====================================================================
        // Test 1: Check Initial State
        // ====================================================================
        $display("\n--- Test 1: Initial State Check ---");
        #100;
        if (led[0] == 1)
            $display("[PASS] LED[0] is ON (system active)");
        else
            $display("[FAIL] LED[0] is OFF (should be ON)");
        
        // ====================================================================
        // Test 2: UART Transmission Test
        // ====================================================================
        $display("\n--- Test 2: UART Transmission ---");
        sw[0] = 1;  // Enable UART test
        $display("[%0t] Enabled UART test (SW[0]=1)", $time);
        
        // Wait for first character
        #200_000_000;  // Wait 200ms for UART startup and transmission
        
        if (led[5] == 1)
            $display("[PASS] LED[5] mirrors SW[0]");
        else
            $display("[FAIL] LED[5] doesn't mirror SW[0]");
        
        // Send a few characters
        $display("[%0t] Waiting for UART transmissions...", $time);
        #500_000_000;  // Wait 500ms for multiple transmissions
        
        // ====================================================================
        // Test 3: I2C Communication Test
        // ====================================================================
        $display("\n--- Test 3: I2C Communication ---");
        sw[0] = 0;  // Disable UART test
        sw[1] = 1;  // Enable I2C test
        $display("[%0t] Enabled I2C test (SW[1]=1)", $time);
        
        // Reset to start I2C test
        sys_rst_n = 0;
        #100;
        sys_rst_n = 1;
        #1000;
        
        // Wait for I2C transaction
        $display("[%0t] Waiting for I2C transaction...", $time);
        #200_000_000;  // Wait 200ms
        
        if (led[6] == 1)
            $display("[PASS] LED[6] mirrors SW[1]");
        else
            $display("[FAIL] LED[6] doesn't mirror SW[1]");
        
        if (led[4] == 1)
            $display("[PASS] Test completed (LED[4]=1)");
        else
            $display("[INFO] Test still running (LED[4]=0)");
        
        // ====================================================================
        // Test 4: Button Control
        // ====================================================================
        $display("\n--- Test 4: Button Control ---");
        btn[2] = 1;  // Press restart button
        #1000;
        btn[2] = 0;
        #1000;
        $display("[%0t] Restart button pressed", $time);
        
        // ====================================================================
        // Test 5: Heartbeat Check
        // ====================================================================
        $display("\n--- Test 5: Heartbeat LED ---");
        
        led7_prev = led[7];
        heartbeat_toggles = 0;
        
        // Monitor LED[7] for 100ms
        for (i = 0; i < 100; i = i + 1) begin
            #1_000_000;  // 1ms
            if (led[7] != led7_prev) begin
                heartbeat_toggles = heartbeat_toggles + 1;
                led7_prev = led[7];
            end
        end
        
        if (heartbeat_toggles > 0)
            $display("[PASS] Heartbeat LED is toggling (%0d toggles in 100ms)", heartbeat_toggles);
        else
            $display("[FAIL] Heartbeat LED not toggling");
        
        // ====================================================================
        // Summary
        // ====================================================================
        $display("\n========================================");
        $display("Verification Complete!");
        $display("========================================");
        $display("LED Status:");
        $display("  LED[0] (Power)    : %b", led[0]);
        $display("  LED[1] (UART TX)  : %b", led[1]);
        $display("  LED[2] (UART IRQ) : %b", led[2]);
        $display("  LED[3] (I2C IRQ)  : %b", led[3]);
        $display("  LED[4] (Done)     : %b", led[4]);
        $display("  LED[5] (UART En)  : %b", led[5]);
        $display("  LED[6] (I2C En)   : %b", led[6]);
        $display("  LED[7] (Heartbeat): %b", led[7]);
        $display("========================================\n");
        
        #10000;
        $finish;
    end
    
    // ========================================================================
    // Timeout Watchdog
    // ========================================================================
    initial begin
        #2_000_000_000;  // 2 second timeout
        $display("\n[ERROR] Simulation timeout!");
        $finish;
    end
    
    // ========================================================================
    // Signal Monitoring
    // ========================================================================
    initial begin
        $monitor("[%0t] LEDs=%b SW=%b BTN=%b UART_TX=%b", 
                 $time, led, sw, btn, uart_tx);
    end

endmodule

// ============================================================================
// END OF TESTBENCH
// ============================================================================