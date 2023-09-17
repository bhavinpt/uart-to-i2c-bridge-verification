// ******************************************************
// File	       : i2c_driver.sv
// Project     : UART to I2C-bus Bridge verification(SC18IM704)
//             : Part of EE273 Project (fall 2022)
//	       : Prepared by (Group: G01) (Members: Bhavin Patel, Neol Rajesh Solanki, Fabiha Roshni Khan, Karthik Ekke)
// Description : I2C driver class 
// ******************************************************


// ############################## 
// I2C clk rate generator
// ############################## 
class SclGen;
  bit [7:0] low, high; 
  realtime sclDelay, halfSclDelay;
  uvm_event posEdgeEvent;
  uvm_event negEdgeEvent;
  uvm_event preStopEvent;
  uvm_event stopEvent;
  process p;
  bit sclVal = 0;

  function new(bit [7:0] low = 'h13, bit[7:0] high = 'h00);
    setRate(low, high);
    posEdgeEvent = new("posEdgeEvent");
    negEdgeEvent = new("negEdgeEvent");
    preStopEvent = new("preStopEvent");
    stopEvent = new("stopEvent");
  endfunction

  function void setRate(bit [7:0] low = 'h13, bit[7:0] high = 'h00);
    real freqInHz = ( 15000000 / (8 * (low + high)));
    this.low = low;
    this.high = high;

    sclDelay = (1s/freqInHz);
    halfSclDelay = sclDelay/2;
    `uvm_info("scl", $sformatf("Scl rate set to (%t) %f Khz", sclDelay, freqInHz/1000), UVM_LOW)
  endfunction

  function realtime getRate();
    return sclDelay;
  endfunction

  task stop(bit driveSig, int clksAfterStop, ref reg scl);
    if(p != null) begin
      p.kill();
    end
    if(sclVal == 0) negEdgeEvent.trigger();
    sclVal = 1;
    if(driveSig) scl = sclVal;

    #(halfSclDelay);
    fork
      begin
	preStopEvent.trigger();
	#(sclDelay * clksAfterStop);
	stopEvent.trigger();
      end
    join_none
  endtask

  task start(bit driveSig, ref reg scl);
    fork
      begin
	p = process::self();
	forever begin
	  #(halfSclDelay);
	  sclVal = ~sclVal;
	  if(driveSig) scl = sclVal;
	  if(sclVal == 0)negEdgeEvent.trigger();
	  if(sclVal == 1)posEdgeEvent.trigger();
	end
      end
    join_none
  endtask

endclass : SclGen



// ############################## 
// I2C driver 
// ############################## 
`uvm_analysis_imp_decl(_i2c_ack_event)
class I2cDriver extends uvm_driver#(I2cData);
  I2cData i2cData;
  virtual I2C_interface_master vif;
  SclGen sclGen;
  uvm_analysis_port#(Command) i2cMsgTxPort;
  uvm_analysis_imp_i2c_ack_event#(ackT, I2cDriver) i2cAckEventImp;
  bit [7:0] dataQ[$];
  Command msg;

  `uvm_component_utils_begin(I2cDriver)
  `uvm_field_object(i2cData, UVM_ALL_ON)
  `uvm_component_utils_end

  function new(string name="I2cDriver", uvm_component parent = null);
    super.new(name, parent);
    sclGen = new();
    i2cMsgTxPort = new("i2cMsgTxPort", this);
    i2cAckEventImp = new("i2cAckEventImp", this);
  endfunction : new

  virtual function void connect_phase(uvm_phase phase);
    if (!uvm_config_db#(virtual I2C_interface_master)::get(null, "", "i2c_intf_master", vif))
    begin
      `uvm_error("VIF_GET_ERROR","COULD NOT GET VIF")
    end
  endfunction

  virtual function void write_i2c_ack_event(ackT ack);
    vif.SDA = ack;
  endfunction


  // run phase
  task run_phase(uvm_phase phase);

    // wait for initial reset
    @(negedge vif.reset);
    vif.SCL = 1;
    vif.SDA = 1;
    sclGen.stop(1,100, vif.SCL);

    forever begin
      seq_item_port.get_next_item(i2cData); 

      $display("\n\n\n\n>>>>>>>>>>>>>>>> I2C Transaction STARTED <<<<<<<<<<<<<<<<\n\n");
      i2cData.print();

      // send start
      vif.SDA = 0;
      sclGen.start(1, vif.SCL);
      $display("I2C_TX start: @%0t", $time);

      // send address + r/w
      for(int jj = ($bits(i2cData.addr) - 1); jj >= 0 ; jj--) begin
	sclGen.negEdgeEvent.wait_trigger();
	vif.SDA = i2cData.addr[jj];
	//$display("I2C_TX bit: %d @%0t", vif.SDA, $time);
      end
      sclGen.negEdgeEvent.wait_trigger();
      vif.SDA = i2cData.dir;
      $display("I2C_TX byte: 0x%0x @%0t", {i2cData.addr, i2cData.dir}, $time);

      // send ack/nack 
      sclGen.negEdgeEvent.wait_trigger();
      // vif.SDA = ACK; // managed by write_i2c_ack_event
      $display("I2C_TX %0x @%0t", "ACK", $time);


      foreach(i2cData.data[ii]) begin
	// send data byte
	for(int jj = ($bits(i2cData.data[ii]) - 1); jj >= 0 ; jj--) begin
	  sclGen.negEdgeEvent.wait_trigger();
	  vif.SDA = i2cData.data[ii][jj];
	  //$display("I2C_TX driven bit: %d @%0t", vif.SDA, $time);
	end
	$display("I2C_TX driven byte: 0x%0x @%0t", i2cData.data[ii], $time);

	// send ack/nack TODO: only ack for now
	sclGen.negEdgeEvent.wait_trigger();
	vif.SDA = ACK; 
	$display("I2C_TX driven %0x @%0t", "ACK", $time);
      end

      // send stop
      sclGen.posEdgeEvent.wait_trigger();
      $display("I2C_TX driving stop: @%0t", $time);
      sclGen.stop(1, i2cData.stopClks, vif.SCL);
      sclGen.preStopEvent.wait_trigger();
      vif.SDA = 1;

      // send msg to scoreboard
      msg = new("i2c_tx_msg");
      msg.data = i2cData.data;
      msg.length = i2cData.data.size();
      msg.addr = i2cData.addr;
      msg.dir = i2cData.dir;
      i2cMsgTxPort.write(msg);
      seq_item_port.item_done(i2cData);

      sclGen.stopEvent.wait_trigger();

      $display("\n\n<<<<<<<<<<<<<<<< I2C Transaction COMPLETE >>>>>>>>>>>>>>>>\n\n\n\n");
    end

  endtask

endclass : I2cDriver


