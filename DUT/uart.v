
//REFERENCE CODE:
// https://github.com/jhallen/i2cmon


// not sure will include this module baud or not, Dont think need this
module baud(
  reset,
  clk,
  tick
  );

parameter BAUD = 115200; // baud rate
parameter OSC = 50000000; // Oscillator frequency

input reset;
input clk;
output reg tick;

reg [26:0] accu; 
// divide OSC and BAUD by GCD(OSC, BAUD) to reduce number
// of bits needed for this.

always @(posedge clk or negedge reset)
  if (!reset)
    begin
      accu <= 0;
      tick <= 0;
    end
  else
    if (accu[26]) // Negative
      begin
        accu <= accu + BAUD;
        tick <= 0;
      end
    else // Positive
      begin
        accu <= accu + BAUD - OSC;
        tick <= 1;
      end

endmodule
/////////////////////////////////////////////////////////////////////////

module uart(
    reset,
    clk,
    baud_rate,
    tick,
    tx_fifo_readData,
    rx_fifo_writeData,
    uart_tx,
    uart_rx,
    tx_fifo_re,
    rx_fifo_we,
    tx_fifo_notEmpty,
    uart_FrameError,
    rx_en
  );
  
  input reset;
  input clk;

  // Baud rate divisor
  input [11:0] baud_rate;
  output reg tick;

  output reg [7:0] rx_fifo_writeData;
  output reg rx_fifo_we;
  output reg uart_FrameError;
  input rx_en;
  input uart_rx;

  input [7:0] tx_fifo_readData;
  output reg tx_fifo_re;
  input tx_fifo_notEmpty;
  output reg uart_tx;

// Transmit baud rate generator

reg [11:0] counter;


always @(posedge clk or negedge reset)
  if(reset)
    begin
      tick <= 0;
      if(counter!=1)
        counter <= counter - 1;
      else
        begin
          counter <= baud_rate;
          tick <= 1;
        end
    begin
      counter <= 0;
      tick <= 0;
    end
    end
  else
    begin
      counter <= 0;
      tick <= 0;
    end

// Receiver

reg uart_rx_1;
reg uart_rx_2;

reg [8:0] rx_shift_reg;
reg [11:0] rx_counter;
reg rx_flag;

always @(posedge clk or negedge reset)
  if(!reset)
    begin
      rx_shift_reg <= 0;
      rx_counter <= 0;
      rx_flag <= 0;
      rx_fifo_we <= 0;
      rx_fifo_writeData <= 0;
      uart_FrameError <= 0;
      uart_rx_1 <= 1;
      uart_rx_2 <= 1;
    end
  else
    begin
      uart_rx_2 <= uart_rx; // synchronizing input
      uart_rx_1 <= uart_rx_2; // synchronize
      rx_fifo_we <= 0;
      uart_FrameError <= 0;

      if(rx_flag)
        begin
          if(rx_counter!=1)
            rx_counter <= rx_counter - 1;
          else if(!rx_shift_reg[0])
            begin // got start and stop bit
              rx_flag <= 0;
              rx_fifo_writeData <= rx_shift_reg[8:1];
              rx_fifo_we <= rx_en;
              if(!uart_rx_1)
                uart_FrameError <= rx_en;
            end
          else
            begin // shifting next bit
              rx_counter <= baud_rate;
              rx_shift_reg <= { uart_rx_1, rx_shift_reg[8:1] };
            end
        end
      else if(!uart_rx_1)
        begin // leading start bit edge, delay bit
          rx_counter <= { 1'd0, baud_rate[11:1] };
          rx_shift_reg <= 9'h1ff;
          rx_flag <= 1;
        end
    end

// Transmitter
reg [5:0] tx_counter;
reg [8:0] tx_shiftReg;

always @(posedge clk or negedge reset)
  if(reset)
    begin
      tx_fifo_re <= 0;
      if(tx_counter)
        begin
          if(tick) // transmitting
            begin
              tx_shiftReg <= { 1'd1, tx_shiftReg[8:1] };
              uart_tx <= tx_shiftReg[0];
              tx_counter <= tx_counter - 1;
            end
        end
      else
        begin 
          if(tx_fifo_notEmpty)//not transmitting, reading FIFO
            begin
              tx_shiftReg <= { tx_fifo_readData, 1'd0 };
              tx_fifo_re <= 1;
              tx_counter <= 10;
            end
        end
    end
  else
    begin
      uart_tx <= 1;
      tx_fifo_re <= 0;
      tx_counter <= 0;
      tx_shiftReg <= 0;
    end



endmodule

