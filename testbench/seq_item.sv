// ******************************************************
// File	       : sequencer.sv
// Project     : UART to I2C-bus Bridge verification(SC18IM704)
//             : Part of EE273 Project (fall 2022)
//	       : Prepared by (Group: G01) (Members: Bhavin Patel, Neol Rajesh Solanki, Fabiha Roshni Khan, Karthik Ekke)
// Description : seq_item definitions for UART and I2C transactions 
// ******************************************************


// ############################## 
// The item sent by the sequence
// ############################## 
class UartData extends uvm_sequence_item;
  rand bit[7:0] data [$];
  rand bit [6:0] addr;
  rand directionT dir;
  rand int stopBauds;
  rand bit [7:0] length;

  constraint sb_con{
    soft stopBauds == 0;
  };

  constraint read{
    dir == READ -> data.size() == 0;
    dir != READ -> soft length == 0;
  }

  `uvm_object_utils_begin(UartData)
  `uvm_field_queue_int(data,  UVM_ALL_ON)
  `uvm_field_int(addr, UVM_ALL_ON)
  `uvm_field_enum(directionT, dir, UVM_ALL_ON)
  `uvm_field_int(stopBauds, UVM_ALL_ON)
  `uvm_field_int(length, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name="UartData");
    super.new(name);
  endfunction : new

endclass: UartData




class I2cData extends uvm_sequence_item;
  rand bit[7:0] data [$];
  rand bit [6:0] addr;
  rand directionT dir;
  rand int stopClks;

  `uvm_object_utils_begin(I2cData)
    `uvm_field_queue_int(data, UVM_ALL_ON)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_enum(directionT, dir, UVM_ALL_ON)
    `uvm_field_int(stopClks, UVM_ALL_ON)
  `uvm_object_utils_end

  constraint sc_con{
    soft stopClks inside {[0:100]};
  };

  function new(string name="I2cData");
    super.new(name);
  endfunction : new

endclass : I2cData
