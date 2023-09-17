// recieving from UART

module i2c_recv
  (
  clk,
  reset,
  SCL_IN,
  SDA_IN,
  SCL,
  SDA,
  oneByteRecieved, 
  Byte, 
  ACK, 
  IncompleteByte, 
  START, 
  STOP, 
  NoTransaction 
  );

input clk;
input reset;

input SCL_IN;
input SDA_IN;

output SCL;
output SDA;

output reg oneByteRecieved; // To detect each byte recieved
output reg [7:0] Byte; // just one Byte
output reg ACK; //acknowledgement after all byte recieved
output reg START; // statrt detection
output reg STOP; // stop detection
output reg IncompleteByte; //not all bytes recieved
output reg NoTransaction; // when no transaction occuring, 0-length-transaction, will remain high along with stop


// pipeline SCL and SDA values to detect fall and rise edge
reg SCL_4;
reg SCL_3;
reg SCL_2;
reg SCL_1;
reg SCL;
reg SCL_old;
reg SDA_4;
reg SDA_3;
reg SDA_2;
reg SDA_1;
reg SDA;
reg SDA_old;
////////////////////////////////

reg [2:0] FSM_I2C;
parameter
  I2C_IDLE = 0, // will wait for start condition, detect falling SDA when SCL high
  I2C_WAIT = 1, // will wait a clock after start detected, skip first falling SCL
  I2C_TRANSMISSION = 2; //WILL receive the data and also look for stop condition

reg [3:0] rx_count;

always @(posedge clk or negedge reset)
  if (!reset)
    begin
      //pipelining to keep track of the old SCL and SDA values to detect the falling and rising edge
      SCL_4 <= 1;
      SCL_3 <= 1;
      SCL_2 <= 1;
      SCL_1 <= 1;
      SCL <= 1;
      SCL_old <= 1;
      SDA_4 <= 1;
      SDA_3 <= 1;
      SDA_2 <= 1;
      SDA_1 <= 1;
      SDA <= 1;
      SDA_old <= 1;

      FSM_I2C <= I2C_IDLE;
      rx_count <= 0;

      oneByteRecieved <= 0;
      Byte <= 0;
      ACK <= 0;
      START <= 0;
      STOP <= 0;
      IncompleteByte <= 0;
      NoTransaction <= 0;
    end
  else
    begin
      SCL_4 <= SCL_IN;
      SCL_3 <= SCL_4;
      SCL_2 <= SCL_3;
      SCL_1 <= SCL_2;
      SCL <= (SCL_3 ? (SCL_2 || SCL_1) : (SCL_2 && SCL_1)); 
      SCL_old <= SCL;
      SDA_4 <= SDA_IN;
      SDA_3 <= SDA_4;
      SDA_2 <= SDA_3;
      SDA_1 <= SDA_2;
      SDA <= (SDA_3 ? (SDA_2 || SDA_1) : (SDA_2 && SDA_1)); 
      SDA_old <= SDA;

      oneByteRecieved <= 0;
      START <= 0;
      STOP <= 0;
      IncompleteByte <= 0;
      NoTransaction <= 0;

      case (FSM_I2C)
      	I2C_IDLE: // detect start condition, detect falling SDA when SCL high
      	  begin
            if (SCL == 1 && SDA == 0 && SDA_old == 1) // Falling SDA while SCL is high
              begin
                FSM_I2C <= I2C_WAIT;
                START <= 1; //start detected
              end
      	  end

      	I2C_WAIT: // start detected and then skip first falling scl
      	  begin
      	    if (SCL == 0 && SCL_old == 1) // Falling SCL
      	      begin
      	        FSM_I2C <= I2C_TRANSMISSION; // now start receiving data from uart
      	        Byte <= 0; //cause byte not recieved yet, just detetcted start
      	        ACK <= 0;
      	        rx_count <= 0;
      	      end
            else if (SCL == 1 && SDA == 1 && SDA_old == 0) // Rising SDA while SCL is high
      	      begin // 
      	        FSM_I2C <= I2C_IDLE;
      	        NoTransaction <= 1;
      	        STOP <= 1; // this is when early stop detected
      	        Byte <= 0; // Stop w/o any transaction
      	      end
      	  end

      	I2C_TRANSMISSION: // Clock data on falling SCLs, look for stop condition
      	  begin
            if (SCL == 0 && SCL_old == 1) // Falling SCL
              begin // data bit transferred
                rx_count <= rx_count + 1'd1;
                { Byte, ACK } <= { Byte[6:0], ACK, SDA };
                if (rx_count == 8)
                  begin
                    oneByteRecieved <= 1;
                    rx_count <= 0;
                  end
              end
            else if (SCL == 1 && SDA == 1 && SDA_old == 0) // Rising SDA when SCL high
              begin // STOP detected
                FSM_I2C <= I2C_IDLE;
                STOP <= 1; 
                if (rx_count) // incomplete transaction
                  begin
                    oneByteRecieved <= 1;
                    IncompleteByte <= 1;
                    { Byte, ACK } <= { Byte[6:0], ACK, 1'd0 };
                  end
              end
            else if (SCL == 1 && SDA == 0 && SDA_old == 1) // Falling SDA when SCL high
              begin // START detected (repeated)
                FSM_I2C <= I2C_WAIT;
                STOP <= 1;
                START <= 1;
                if (rx_count)
                  begin
                    oneByteRecieved <= 1;
                    IncompleteByte <= 1; // Incomplete data
                    { Byte, ACK } <= { Byte[6:0], ACK, 1'd0 };
                  end
              end
            
      	  end
      endcase
    end

endmodule