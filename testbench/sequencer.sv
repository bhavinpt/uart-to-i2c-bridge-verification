// ******************************************************
// File	       : sequencer.sv
// Project     : UART to I2C-bus Bridge verification(SC18IM704)
//             : Part of EE273 Project (fall 2022)
//	       : Prepared by (Group: G01) (Members: Bhavin Patel, Neol Rajesh Solanki, Fabiha Roshni Khan, Karthik Ekke)
// Description : virtual sequencer hierarchy 
// ******************************************************


// ############################## 
// uart base sequencer class
// ############################## 
class UartSequencer extends uvm_sequencer #(UartData);
  `uvm_component_utils(UartSequencer)

  function new(string name="UartSequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

endclass : UartSequencer 

// ############################## 
// uart base sequencer class
// ############################## 
class I2cSequencer extends uvm_sequencer #(I2cData);
  `uvm_component_utils(I2cSequencer)

  function new(string name="I2cSequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

endclass : I2cSequencer


// ############################## 
// top level virtual sequencer class
// ############################## 
class BridgeVirtualSequencer extends uvm_sequencer;
  UartSequencer uartSeqr;
  I2cSequencer i2cSeqr;

  `uvm_component_utils_begin(BridgeVirtualSequencer)
  `uvm_field_object(uartSeqr, UVM_ALL_ON)
  `uvm_field_object(i2cSeqr, UVM_ALL_ON)
  `uvm_component_utils_end

  function new(string name="BridgeVirtualSequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new
  
  function void build_phase(uvm_phase phase);
    uartSeqr = UartSequencer::type_id::create("uartSeqr", this);
    i2cSeqr = I2cSequencer::type_id::create("i2cSeqr", this);
  endfunction

endclass : BridgeVirtualSequencer


