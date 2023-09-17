//REFERENCE CODE:
// https://github.com/jhallen/i2cmon

`include "i2c_recv.v"
`include "uart.v"
`include "fifo.v"

module dut(
    clk,
    reset,
    SCL_IN,
    SDA_IN,
    SDA,
    rx,
    tx
    );
  
  input clk;
  input reset;

  input SCL_IN;
  input SDA_IN;
  output SDA;
  
  input rx;
  output tx;
  wire tx;
  
  // UART
  /*
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
  */
  
  wire [7:0] tx_fifo_readData;
  wire [7:0] rx_fifo_writeData;
  wire tx_fifo_re;
  wire rx_fifo_we;
  wire tx_fifo_notEmpty;
  wire uart_FrameError;
  wire rx_en = 1'd1;
  wire baud_pulse; // for tick
  
  reg tx_enable;


uart uart(
        .reset (reset),
        .clk (clk),
        .baud_rate (12'd54),
        .tick (baud_pulse),
        .tx_fifo_readData (tx_fifo_readData),
        .rx_fifo_writeData (rx_fifo_writeData),
        .uart_tx (tx),
        .uart_rx (rx),
        .tx_fifo_re (tx_fifo_re),
        .rx_fifo_we (rx_fifo_we),
        .tx_fifo_notEmpty (tx_fifo_notEmpty && tx_enable),
        .uart_FrameError (uart_FrameError),
        .rx_en
      );
  
  // Serial output FIFO
  wire tx_fifoFULL;
  reg [7:0] tx_fifo_writeData;
  reg tx_fifo_we;
  ///////////////////////////////////////////////////////////
  
fifo #(.dataWIDTH(8), .addressWIDTH(13)) tx_fifo
   (
  .clk (clk),
  .reset (reset),
  .writeData (tx_fifo_writeData),
  .readData (tx_fifo_readData),
  .writeENABLE (tx_fifo_we),
  .readENABLE (tx_fifo_re),
  .full (tx_fifoFULL),
  .notEmpty (tx_fifo_notEmpty)
  );

  
  // controlling flow
  always @(posedge clk or negedge reset)
    if (!reset)
      tx_enable <= 1;
    else if (rx_fifo_we)
      begin
        if (rx_fifo_writeData == 8'h13) 
          tx_enable <= 0; // Stop sending
        else 
          tx_enable <= 1; // Resume sending
      end
  
  // I2C monitor
  
  wire oneByteRecieved;
  wire IncompleteByte;
  wire [7:0] Byte;
  wire ACK;
  
  wire START;
  wire STOP;
  wire NoTransaction;
  
  wire SCL;
  wire SDA;
  
  i2c_recv i2c_recv
    (
    .clk (clk),
    .reset (reset),
    .SCL_IN (SCL_IN),
    .SDA_IN (SDA_IN),
    .SCL (SCL),
    .SDA (SDA),
    .oneByteRecieved (oneByteRecieved), 
    .Byte (Byte), 
    .ACK (ACK), 
    .IncompleteByte (IncompleteByte), 
    .START (START), 
    .STOP (STOP), 
    .NoTransaction (NoTransaction)
    );
  // Real time clock

reg [22:0] long_counter;
reg tick10;
reg [19:0] rtc; // 999.9 seconds
reg time_check;

always @(posedge clk or negedge reset)
  if (!reset)
    begin
      long_counter <= 0;
      rtc <= 0;
      tick10 <= 0;
      time_check <= 0;
    end
  else
    begin
      tick10 <= 0;
      if (long_counter == 23'd4_999_999) //50MHZ/5M = 10HZ
        begin
          long_counter <= 0;
          tick10 <= 1;
        end
      else
        long_counter <= long_counter + 1'd1;
      if (tick10)
        begin
          if (rtc[7:0] == 8'h99)
            time_check <= !time_check;

          // Increment decimal digits...
          if (rtc[3:0] != 9)
            rtc[3:0] <= rtc[3:0] + 1'd1;
          else
            begin
              rtc[3:0] <= 0;
              if (rtc[7:4] != 9)
                rtc[7:4] <= rtc[7:4] + 1'd1;
              else
                begin
                  rtc[7:4] <= 0;
                  if (rtc[11:8] != 9)
                    rtc[11:8] <= rtc[11:8] + 1'd1;
                  else
                    begin
                      rtc[11:8] <= 0;
                      if (rtc[15:12] != 9)
                        rtc[15:12] <= rtc[15:12] + 1'd1;
                      else
                        begin
                          rtc[15:12] <= 0;
                          if (rtc[19:16] != 0)
                            rtc[19:16] <= rtc[19:16] + 1'd1;
                          else
                            rtc[19:16] <= 0;
                        end
                    end
                end
            end
        end
    end
  // Format recieved I2C data...
  
  reg [4:0] stateMachine;
  
  parameter
    SM_IDLE = 0,
    SM_B0 = 1,
    SM_B1 = 2,
    SM_B2 = 3,
    SM_B3 = 4,
    SM_B4 = 5,
    SM_B5 = 6,
    SM_B6 = 7,
    SM_B7 = 8,
    SM_DATA = 9,
    SM_LOW = 10,
    SM_ACK = 11,
    SM_SPC = 12,
    SM_CR = 13,
    SM_LF = 14,
    SM_REPEAT = 15,
    SM_A = 16,
    SM_B = 17;
  
  reg [19:0] SM_BUFFER;
  reg SM_FLAG;
  reg SM_TIMECHECK;
  
  always @(posedge clk or negedge reset)
    if (!reset)
      begin
        tx_fifo_we <= 0;
        tx_fifo_writeData <= 0;
        SM_TIMECHECK <= 0;
        SM_BUFFER <= 0;
        SM_FLAG <= 0;
        stateMachine <= SM_IDLE;
      end
    else
      begin
        tx_fifo_we <= 0;
        case (stateMachine)
          SM_IDLE:
            if (START) // THERE IS DATA
              if (!tx_fifoFULL)
                begin
                  SM_FLAG <= 0;
                  SM_BUFFER <= rtc;
                  tx_fifo_writeData <= 8'h5b;
                  tx_fifo_we <= 1;
                  stateMachine <= SM_B0;
                end
              else
                begin
                  tx_fifo_writeData <= 8'h56;
                  tx_fifo_we <= 1;
                  stateMachine <= SM_CR;
                end
            else if (time_check != SM_TIMECHECK)
              begin // Print time check
                SM_TIMECHECK <= time_check;
                SM_BUFFER <= rtc;
                tx_fifo_writeData <= 8'h5b; // [
                tx_fifo_we <= 1;
                stateMachine <= SM_B0;
                SM_FLAG <= 1;
              end
  
          SM_B0:
            begin
              tx_fifo_writeData <= 8'h30 + SM_BUFFER[19:16];
              tx_fifo_we <= 1;
              stateMachine <= SM_B1;
            end
  
          SM_B1:
            begin
              tx_fifo_writeData <= 8'h30 + SM_BUFFER[15:12];
              tx_fifo_we <= 1;
              stateMachine <= SM_B2;
            end
  
          SM_B2:
            begin
              tx_fifo_writeData <= 8'h30 + SM_BUFFER[11:8];
              tx_fifo_we <= 1;
              stateMachine <= SM_B3;
            end
  
          SM_B3:
            begin
              tx_fifo_writeData <= 8'h30 + SM_BUFFER[7:4];
              tx_fifo_we <= 1;
              stateMachine <= SM_B4;
            end
            
          SM_B4:
            begin
              tx_fifo_writeData <= 8'h2E; // .
              tx_fifo_we <= 1;
              stateMachine <= SM_B5;
            end
  
          SM_B5:
            begin
              tx_fifo_writeData <= 8'h30 + SM_BUFFER[3:0];
              tx_fifo_we <= 1;
              stateMachine <= SM_B6;
            end
  
          SM_B6:
            begin
              tx_fifo_writeData <= 8'h5d; // ]
              tx_fifo_we <= 1;
              stateMachine <= SM_B7;
            end
  
          SM_B7:
            begin
              tx_fifo_writeData <= 8'h20;
              tx_fifo_we <= 1;
              if (SM_FLAG)
                stateMachine <= SM_A;
              else
                stateMachine <= SM_DATA;
            end
  
          SM_A:
            begin
              if (SCL)
                tx_fifo_writeData <= 8'h43; // C
              else
                tx_fifo_writeData <= 8'h63; // c
              tx_fifo_we <= 1;
              stateMachine <= SM_B;
            end
  
          SM_B:
            begin
              if (SDA)
                tx_fifo_writeData <= 8'h44; // D
              else
                tx_fifo_writeData <= 8'h64; // d
              tx_fifo_we <= 1;
              stateMachine <= SM_CR;
            end
  
          SM_DATA:
            begin
              // Record data
              SM_BUFFER <= { 7'd0, NoTransaction, START, STOP, IncompleteByte, ACK, Byte };
  
              if (oneByteRecieved)
                begin
                  // We have data, so print it
                  if (Byte[7:4] >= 10)
                    tx_fifo_writeData <= 8'h41 + Byte[7:4] - 8'd10;
                  else
                    tx_fifo_writeData <= 8'h30 + Byte[7:4];
                  tx_fifo_we <= 1;
                  stateMachine <= SM_LOW;
                end
              else if (STOP)
                // No data, but we have a stop
                stateMachine <= SM_SPC;
            end
  
          SM_LOW:
            begin
              if (SM_BUFFER[3:0] >= 10)
                tx_fifo_writeData <= 8'h41 + SM_BUFFER[3:0] - 8'd10;
              else
                tx_fifo_writeData <= 8'h30 + SM_BUFFER[3:0];
              tx_fifo_we <= 1;
              stateMachine <= SM_ACK;
            end
  
          SM_ACK:
            begin
              if (SM_BUFFER[9])
                tx_fifo_writeData <= 8'h3f; // Short byte: print ?
              else if (SM_BUFFER[8])
                tx_fifo_writeData <= 8'h2d; // NAK
              else
                tx_fifo_writeData <= 8'h2b; // ACK
              tx_fifo_we <= 1;
              
              stateMachine <= SM_SPC;
            end
  
          SM_SPC:
            if (SM_BUFFER[10]) // Stop
              begin
                if (SM_BUFFER[11]) // Repeated start
                  begin
                    tx_fifo_writeData <= 8'h52;
                    tx_fifo_we <= 1;
                    stateMachine <= SM_REPEAT;
                  end
                else if (SM_BUFFER[12]) // Normal top, but empty transaction
                  begin
                    tx_fifo_writeData <= 8'h45;
                    tx_fifo_we <= 1;
                    stateMachine <= SM_CR;
                  end
                else // Normal stop
                  stateMachine <= SM_CR;
              end
            else
              begin // No stop..
                tx_fifo_writeData <= 8'h20;
                tx_fifo_we <= 1;
                stateMachine <= SM_DATA;
              end
  
          SM_REPEAT:
            begin
              tx_fifo_writeData <= 8'h20;
              tx_fifo_we <= 1;
              stateMachine <= SM_DATA;
            end
  
          SM_CR:
            begin
              tx_fifo_writeData <= 'h0d;
              tx_fifo_we <= 1;
              stateMachine <= SM_LF;
            end
  
          SM_LF:
            begin
              tx_fifo_writeData <= 'h0A;
              tx_fifo_we <= 1;
              stateMachine <= SM_IDLE;
            end
        endcase
      end
  
  endmodule