// ******************************************************
// File	       : env.sv
// Project     : UART to I2C-bus Bridge verification(SC18IM704)
//             : Part of EE273 Project (fall 2022)
//	       : Prepared by (Group: G01) (Members: Bhavin Patel, Neol Rajesh Solanki, Fabiha Roshni Khan, Karthik Ekke)
// Description : The verification environment
// ******************************************************



// ############################## 
// environment class
// ############################## 

class BridgeEnv extends uvm_env;
  UartMasterAgent uartMaster;
  UartSlaveAgent uartSlave;
  I2cMasterAgent i2cMaster;
  I2cSlaveAgent i2cSlave;

  BridgeVirtualSequencer vSeqr;
  ScoreboardTop scoreboard;

  `uvm_component_utils_begin(BridgeEnv)
  `uvm_field_object(uartMaster, UVM_ALL_ON)
  `uvm_field_object(uartSlave, UVM_ALL_ON)
  `uvm_field_object(i2cMaster, UVM_ALL_ON)
  `uvm_field_object(vSeqr, UVM_ALL_ON)
  `uvm_component_utils_end

  function new(string name="BridgeEnv", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uartMaster = UartMasterAgent::type_id::create("uartMaster", this);
    uartSlave = UartSlaveAgent::type_id::create("uartSlave", this);
    i2cMaster = I2cMasterAgent::type_id::create("i2cMaster", this);
    i2cSlave = I2cSlaveAgent::type_id::create("i2cSlave", this);
    
    vSeqr= BridgeVirtualSequencer::type_id::create("vSeqr", this);
    scoreboard = ScoreboardTop::type_id::create("ScoreboardTop", this);
  endfunction : build_phase

  virtual function void connect_phase(uvm_phase phase);
    uartMaster.driver.seq_item_port.connect(vSeqr.uartSeqr.seq_item_export);
    i2cMaster.driver.seq_item_port.connect(vSeqr.i2cSeqr.seq_item_export);
    i2cSlave.monitor.i2cAckEventPort.connect(i2cMaster.driver.i2cAckEventImp);

    // scoreboard connections
    uartMaster.driver.uartMsgTxPort.connect(scoreboard.uartMsgTxTopImp);
    scoreboard.uartOkScoreboard.uartOkDetectedPort.connect(uartMaster.driver.uartOkDetectedImp);
    uartSlave.monitor.uartByteRxPort.connect(scoreboard.uartByteRxTopImp);

    i2cMaster.driver.i2cMsgTxPort.connect(scoreboard.i2cMsgTxTopImp);
    i2cSlave.byteMonitor.i2cMsgRxPort.connect(scoreboard.i2cMsgRxTopImp);
  endfunction : connect_phase

endclass : BridgeEnv


