// ============================================================================
// TOP LEVEL MODULE for Artix-7 FPGA
// ============================================================================
// This is the main top module that connects to physical FPGA pins
// It instantiates the APB peripherals and provides test logic
// ============================================================================

module top_level_fpga (
    // ========================================================================
    // System Clock and Reset
    // ========================================================================
    input  wire        sys_clk,        // 100 MHz system clock from FPGA
    input  wire        sys_rst_n,      // Active-low reset button
    
    // ========================================================================
    // UART Interface (connects to USB-UART bridge)
    // ========================================================================
    input  wire        uart_rx,        // UART receive from PC
    output wire        uart_tx,        // UART transmit to PC
    
    // ========================================================================
    // I2C Interface (connects to I2C devices)
    // ========================================================================
    inout  wire        i2c_sda,        // I2C data line (bidirectional)
    inout  wire        i2c_scl,        // I2C clock line (bidirectional)
    
    // ========================================================================
    // User Interface
    // ========================================================================
    output wire [7:0]  led,            // 8 LEDs for status indication
    input  wire [7:0]  sw,             // 8 switches for control
    input  wire [3:0]  btn             // 4 push buttons for control
);

    // ========================================================================
    // Internal Signals
    // ========================================================================
    wire clk_100mhz;
    wire rst_n_sync;
    
    // APB Signals for UART
    reg [7:0]  apb_uart_addr;
    reg        apb_uart_sel;
    reg        apb_uart_enable;
    reg        apb_uart_write;
    reg [31:0] apb_uart_wdata;
    wire [31:0] apb_uart_rdata;
    wire       apb_uart_ready;
    wire       uart_irq;
    
    // APB Signals for I2C
    reg [7:0]  apb_i2c_addr;
    reg        apb_i2c_sel;
    reg        apb_i2c_enable;
    reg        apb_i2c_write;
    reg [31:0] apb_i2c_wdata;
    wire [31:0] apb_i2c_rdata;
    wire       apb_i2c_ready;
    wire       i2c_irq;
    
    // Test Controller FSM
    reg [3:0] test_state;
    reg [31:0] test_counter;
    reg [7:0] test_data;
    
    // ========================================================================
    // FSM States
    // ========================================================================
    localparam TEST_IDLE       = 4'd0;
    localparam TEST_UART_INIT  = 4'd1;
    localparam TEST_UART_TX    = 4'd2;
    localparam TEST_UART_WAIT  = 4'd3;
    localparam TEST_I2C_INIT   = 4'd4;
    localparam TEST_I2C_ADDR   = 4'd5;
    localparam TEST_I2C_DATA   = 4'd6;
    localparam TEST_I2C_START  = 4'd7;
    localparam TEST_I2C_WAIT   = 4'd8;
    localparam TEST_DONE       = 4'd9;
    
    // ========================================================================
    // Clock and Reset Management
    // ========================================================================
    
    // Direct clock assignment (100 MHz from FPGA)
    assign clk_100mhz = sys_clk;
    
    // Reset synchronizer (3-stage for metastability protection)
    reg [2:0] rst_sync;
    always @(posedge clk_100mhz or negedge sys_rst_n) begin
        if (!sys_rst_n)
            rst_sync <= 3'b000;
        else
            rst_sync <= {rst_sync[1:0], 1'b1};
    end
    assign rst_n_sync = rst_sync[2];
    
    // ========================================================================
    // APB-UART Module Instantiation
    // ========================================================================
    apb_uart #(
        .ADDR_WIDTH(8),
        .DATA_WIDTH(32),
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(9600)
    ) apb_uart_inst (
        .clk(clk_100mhz),
        .rst_n(rst_n_sync),
        .PADDR(apb_uart_addr),
        .PSEL(apb_uart_sel),
        .PENABLE(apb_uart_enable),
        .PWRITE(apb_uart_write),
        .PWDATA(apb_uart_wdata),
        .PRDATA(apb_uart_rdata),
        .PREADY(apb_uart_ready),
        .PSLVERR(),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .irq(uart_irq)
    );
    
    // ========================================================================
    // APB-I2C Module Instantiation
    // ========================================================================
    apb_i2c #(
        .ADDR_WIDTH(8),
        .DATA_WIDTH(32),
        .CLK_FREQ(100_000_000),
        .I2C_FREQ(100_000)
    ) apb_i2c_inst (
        .clk(clk_100mhz),
        .rst_n(rst_n_sync),
        .PADDR(apb_i2c_addr),
        .PSEL(apb_i2c_sel),
        .PENABLE(apb_i2c_enable),
        .PWRITE(apb_i2c_write),
        .PWDATA(apb_i2c_wdata),
        .PRDATA(apb_i2c_rdata),
        .PREADY(apb_i2c_ready),
        .PSLVERR(),
        .sda(i2c_sda),
        .scl(i2c_scl),
        .irq(i2c_irq)
    );
    
    // ========================================================================
    // Test Controller FSM
    // ========================================================================
    always @(posedge clk_100mhz or negedge rst_n_sync) begin
        if (!rst_n_sync) begin
            test_state <= TEST_IDLE;
            test_counter <= 0;
            test_data <= 8'h41;  // ASCII 'A'
            apb_uart_sel <= 0;
            apb_uart_enable <= 0;
            apb_uart_write <= 0;
            apb_uart_wdata <= 0;
            apb_uart_addr <= 0;
            apb_i2c_sel <= 0;
            apb_i2c_enable <= 0;
            apb_i2c_write <= 0;
            apb_i2c_wdata <= 0;
            apb_i2c_addr <= 0;
        end else begin
            // Default: Clear APB signals
            apb_uart_sel <= 0;
            apb_uart_enable <= 0;
            apb_i2c_sel <= 0;
            apb_i2c_enable <= 0;
            
            case (test_state)
                // ============================================================
                // IDLE: Wait for user to enable test
                // ============================================================
                TEST_IDLE: begin
                    test_counter <= test_counter + 1;
                    // Wait 1 second after reset
                    if (test_counter >= 100_000_000) begin
                        test_counter <= 0;
                        if (sw[0])  // Switch 0 enables UART test
                            test_state <= TEST_UART_INIT;
                        else if (sw[1])  // Switch 1 enables I2C test
                            test_state <= TEST_I2C_INIT;
                    end
                end
                
                // ============================================================
                // UART TEST SEQUENCE
                // ============================================================
                TEST_UART_INIT: begin
                    test_state <= TEST_UART_TX;
                    test_data <= 8'h41;  // Start with 'A'
                end
                
                TEST_UART_TX: begin
                    // APB Write to UART TX register
                    apb_uart_sel <= 1;
                    apb_uart_enable <= 1;
                    apb_uart_write <= 1;
                    apb_uart_addr <= 8'h08;  // TX_DATA register
                    apb_uart_wdata <= {24'h0, test_data};
                    
                    if (apb_uart_ready) begin
                        test_state <= TEST_UART_WAIT;
                        test_counter <= 0;
                    end
                end
                
                TEST_UART_WAIT: begin
                    test_counter <= test_counter + 1;
                    // Wait for transmission (approx 1.1ms at 9600 baud)
                    if (test_counter >= 110_000) begin
                        test_counter <= 0;
                        test_data <= test_data + 1;  // Next ASCII character
                        
                        // Loop back or finish
                        if (test_data >= 8'h5A) begin  // After 'Z'
                            test_data <= 8'h41;  // Reset to 'A'
                        end
                        
                        if (btn[0])  // Button 0 to send next character
                            test_state <= TEST_UART_TX;
                        else if (btn[1])  // Button 1 to stop
                            test_state <= TEST_DONE;
                        else
                            test_state <= TEST_UART_TX;  // Auto-send
                    end
                end
                
                // ============================================================
                // I2C TEST SEQUENCE
                // ============================================================
                TEST_I2C_INIT: begin
                    test_state <= TEST_I2C_ADDR;
                    test_data <= 8'hAA;  // Test data
                end
                
                TEST_I2C_ADDR: begin
                    // Write I2C slave address
                    apb_i2c_sel <= 1;
                    apb_i2c_enable <= 1;
                    apb_i2c_write <= 1;
                    apb_i2c_addr <= 8'h08;  // SLAVE_ADDR register
                    apb_i2c_wdata <= {25'h0, 7'h50};  // Example: 0x50 (EEPROM)
                    
                    if (apb_i2c_ready) begin
                        test_state <= TEST_I2C_DATA;
                    end
                end
                
                TEST_I2C_DATA: begin
                    // Write data to be transmitted
                    apb_i2c_sel <= 1;
                    apb_i2c_enable <= 1;
                    apb_i2c_write <= 1;
                    apb_i2c_addr <= 8'h0C;  // TX_DATA register
                    apb_i2c_wdata <= {24'h0, test_data};
                    
                    if (apb_i2c_ready) begin
                        test_state <= TEST_I2C_START;
                    end
                end
                
                TEST_I2C_START: begin
                    // Start I2C write transaction
                    apb_i2c_sel <= 1;
                    apb_i2c_enable <= 1;
                    apb_i2c_write <= 1;
                    apb_i2c_addr <= 8'h00;  // CONTROL register
                    apb_i2c_wdata <= 32'h00000009;  // start=1, write=1
                    
                    if (apb_i2c_ready) begin
                        test_state <= TEST_I2C_WAIT;
                        test_counter <= 0;
                    end
                end
                
                TEST_I2C_WAIT: begin
                    test_counter <= test_counter + 1;
                    // Wait for I2C transaction (max 1ms)
                    if (test_counter >= 100_000 || i2c_irq) begin
                        test_state <= TEST_DONE;
                    end
                end
                
                // ============================================================
                // DONE: Test complete, wait for restart
                // ============================================================
                TEST_DONE: begin
                    if (btn[2])  // Button 2 to restart
                        test_state <= TEST_IDLE;
                end
                
                default: test_state <= TEST_IDLE;
            endcase
        end
    end
    
    // ========================================================================
    // LED Status Indicators
    // ========================================================================
    assign led[0] = rst_n_sync;                    // Power/Reset indicator
    assign led[1] = uart_tx;                       // UART TX activity
    assign led[2] = uart_irq;                      // UART interrupt
    assign led[3] = i2c_irq;                       // I2C interrupt
    assign led[4] = (test_state == TEST_DONE);     // Test complete
    assign led[5] = sw[0];                         // UART test enabled
    assign led[6] = sw[1];                         // I2C test enabled
    assign led[7] = test_counter[23];              // Heartbeat (~12 Hz)

endmodule

// ============================================================================
// END OF TOP MODULE
// ============================================================================