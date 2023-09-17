// ******************************************************
// File	       : types.sv
// Project     : UART to I2C-bus Bridge verification(SC18IM704)
//             : Part of EE273 Project (fall 2022)
//	       : Prepared by (Group: G01) (Members: Bhavin Patel, Neol Rajesh Solanki, Fabiha Roshni Khan)
// Description : type definitions used across the project 
// ******************************************************


// ---------------------------------------------------------------------------------
// testbench -- types 
// ---------------------------------------------------------------------------------

typedef bit[7:0] byteT;

typedef enum{
  WRITE = 0,
  READ = 1
} directionT;

typedef enum{
  ACK = 0,
  NACK = 1
} ackT;

typedef enum{
  S_CHAR = 32'h53, // I2C-bus START
  P_CHAR = 32'h50, // I2C-bus STOP
  R_CHAR = 32'h52, // read SC18IM704 internal register
  W_CHAR = 32'h57, // write to SC18IM704 internal regster
  I_CHAR = 32'h49, // read GPIO port (unsupported)
  O_CHAR = 32'h4F, // write to GPIO port (unsupported)
  Z_CHAR = 32'h5A // power down (unsupported)
} charsT;


class Command extends uvm_object;
  bit [7:0] data[$];
  bit [6:0] addr = 0;
  directionT dir;
  bit [6:0] length = 0;

  `uvm_object_utils_begin(Command)
    `uvm_field_queue_int(data, UVM_ALL_ON)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_enum(directionT, dir, UVM_ALL_ON)
    `uvm_field_int(length, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "");
    super.new(name);
  endfunction

endclass


