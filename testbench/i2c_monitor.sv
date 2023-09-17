// ******************************************************
// File	       : i2c_monitor.sv
// Project     : UART to I2C-bus Bridge verification(SC18IM704)
//             : Part of EE273 Project (fall 2022)
//	       : Prepared by (Group: G01) (Members: Bhavin Patel, Neol Rajesh Solanki, Fabiha Roshni Khan, Karthik Ekke)
// Description : I2C monitor class 
// ******************************************************

typedef enum {
  IDLE_STATE_I2C,
  STOP_STATE_I2C,
  START_STATE_I2C,
  DATA_STATE_I2C
}I2cMonitorStateT;

// ############################## 
// monitor class : collects bytes
// ############################## 
class I2cMonitor extends uvm_monitor;
  I2cData i2cData;
  virtual I2C_interface_slave vif;
  SclGen sclGen;
  I2cMonitorStateT state;
  uvm_analysis_port#(bit[7:0]) i2cByteRxPort;
  uvm_analysis_port#(ackT) i2cAckRxPort;
  uvm_analysis_port#(bit) i2cStopRxPort;
  uvm_analysis_port#(ackT) i2cAckEventPort;
  bit[7:0] rxByte;
  rand int ackChoiceInt;
  ackT ackChoice;

  `uvm_component_utils_begin(I2cMonitor)
  `uvm_field_object(i2cData, UVM_ALL_ON)
  `uvm_component_utils_end

  function new(string name="I2cMonitor", uvm_component parent = null);
    super.new(name, parent);
    i2cByteRxPort = new("i2cByteRxPort", this);
    i2cAckRxPort = new("i2cAclRxPort", this);
    i2cStopRxPort = new("i2cStopRxPort", this);
    i2cAckEventPort = new("i2cAckEventPort", this);
    sclGen = new();
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    if (!uvm_config_db#(virtual I2C_interface_slave)::get(null, "", "i2c_intf_slave", vif)) begin
      `uvm_error("VIF_GET_ERROR","COULD NOT GET VIF")
    end
  endfunction

  task run_phase(uvm_phase phase);
    state = IDLE_STATE_I2C;

    // wait for initial reset
    @(negedge vif.reset);

    forever begin
      case(state)
	IDLE_STATE_I2C: begin
	  forever 
	  begin
	    @(negedge vif.SDA);
	    if(vif.SCL == 1) begin
	      rxByte = 0;
	      state = DATA_STATE_I2C;
	      $display("I2C received start @%0t", $time);
	      break;
	    end
	  end
	end

	DATA_STATE_I2C: begin
	  fork : I2Cm
	    begin
	      forever begin
		// receive byte
		repeat(8) begin
		  @(posedge vif.SCL);
		  //$display("I2C received bit :%0d @%0t", vif.SDA, $time);
		  rxByte = rxByte << 1 | vif.SDA;
		end
		i2cByteRxPort.write(rxByte);
		void'(std::randomize(ackChoiceInt) with {ackChoiceInt inside {[1:100]};});
		ackChoice = ackChoiceInt <= 10 ? NACK : ACK; // 10% of bytes will be NACK'ed
		i2cAckEventPort.write(ACK);

		// receive ack
		@(posedge vif.SCL);
		i2cAckRxPort.write(ackChoice);

	      end
	    end
	    begin
	      forever begin
		@(posedge vif.SDA);
		if(vif.SCL == 1) begin
		  state = STOP_STATE_I2C;
		  i2cStopRxPort.write(1);
		  break;
		end
	      end
	    end
	  join_any
	  disable I2Cm;
	end

	STOP_STATE_I2C: begin
	  //if(vif.RX != 1) begin
	  //  `uvm_error("ERR_I2C_MISSING_STOP_BIT", $sformatf("Data byte did not end with a stop state"))
	  //end
	  //else begin
	  //  //$display("received stop bit @%t", $time);
	  //end
	  state = IDLE_STATE_I2C;
	end
      endcase
    end

  endtask : run_phase
endclass : I2cMonitor







// ############################## 
// monitor class : Converts received bytes into one stream
// ############################## 
`uvm_analysis_imp_decl(_i2c_byte_rx)
`uvm_analysis_imp_decl(_i2c_ack_rx)
`uvm_analysis_imp_decl(_i2c_stop_rx)
class I2cByteMonitor extends uvm_monitor;
  uvm_analysis_imp_i2c_byte_rx#(bit[7:0], I2cByteMonitor) i2cByteRxImp;
  uvm_analysis_imp_i2c_stop_rx#(bit, I2cByteMonitor) i2cStopRxImp;
  uvm_analysis_imp_i2c_ack_rx#(ackT, I2cByteMonitor) i2cAckRxImp;
  uvm_analysis_port#(Command) i2cMsgRxPort;

  bit[7:0] rxByteQ [$];
  bit stopNext;
  Command rxMsg;
  int pendingBytes;

  `uvm_component_utils(I2cByteMonitor)

  function new(string name="bridgemonitor", uvm_component parent = null);
    super.new(name, parent);
    i2cByteRxImp = new("i2cByteRxImp", this);
    i2cAckRxImp = new("i2cAckRxImp", this);
    i2cStopRxImp = new("i2cStopRxImp", this);
    i2cMsgRxPort = new("i2cMsgRxPort", this);
  endfunction : new

  function void write_i2c_stop_rx(bit stop);
    $display("I2C_RX: received stop @%t", $time);
    if(rxMsg != null) begin
      rxMsg.length = rxMsg.data.size();
      i2cMsgRxPort.write(rxMsg);
      rxByteQ.delete();
      rxMsg = null;
    end
  endfunction

  function void write_i2c_ack_rx(ackT ack);
    $display("I2C_RX: received %s @%t",ack.name(), $time);
    if(ack == NACK) begin
      rxByteQ.pop_back();
      if(rxMsg != null) begin // TODO: invalid ack check
	rxMsg.data.pop_back();
      end
    end
  endfunction

  function void write_i2c_byte_rx(bit[7:0] msgByte);
    $display("I2C_RX: Received Byte: 0x%x @%t", msgByte, $time);
    if(rxByteQ.size() == 0) begin
      rxByteQ.push_back(msgByte);
      rxMsg = new("i2c_rx_msg");
      rxMsg.addr = msgByte[7:1];
      rxMsg.dir = directionT'(msgByte[0]);
      stopNext = 0;
    end

    else begin
      rxByteQ.push_back(msgByte);
      rxMsg.data.push_back(msgByte);
    end
  endfunction

endclass : I2cByteMonitor
