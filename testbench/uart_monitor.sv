// ******************************************************
// File	       : uart_monitor.sv
// Project     : UART to I2C-bus Bridge verification(SC18IM704)
//             : Part of EE273 Project (fall 2022)
//	       : Prepared by (Group: G01) (Members: Bhavin Patel, Neol Rajesh Solanki, Fabiha Roshni Khan)
// Description : UART monitor class 
// ******************************************************

typedef enum {
  IDLE_STATE,
  STOP_STATE,
  START_STATE,
  DATA_STATE
} UartMonitorStateT;


// ############################## 
// monitor class
// ############################## 
class UartMonitor extends uvm_monitor;
  UartData uartData;
  virtual UART_interface_slave vif;
  BaudGen baudGen;
  UartMonitorStateT state;
  uvm_analysis_port#(bit[7:0]) uartByteRxPort;
  bit[7:0] rxByte;
  int rxBitIdx;

  `uvm_component_utils_begin(UartMonitor)
  `uvm_field_object(uartData, UVM_ALL_ON)
  `uvm_component_utils_end

  function new(string name="UartMonitor", uvm_component parent = null);
    super.new(name, parent);
    uartByteRxPort = new("uartByteRxPort", this);
    baudGen = new();
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    if (!uvm_config_db#(virtual UART_interface_slave)::get(null, "", "uart_intf_slave", vif)) begin
      `uvm_error("VIF_GET_ERROR","COULD NOT GET VIF")
    end
  endfunction

  task run_phase(uvm_phase phase);
    state = IDLE_STATE;

    // wait for initial reset
    @(posedge vif.reset);
    baudGen.stop(1, vif.deubg_uart_rx_clk);


    forever begin
      case(state)
	IDLE_STATE: begin
	  @(negedge vif.RX);
	  baudGen.start(1, vif.deubg_uart_rx_clk);
	  rxByte = 0;
	  rxBitIdx = 0;
	  state = DATA_STATE;
	  $display("UART_RX: start bit @%t", $time);
	  baudGen.negEdgeEvent.wait_trigger();
	end

	DATA_STATE: begin
	  baudGen.posEdgeEvent.wait_trigger();
	  rxByte[rxBitIdx] = bit'(vif.RX);
	  rxBitIdx++;
	  $display("UART_RX: %0dth-Bit: 0x%0d @%t", rxBitIdx, vif.RX, $time);
	  if(rxBitIdx == 8) begin
	    $display("UART_RX: Byte: 0x%x (8'b%8b) @%t", rxByte, rxByte, $time);
	    rxBitIdx = 0;
	    state = STOP_STATE;
	  end
	end

	STOP_STATE: begin
	  baudGen.posEdgeEvent.wait_trigger();
	  if(vif.RX != 1) begin
	    `uvm_error("ERR_UART_MISSING_STOP_BIT", $sformatf("Data byte did not end with a stop state"))
	  end
	  else begin
	    $display("UART_RX: stop bit @%t", $time);
	  end
	  uartByteRxPort.write(rxByte);
	  baudGen.stop(1, vif.deubg_uart_rx_clk);
	  state = IDLE_STATE;
	end
      endcase

      begin
      end
    end
  endtask : run_phase

endclass : UartMonitor




