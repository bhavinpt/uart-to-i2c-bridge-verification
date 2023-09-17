// ******************************************************
// File	       : uart_agent.sv
// Project     : UART to I2C-bus Bridge verification(SC18IM704)
//             : Part of EE273 Project (fall 2022)
//	       : Prepared by (Group: G01) (Members: Bhavin Patel, Neol Rajesh Solanki, Fabiha Roshni Khan)
// Description : UART agent class 
// ******************************************************

class UartMasterAgent extends uvm_agent;
  UartDriver driver;

  `uvm_component_utils_begin(UartMasterAgent)
    `uvm_field_object(driver, UVM_ALL_ON)
  `uvm_component_utils_end

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    driver = UartDriver::type_id::create("driver", this);
  endfunction

endclass : UartMasterAgent


class UartSlaveAgent extends uvm_agent;
  UartMonitor monitor;

  `uvm_component_utils_begin(UartSlaveAgent)
    `uvm_field_object(monitor, UVM_ALL_ON)
  `uvm_component_utils_end

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    monitor = UartMonitor::type_id::create("monitor", this);
  endfunction

endclass : UartSlaveAgent
