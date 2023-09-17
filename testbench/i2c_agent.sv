// ******************************************************
// File	       : i2c_agent.sv
// Project     : UART to I2C-bus Bridge verification(SC18IM704)
//             : Part of EE273 Project (fall 2022)
//	       : Prepared by (Group: G01) (Members: Bhavin Patel, Neol Rajesh Solanki, Fabiha Roshni Khan, Karthik Ekke)
// Description : I2C agent class 
// ******************************************************

class I2cMasterAgent extends uvm_agent;
  I2cDriver driver;

  // UVM automation macros for general components
  `uvm_component_utils_begin(I2cMasterAgent)
    `uvm_field_object(driver, UVM_ALL_ON)
  `uvm_component_utils_end

  // constructor
  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    driver = I2cDriver::type_id::create("driver", this);
  endfunction

endclass : I2cMasterAgent


class I2cSlaveAgent extends uvm_agent;
  I2cMonitor monitor;
  I2cByteMonitor byteMonitor;

  // UVM automation macros for general components
  `uvm_component_utils_begin(I2cSlaveAgent)
    `uvm_field_object(monitor, UVM_ALL_ON)
  `uvm_component_utils_end

  // constructor
  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = I2cMonitor::type_id::create("monitor", this);
    byteMonitor = I2cByteMonitor::type_id::create("byteMonitor", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    monitor.i2cByteRxPort.connect(byteMonitor.i2cByteRxImp);
    monitor.i2cAckRxPort.connect(byteMonitor.i2cAckRxImp);
    monitor.i2cStopRxPort.connect(byteMonitor.i2cStopRxImp);
    super.connect_phase(phase);
    //
  endfunction

endclass : I2cSlaveAgent
