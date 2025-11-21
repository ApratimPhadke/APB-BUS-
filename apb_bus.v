// ============================================================================
// Complete APB Slave BFM with UART and I2C - Single File Implementation
// ============================================================================
// This file contains all modules:
// 1. APB Slave Interface
// 2. UART Transmitter
// 3. UART Receiver  
// 4. UART-APB Bridge
// 5. I2C Master
// 6. I2C-APB Bridge
// ============================================================================

// ============================================================================
// MODULE 1: APB SLAVE INTERFACE
// ============================================================================
module apb_slave #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
) (
    input  wire                      PCLK,
    input  wire                      PRESETn,
    input  wire [    ADDR_WIDTH-1:0] PADDR,
    input  wire                      PSEL,
    input  wire                      PENABLE,
    input  wire                      PWRITE,
    input  wire [    DATA_WIDTH-1:0] PWDATA,
    input  wire [(DATA_WIDTH/8)-1:0] PSTRB,
    output reg  [    DATA_WIDTH-1:0] PRDATA,
    output reg                       PREADY,
    output reg                       PSLVERR
);

  reg [DATA_WIDTH-1:0] mem[0:255];

  localparam IDLE = 2'b00;
  localparam SETUP = 2'b01;
  localparam ACCESS = 2'b10;

  reg [1:0] state, next_state;
  integer i;

  initial begin
    for (i = 0; i < 256; i = i + 1) begin
      mem[i] = 32'h0;
    end
  end

  always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) state <= IDLE;
    else state <= next_state;
  end

  always @(*) begin
    case (state)
      IDLE: begin
        if (PSEL && !PENABLE) next_state = SETUP;
        else next_state = IDLE;
      end
      SETUP: begin
        next_state = ACCESS;
      end
      ACCESS: begin
        if (PREADY) begin
          if (PSEL) next_state = SETUP;
          else next_state = IDLE;
        end else next_state = ACCESS;
      end
      default: next_state = IDLE;
    endcase
  end

  always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      for (i = 0; i < 256; i = i + 1) begin
        mem[i] <= 32'h0;
      end
    end else if (state == ACCESS && PWRITE && PSEL && PENABLE) begin
      if (PSTRB[0]) mem[PADDR][7:0] <= PWDATA[7:0];
      if (PSTRB[1]) mem[PADDR][15:8] <= PWDATA[15:8];
      if (PSTRB[2]) mem[PADDR][23:16] <= PWDATA[23:16];
      if (PSTRB[3]) mem[PADDR][31:24] <= PWDATA[31:24];
    end
  end

  always @(*) begin
    if (state == ACCESS && !PWRITE && PSEL) PRDATA = mem[PADDR];
    else PRDATA = 32'h0;
  end

  always @(*) begin
    if (state == ACCESS) PREADY = 1'b1;
    else PREADY = 1'b0;
  end

  always @(*) begin
    PSLVERR = 1'b0;
  end

endmodule


// ============================================================================
// MODULE 2: UART TRANSMITTER
// ============================================================================
module uart_tx #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 9600,
    parameter DATA_BITS = 8,
    parameter PARITY_EN = 0,
    parameter STOP_BITS = 1
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] tx_data,
    input  wire       tx_start,
    output reg        tx,
    output reg        tx_busy,
    output reg        tx_done
);

  localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;

  localparam IDLE = 3'b000;
  localparam START_BIT = 3'b001;
  localparam DATA_BITS_TX = 3'b010;
  localparam PARITY_BIT = 3'b011;
  localparam STOP_BIT = 3'b100;

  reg [2:0] state, next_state;
  reg [15:0] baud_counter;
  reg [2:0] bit_counter;
  reg [7:0] tx_shift_reg;
  reg parity_bit;
  reg baud_tick;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      baud_counter <= 0;
      baud_tick <= 0;
    end else begin
      if (baud_counter >= BAUD_DIV - 1) begin
        baud_counter <= 0;
        baud_tick <= 1;
      end else begin
        baud_counter <= baud_counter + 1;
        baud_tick <= 0;
      end
    end
  end

  always @(*) begin
    if (PARITY_EN == 1) parity_bit = ^tx_shift_reg;
    else if (PARITY_EN == 2) parity_bit = ~(^tx_shift_reg);
    else parity_bit = 0;
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx <= 1'b1;
      tx_busy <= 0;
      tx_done <= 0;
      bit_counter <= 0;
      tx_shift_reg <= 0;
      next_state <= IDLE;
    end else begin
      tx_done <= 0;

      case (state)
        IDLE: begin
          tx <= 1'b1;
          tx_busy <= 0;
          bit_counter <= 0;

          if (tx_start) begin
            tx_shift_reg <= tx_data;
            tx_busy <= 1;
            next_state <= START_BIT;
          end else next_state <= IDLE;
        end

        START_BIT: begin
          tx <= 1'b0;
          if (baud_tick) begin
            next_state  <= DATA_BITS_TX;
            bit_counter <= 0;
          end else next_state <= START_BIT;
        end

        DATA_BITS_TX: begin
          tx <= tx_shift_reg[0];
          if (baud_tick) begin
            tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};
            if (bit_counter >= DATA_BITS - 1) begin
              bit_counter <= 0;
              if (PARITY_EN > 0) next_state <= PARITY_BIT;
              else next_state <= STOP_BIT;
            end else begin
              bit_counter <= bit_counter + 1;
              next_state  <= DATA_BITS_TX;
            end
          end else next_state <= DATA_BITS_TX;
        end

        PARITY_BIT: begin
          tx <= parity_bit;
          if (baud_tick) next_state <= STOP_BIT;
          else next_state <= PARITY_BIT;
        end

        STOP_BIT: begin
          tx <= 1'b1;
          if (baud_tick) begin
            if (bit_counter >= STOP_BITS - 1) begin
              tx_done <= 1;
              next_state <= IDLE;
            end else begin
              bit_counter <= bit_counter + 1;
              next_state  <= STOP_BIT;
            end
          end else next_state <= STOP_BIT;
        end

        default: next_state <= IDLE;
      endcase
    end
  end

endmodule


// ============================================================================
// MODULE 3: UART RECEIVER
// ============================================================================
module uart_rx #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 9600,
    parameter DATA_BITS = 8,
    parameter PARITY_EN = 0,
    parameter STOP_BITS = 1
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,
    output reg  [7:0] rx_data,
    output reg        rx_valid,
    output reg        rx_error,
    output reg        frame_error,
    output reg        parity_error
);

  localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;
  localparam HALF_BAUD = BAUD_DIV / 2;

  localparam IDLE = 3'b000;
  localparam START_BIT = 3'b001;
  localparam DATA_BITS_RX = 3'b010;
  localparam PARITY_BIT = 3'b011;
  localparam STOP_BIT = 3'b100;

  reg [2:0] state, next_state;
  reg [15:0] baud_counter;
  reg [ 2:0] bit_counter;
  reg [ 7:0] rx_shift_reg;
  reg rx_sync1, rx_sync2;
  reg sample_tick;
  reg parity_calc;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_sync1 <= 1'b1;
      rx_sync2 <= 1'b1;
    end else begin
      rx_sync1 <= rx;
      rx_sync2 <= rx_sync1;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      baud_counter <= 0;
      sample_tick  <= 0;
    end else begin
      sample_tick <= 0;
      if (state == IDLE) begin
        baud_counter <= 0;
      end else begin
        if (baud_counter >= BAUD_DIV - 1) begin
          baud_counter <= 0;
          sample_tick  <= 1;
        end else begin
          baud_counter <= baud_counter + 1;
        end
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_data <= 0;
      rx_valid <= 0;
      rx_error <= 0;
      frame_error <= 0;
      parity_error <= 0;
      bit_counter <= 0;
      rx_shift_reg <= 0;
      next_state <= IDLE;
      parity_calc <= 0;
    end else begin
      rx_valid <= 0;
      rx_error <= 0;

      case (state)
        IDLE: begin
          bit_counter  <= 0;
          frame_error  <= 0;
          parity_error <= 0;

          if (rx_sync2 == 0) begin
            next_state <= START_BIT;
          end else next_state <= IDLE;
        end

        START_BIT: begin
          if (baud_counter == HALF_BAUD) begin
            if (rx_sync2 == 0) begin
              next_state <= DATA_BITS_RX;
            end else begin
              next_state  <= IDLE;
              frame_error <= 1;
            end
          end else next_state <= START_BIT;
        end

        DATA_BITS_RX: begin
          if (sample_tick) begin
            rx_shift_reg <= {rx_sync2, rx_shift_reg[7:1]};

            if (bit_counter >= DATA_BITS - 1) begin
              bit_counter <= 0;
              if (PARITY_EN > 0) next_state <= PARITY_BIT;
              else next_state <= STOP_BIT;
            end else begin
              bit_counter <= bit_counter + 1;
              next_state  <= DATA_BITS_RX;
            end
          end else next_state <= DATA_BITS_RX;
        end

        PARITY_BIT: begin
          if (sample_tick) begin
            if (PARITY_EN == 1) parity_calc = ^rx_shift_reg;
            else parity_calc = ~(^rx_shift_reg);

            if (rx_sync2 != parity_calc) parity_error <= 1;

            next_state <= STOP_BIT;
          end else next_state <= PARITY_BIT;
        end

        STOP_BIT: begin
          if (sample_tick) begin
            if (rx_sync2 == 1) begin
              rx_data  <= rx_shift_reg;
              rx_valid <= 1;

              if (bit_counter >= STOP_BITS - 1) next_state <= IDLE;
              else begin
                bit_counter <= bit_counter + 1;
                next_state  <= STOP_BIT;
              end
            end else begin
              frame_error <= 1;
              rx_error <= 1;
              next_state <= IDLE;
            end
          end else next_state <= STOP_BIT;
        end

        default: next_state <= IDLE;
      endcase
    end
  end

endmodule


// ============================================================================
// MODULE 4: APB-UART BRIDGE
// ============================================================================
module apb_uart #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32,
    parameter CLK_FREQ   = 100_000_000,
    parameter BAUD_RATE  = 9600
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire [ADDR_WIDTH-1:0] PADDR,
    input  wire                  PSEL,
    input  wire                  PENABLE,
    input  wire                  PWRITE,
    input  wire [DATA_WIDTH-1:0] PWDATA,
    output wire [DATA_WIDTH-1:0] PRDATA,
    output wire                  PREADY,
    output wire                  PSLVERR,
    input  wire                  uart_rx,
    output wire                  uart_tx,
    output reg                   irq
);

  localparam REG_CONTROL = 8'h00;
  localparam REG_STATUS = 8'h04;
  localparam REG_TX_DATA = 8'h08;
  localparam REG_RX_DATA = 8'h0C;
  localparam REG_BAUD_DIV = 8'h10;

  reg  [          31:0] control_reg;
  reg  [          31:0] status_reg;
  reg  [           7:0] tx_data_reg;
  reg  [           7:0] rx_data_reg;

  wire [           7:0] uart_rx_data;
  wire                  uart_rx_valid;
  wire                  uart_rx_error;
  wire                  uart_tx_busy;
  wire                  uart_tx_done;
  reg                   uart_tx_start;

  reg  [DATA_WIDTH-1:0] prdata_int;
  reg                   pready_int;

  uart_tx #(
      .CLK_FREQ (CLK_FREQ),
      .BAUD_RATE(BAUD_RATE),
      .DATA_BITS(8),
      .PARITY_EN(0),
      .STOP_BITS(1)
  ) uart_tx_inst (
      .clk(clk),
      .rst_n(rst_n),
      .tx_data(tx_data_reg),
      .tx_start(uart_tx_start),
      .tx(uart_tx),
      .tx_busy(uart_tx_busy),
      .tx_done(uart_tx_done)
  );

  uart_rx #(
      .CLK_FREQ (CLK_FREQ),
      .BAUD_RATE(BAUD_RATE),
      .DATA_BITS(8),
      .PARITY_EN(0),
      .STOP_BITS(1)
  ) uart_rx_inst (
      .clk(clk),
      .rst_n(rst_n),
      .rx(uart_rx),
      .rx_data(uart_rx_data),
      .rx_valid(uart_rx_valid),
      .rx_error(uart_rx_error),
      .frame_error(),
      .parity_error()
  );

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      control_reg   <= 32'h0;
      tx_data_reg   <= 8'h0;
      uart_tx_start <= 0;
    end else begin
      uart_tx_start <= 0;

      if (PSEL && PENABLE && PWRITE) begin
        case (PADDR)
          REG_CONTROL: control_reg <= PWDATA;
          REG_TX_DATA: begin
            tx_data_reg <= PWDATA[7:0];
            if (!uart_tx_busy) uart_tx_start <= 1;
          end
        endcase
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_data_reg <= 8'h0;
    end else if (uart_rx_valid) begin
      rx_data_reg <= uart_rx_data;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      status_reg <= 32'h0;
    end else begin
      status_reg[0] <= uart_tx_busy;
      status_reg[1] <= uart_tx_done;
      status_reg[2] <= uart_rx_valid;
      status_reg[3] <= uart_rx_error;
    end
  end

  always @(*) begin
    prdata_int = 32'h0;
    if (PSEL && !PWRITE) begin
      case (PADDR)
        REG_CONTROL: prdata_int = control_reg;
        REG_STATUS:  prdata_int = status_reg;
        REG_RX_DATA: prdata_int = {24'h0, rx_data_reg};
        REG_TX_DATA: prdata_int = {24'h0, tx_data_reg};
        default:     prdata_int = 32'h0;
      endcase
    end
  end

  assign PRDATA = prdata_int;

  always @(*) begin
    pready_int = PSEL && PENABLE;
  end

  assign PREADY  = pready_int;
  assign PSLVERR = 1'b0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) irq <= 0;
    else irq <= uart_rx_valid | uart_tx_done | uart_rx_error;
  end

endmodule


// ============================================================================
// MODULE 5: I2C MASTER
// ============================================================================
module i2c_master #(
    parameter CLK_FREQ = 100_000_000,
    parameter I2C_FREQ = 100_000
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire       stop,
    input  wire       read,
    input  wire       write,
    input  wire [6:0] slave_addr,
    input  wire [7:0] tx_data,
    output reg  [7:0] rx_data,
    output reg        busy,
    output reg        ack_error,
    output reg        done,
    inout  wire       sda,
    inout  wire       scl
);

  localparam I2C_DIV = CLK_FREQ / (4 * I2C_FREQ);

  localparam IDLE = 4'h0;
  localparam START_COND = 4'h1;
  localparam ADDR_SEND = 4'h2;
  localparam ACK_CHECK = 4'h3;
  localparam DATA_WR = 4'h4;
  localparam DATA_RD = 4'h5;
  localparam SEND_ACK = 4'h6;
  localparam STOP_COND = 4'h7;

  reg [3:0] state, next_state;
  reg [15:0] clk_counter;
  reg [ 3:0] bit_counter;
  reg [ 7:0] shift_reg;
  reg scl_out, sda_out;
  reg scl_enable, sda_enable;
  reg i2c_clk_tick;
  reg [1:0] i2c_phase;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      clk_counter <= 0;
      i2c_clk_tick <= 0;
      i2c_phase <= 0;
    end else begin
      i2c_clk_tick <= 0;
      if (clk_counter >= I2C_DIV - 1) begin
        clk_counter <= 0;
        i2c_clk_tick <= 1;
        i2c_phase <= i2c_phase + 1;
      end else begin
        clk_counter <= clk_counter + 1;
      end
    end
  end

  assign scl = scl_enable ? scl_out : 1'bz;
  assign sda = sda_enable ? sda_out : 1'bz;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      scl_out <= 1;
      sda_out <= 1;
      scl_enable <= 1;
      sda_enable <= 1;
      busy <= 0;
      done <= 0;
      ack_error <= 0;
      bit_counter <= 0;
      shift_reg <= 0;
      rx_data <= 0;
      next_state <= IDLE;
    end else begin
      done <= 0;

      case (state)
        IDLE: begin
          scl_out <= 1;
          sda_out <= 1;
          scl_enable <= 0;
          sda_enable <= 0;
          busy <= 0;
          ack_error <= 0;

          if (start) begin
            busy <= 1;
            next_state <= START_COND;
          end else next_state <= IDLE;
        end

        START_COND: begin
          scl_enable <= 1;
          sda_enable <= 1;

          if (i2c_clk_tick) begin
            case (i2c_phase)
              2'b00: begin
                sda_out <= 1;
                scl_out <= 1;
              end
              2'b01: begin
                sda_out <= 0;
                scl_out <= 1;
              end
              2'b10: begin
                sda_out <= 0;
                scl_out <= 0;
              end
              2'b11: begin
                bit_counter <= 0;
                shift_reg   <= {slave_addr, write ? 1'b0 : 1'b1};
                next_state  <= ADDR_SEND;
              end
            endcase
          end else next_state <= START_COND;
        end

        ADDR_SEND: begin
          if (i2c_clk_tick) begin
            case (i2c_phase)
              2'b00: begin
                sda_out <= shift_reg[7];
                scl_out <= 0;
              end
              2'b01: scl_out <= 1;
              2'b10: scl_out <= 1;
              2'b11: begin
                scl_out   <= 0;
                shift_reg <= {shift_reg[6:0], 1'b0};

                if (bit_counter >= 7) begin
                  bit_counter <= 0;
                  next_state  <= ACK_CHECK;
                end else begin
                  bit_counter <= bit_counter + 1;
                  next_state  <= ADDR_SEND;
                end
              end
            endcase
          end else next_state <= ADDR_SEND;
        end

        ACK_CHECK: begin
          if (i2c_clk_tick) begin
            case (i2c_phase)
              2'b00: begin
                sda_enable <= 0;
                scl_out <= 0;
              end
              2'b01: scl_out <= 1;
              2'b10: begin
                if (sda == 1) begin
                  ack_error <= 1;
                end
              end
              2'b11: begin
                scl_out <= 0;
                sda_enable <= 1;

                if (ack_error) next_state <= STOP_COND;
                else if (write) next_state <= DATA_WR;
                else if (read) next_state <= DATA_RD;
                else next_state <= STOP_COND;
              end
            endcase
          end else next_state <= ACK_CHECK;
        end

        DATA_WR: begin
          if (bit_counter == 0) shift_reg <= tx_data;

          if (i2c_clk_tick) begin
            case (i2c_phase)
              2'b00: begin
                sda_out <= shift_reg[7];
                scl_out <= 0;
              end
              2'b01: scl_out <= 1;
              2'b10: scl_out <= 1;
              2'b11: begin
                scl_out   <= 0;
                shift_reg <= {shift_reg[6:0], 1'b0};

                if (bit_counter >= 7) begin
                  bit_counter <= 0;
                  done <= 1;
                  next_state <= STOP_COND;
                end else begin
                  bit_counter <= bit_counter + 1;
                  next_state  <= DATA_WR;
                end
              end
            endcase
          end else next_state <= DATA_WR;
        end

        DATA_RD: begin
          if (i2c_clk_tick) begin
            case (i2c_phase)
              2'b00: begin
                sda_enable <= 0;
                scl_out <= 0;
              end
              2'b01: scl_out <= 1;
              2'b10: begin
                shift_reg <= {shift_reg[6:0], sda};
              end
              2'b11: begin
                scl_out <= 0;

                if (bit_counter >= 7) begin
                  rx_data <= shift_reg;
                  bit_counter <= 0;
                  next_state <= SEND_ACK;
                end else begin
                  bit_counter <= bit_counter + 1;
                  next_state  <= DATA_RD;
                end
              end
            endcase
          end else next_state <= DATA_RD;
        end

        SEND_ACK: begin
          if (i2c_clk_tick) begin
            case (i2c_phase)
              2'b00: begin
                sda_enable <= 1;
                sda_out <= 0;
                scl_out <= 0;
              end
              2'b01: scl_out <= 1;
              2'b10: scl_out <= 1;
              2'b11: begin
                scl_out <= 0;
                done <= 1;
                next_state <= STOP_COND;
              end
            endcase
          end else next_state <= SEND_ACK;
        end

        STOP_COND: begin
          if (i2c_clk_tick) begin
            case (i2c_phase)
              2'b00: begin
                sda_out <= 0;
                scl_out <= 0;
              end
              2'b01: begin
                sda_out <= 0;
                scl_out <= 1;
              end
              2'b10: begin
                sda_out <= 1;
                scl_out <= 1;
              end
              2'b11: begin
                next_state <= IDLE;
              end
            endcase
          end else next_state <= STOP_COND;
        end

        default: next_state <= IDLE;
      endcase
    end
  end

endmodule


// ============================================================================
// MODULE 6: APB-I2C BRIDGE
// ============================================================================
module apb_i2c #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32,
    parameter CLK_FREQ   = 100_000_000,
    parameter I2C_FREQ   = 100_000
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire [ADDR_WIDTH-1:0] PADDR,
    input  wire                  PSEL,
    input  wire                  PENABLE,
    input  wire                  PWRITE,
    input  wire [DATA_WIDTH-1:0] PWDATA,
    output wire [DATA_WIDTH-1:0] PRDATA,
    output wire                  PREADY,
    output wire                  PSLVERR,
    inout  wire                  sda,
    inout  wire                  scl,
    output reg                   irq
);

  localparam REG_CONTROL = 8'h00;
  localparam REG_STATUS = 8'h04;
  localparam REG_SLAVE_ADDR = 8'h08;
  localparam REG_TX_DATA = 8'h0C;
  localparam REG_RX_DATA = 8'h10;

  reg  [          31:0] control_reg;
  reg  [          31:0] status_reg;
  reg  [           6:0] slave_addr_reg;
  reg  [           7:0] tx_data_reg;
  reg  [           7:0] rx_data_reg;

  wire                  i2c_busy;
  wire                  i2c_ack_error;
  wire                  i2c_done;
  wire [           7:0] i2c_rx_data;
  reg                   i2c_start;
  reg                   i2c_stop;
  reg                   i2c_read;
  reg                   i2c_write;

  reg  [DATA_WIDTH-1:0] prdata_int;
  reg                   pready_int;

  i2c_master #(
      .CLK_FREQ(CLK_FREQ),
      .I2C_FREQ(I2C_FREQ)
  ) i2c_master_inst (
      .clk(clk),
      .rst_n(rst_n),
      .start(i2c_start),
      .stop(i2c_stop),
      .read(i2c_read),
      .write(i2c_write),
      .slave_addr(slave_addr_reg),
      .tx_data(tx_data_reg),
      .rx_data(i2c_rx_data),
      .busy(i2c_busy),
      .ack_error(i2c_ack_error),
      .done(i2c_done),
      .sda(sda),
      .scl(scl)
  );

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      control_reg <= 32'h0;
      slave_addr_reg <= 7'h0;
      tx_data_reg <= 8'h0;
      i2c_start <= 0;
      i2c_stop <= 0;
      i2c_read <= 0;
      i2c_write <= 0;
    end else begin
      i2c_start <= 0;
      i2c_stop  <= 0;
      i2c_read  <= 0;
      i2c_write <= 0;

      if (PSEL && PENABLE && PWRITE) begin
        case (PADDR)
          REG_CONTROL: begin
            control_reg <= PWDATA;
            i2c_start <= PWDATA[0];
            i2c_stop <= PWDATA[1];
            i2c_read <= PWDATA[2];
            i2c_write <= PWDATA[3];
          end
          REG_SLAVE_ADDR: slave_addr_reg <= PWDATA[6:0];
          REG_TX_DATA:    tx_data_reg <= PWDATA[7:0];
        endcase
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_data_reg <= 8'h0;
    end else if (i2c_done && i2c_read) begin
      rx_data_reg <= i2c_rx_data;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      status_reg <= 32'h0;
    end else begin
      status_reg[0] <= i2c_busy;
      status_reg[1] <= i2c_done;
      status_reg[2] <= i2c_ack_error;
    end
  end

  always @(*) begin
    prdata_int = 32'h0;
    if (PSEL && !PWRITE) begin
      case (PADDR)
        REG_CONTROL:    prdata_int = control_reg;
        REG_STATUS:     prdata_int = status_reg;
        REG_SLAVE_ADDR: prdata_int = {25'h0, slave_addr_reg};
        REG_TX_DATA:    prdata_int = {24'h0, tx_data_reg};
        REG_RX_DATA:    prdata_int = {24'h0, rx_data_reg};
        default:        prdata_int = 32'h0;
      endcase
    end
  end

  assign PRDATA = prdata_int;

  always @(*) begin
    pready_int = PSEL && PENABLE;
  end

  assign PREADY  = pready_int;
  assign PSLVERR = 1'b0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) irq <= 0;
    else irq <= i2c_done | i2c_ack_error;
  end

endmodule

// ============================================================================
// END OF FILE
// ============================================================================
