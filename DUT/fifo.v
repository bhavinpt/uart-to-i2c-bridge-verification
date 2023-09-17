//REFERENCE CODE:
// https://github.com/jhallen/i2cmon

module fifo (
  clk,
  reset,
  writeData,
  readData,
  writeENABLE,
  readENABLE,
  full_n,
  full,
  overflow,
  underflow,
  notEmpty
  );

parameter
  addressWIDTH = 5, 
  dataWIDTH = 18, 
  diffFullandOverflow = 4; // Number of words between full and overflow

input clk;
input reset;

input [dataWIDTH-1:0] writeData; 
output [dataWIDTH-1:0] readData; 
input writeENABLE;
input readENABLE; 
output reg full_n;
output reg full; //almost full
output reg overflow; // FIFO is broken when 1
output reg underflow;  // FIFO is broken when 1
output reg notEmpty;

reg [addressWIDTH-1:0] readAddress, readAddress_ns; // oldest data
reg [addressWIDTH-1:0] writeAddress, writeAddress_ns;
reg [addressWIDTH:0] count, count_d; // Number of words in FIFO

memory #(.dataWIDTH(dataWIDTH), .addressWIDTH(addressWIDTH)) ram
  (
  .clk (clk),
  .writeData (writeData),
  .writeAddress (writeAddress),
  .writeENABLE (writeENABLE),
  .readData (readData),
  .readAddress (readAddress_ns)
  );


reg writeENABLE_d; // Delay assertion of notEmpty after writeENABLE because ram has 2 cycle delay

always @(posedge clk or negedge reset)
  if (!reset)
    begin
      readAddress <= 0;
      writeAddress <= 0;
      writeENABLE_d <= 0;
      overflow <= 0;
      underflow <= 0;
      full <= 0;
      count <= 0;
    end
  else
    begin
      writeAddress <= writeAddress_ns;
      readAddress <= readAddress_ns;
      writeENABLE_d <= writeENABLE;
      count <= count_d;
      full <= full_n;

      if (readENABLE && !notEmpty)
        begin
          underflow <= 1;
          $display("%m FIFO underflow");
          $finish;
        end

      if (writeENABLE_d && (count == (1 << addressWIDTH)))
        begin
          overflow <= 1;
          $display("%m FIFO overflow");
          $finish;
        end
    end

// Read side state

always @(*)
  begin
    readAddress_ns = readAddress;
    writeAddress_ns = writeAddress;
    count_d = count;

    if (writeENABLE)
      writeAddress_ns = writeAddress_ns + 1'd1;
    if (readENABLE)
      readAddress_ns = readAddress_ns + 1'd1;

    if (writeENABLE_d && !readENABLE)
      count_d = count_d + 1'd1;
    else if (!writeENABLE_d && readENABLE)
      count_d = count_d - 1'd1;

    full_n = (count_d >= (1 << addressWIDTH) - diffFullandOverflow);
    notEmpty = (count != 0);
  end

endmodule


module memory(
  clk,
  writeData,
  writeAddress,
  writeENABLE,
  readData,
  readAddress
  );

parameter dataWIDTH = 9;
parameter addressWIDTH = 9;

input clk;
input [dataWIDTH-1:0] writeData;
output reg [dataWIDTH-1:0] readData;
input [addressWIDTH-1:0] writeAddress;
input [addressWIDTH-1:0] readAddress;
input writeENABLE;


reg [dataWIDTH-1:0] ram[((1 << addressWIDTH) - 1) : 0];

always @(posedge clk)
  begin
    if (writeENABLE)
      ram[writeAddress] <= writeData;
    readData <= ram[readAddress];
  end

endmodule