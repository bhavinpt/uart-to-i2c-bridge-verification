// ******************************************************
// File	       : test.sv
// Project     : UART to I2C-bus Bridge verification(SC18IM704)
//             : Part of EE273 Project (fall 2022)
//	       : Prepared by (Group: G01) (Members: Bhavin Patel, Neol Rajesh Solanki, Fabiha Roshni Khan, Karthik Ekke)
// Description : Main test class
// ******************************************************


// ############################## 
// test class
// ############################## 

class BridgeTest extends uvm_test;
  BridgeEnv env;
  BridgeSequence seq;

  `uvm_component_utils_begin(BridgeTest)
  `uvm_field_object(env, UVM_ALL_ON)
  `uvm_field_object(seq, UVM_ALL_ON)
  `uvm_component_utils_end

  function new(string name = "BridgeTest", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase( uvm_phase phase);
    super.build_phase(phase);
    env = BridgeEnv::type_id::create("env", this);
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    phase.raise_objection(this);

    // create and start sequence
    seq = BridgeSequence::type_id::create("seq", this);
    seq.start(env.vSeqr);

    phase.drop_objection(this);
  endtask : run_phase

endclass : BridgeTest


// TODO: add more tests
