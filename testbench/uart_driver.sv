// ******************************************************
// File	       : uart_driver.sv
// Project     : UART to I2C-bus Bridge verification(SC18IM704)
//             : Part of EE273 Project (fall 2022)
//	       : Prepared by (Group: G01) (Members: Bhavin Patel, Neol Rajesh Solanki, Fabiha Roshni Khan)
// Description : UART driver class 
// ******************************************************



// ############################## 
// baud rate generator 
// ############################## 
class BaudGen;
  bit [7:0] BRG0, BRG1; 
  realtime baud, halfbaud;
  int baudVal;
  uvm_event posEdgeEvent;
  uvm_event negEdgeEvent;
  uvm_event stopEvent;
  bit clkVal = 0;
  process p;

  function new(bit [7:0] BRG0 = 'hf0, bit[7:0] BRG1 = 'h02);
    setBRG(BRG0, BRG1);
    posEdgeEvent = new("posEdgeEvent");
    negEdgeEvent = new("negEdgeEvent");
    stopEvent = new("stopEvent");
  endfunction

  function void setBRG(bit [7:0] BRG0 = 'hf0, bit[7:0] BRG1 = 'h02);
    this.BRG0 = BRG0;
    this.BRG1 = BRG1;
    baudVal = ((7.3728 * (10**6)) / (16 + {BRG1, BRG0}));
    baud = 1s / baudVal;
    halfbaud = baud/2;
    `uvm_info("BAUD", $sformatf("Baud rate set to %d (%t)", baudVal, baud), UVM_LOW)
  endfunction

  function realtime getDuration();
    return baud;
  endfunction;

  task stop(bit driveSig, ref reg clk);
    if(p != null) begin
      p.kill();
    end
    if(clkVal == 1) negEdgeEvent.trigger();
    clkVal = 0; 
    if(driveSig) clk = clkVal;

    fork
      begin
	#(baud);
	stopEvent.trigger();
      end
    join_none
  endtask

  task start(bit driveSig, ref reg clk);
    #(halfbaud);
    fork
      begin
	p = process::self();
	forever begin
	  clkVal = ~clkVal;
	  if(driveSig) clk = clkVal;
	  if(clkVal == 1) posEdgeEvent.trigger();
	  if(clkVal == 0) negEdgeEvent.trigger();
	  #(halfbaud);
	end
      end
    join_none
  endtask

endclass : BaudGen




// ############################## 
// driver class
// ############################## 
`uvm_analysis_imp_decl(_uart_ok_detected)
class UartDriver extends uvm_driver #(UartData);
  UartData uartData;
  virtual UART_interface_master vif;
  BaudGen baudGen;
  uvm_analysis_port#(Command) uartMsgTxPort;
  uvm_analysis_imp_uart_ok_detected#(bit, UartDriver) uartOkDetectedImp;
  bit [7:0] dataQ[$];
  Command msg;
  bit okDetected = 0;

  `uvm_component_utils_begin(UartDriver)
  `uvm_field_object(uartData, UVM_ALL_ON)
  `uvm_component_utils_end

  function new(string name="UartDriver", uvm_component parent = null);
    super.new(name, parent);
    baudGen = new();
    uartMsgTxPort = new("uartMsgTxPort", this);
    uartOkDetectedImp = new("uartOkDetectedImp", this);
    okDetected = 0;
  endfunction : new

  virtual function void connect_phase(uvm_phase phase);
    if (!uvm_config_db#(virtual UART_interface_master)::get(null, "", "uart_intf_master", vif))
    begin
      `uvm_error("VIF_GET_ERROR","COULD NOT GET VIF")
    end
  endfunction

  virtual function void write_uart_ok_detected(bit ok);
    okDetected = 1;
  endfunction
 
  // run phase
  task run_phase(uvm_phase phase);
    vif.TX = 1; // stop state

    // wait for initial reset
    @(posedge vif.reset);
    baudGen.stop(1, vif.deubg_uart_tx_clk);

    // wait for 'OK'
    `uvm_info("OK_DETECT_WAIT", "UART driver is waiting for 'OK' indication", UVM_LOW)
    wait(okDetected == 1);
    `uvm_info("OK_DETECT_WAIT", "UART driver received 'OK' indication, now started normal operation", UVM_LOW)

    forever begin
      seq_item_port.get_next_item(uartData); // get the sequence item from sequencer

      $display("\n\n\n\n>>>>>>>>>>>>>>>> UART Transaction STARTED <<<<<<<<<<<<<<<<\n\n");
      uartData.print();

      // convert to uart message format (section 7)
      dataQ.delete();
      dataQ.push_back(S_CHAR);
      dataQ.push_back((uartData.addr << 1 |  uartData.dir));
      dataQ.push_back(uartData.length);
      if(uartData.dir == WRITE) begin
	foreach(uartData.data[ii]) begin
	  dataQ.push_back(uartData.data[ii]);
	end
      end
      dataQ.push_back(P_CHAR);

      // send the uart format
      for(int ii = 0; ii < dataQ.size(); ii++) begin

	// start bit
	baudGen.start(1, vif.deubg_uart_tx_clk);
	baudGen.posEdgeEvent.wait_trigger();
	$display("UART_TX: sent start bit @%t", $time);
	vif.TX = 0;

	// data bits
	if(ii == 0)
	  $display("UART_TX: sending S_CHAR: 0x%x (8'b%8b) @%t", dataQ[ii], dataQ[ii], $time);
	else if(ii == 1)
	  $display("UART_TX: sending Addr + R/W byte: 0x%x (8'b%8b) @%t", dataQ[ii], dataQ[ii], $time);
	else if(ii == 2)
	  $display("UART_TX: sending Length field: %0d (8'b%8b) @%t", dataQ[ii], dataQ[ii], $time);
	else if(ii == dataQ.size() - 1)
	  $display("UART_TX: sending P_CHAR: 0x%x (8'b%8b) @%t", dataQ[ii], dataQ[ii], $time);
	else 
	  $display("UART_TX: sending %dth payload byte: 0x%x (8'b%8b) @%t", ii+1-3, dataQ[ii], dataQ[ii], $time);

	for(int jj = 0; jj < $bits(dataQ[ii]); jj++) begin
	  int msbIdx = $bits(dataQ[ii]) - jj - 1;
	  baudGen.posEdgeEvent.wait_trigger();
	  $display("UART_TX: sent %0dth-bit: %0d @%t", jj+1, dataQ[ii][jj], $time);
	  vif.TX = dataQ[ii][jj]; // Looks like DUT sends LSB first ... so driving LSB first instead of MSB
	end

	// stop bit
	baudGen.posEdgeEvent.wait_trigger();
	$display("UART_TX: sent stop bit @%t", $time);
	vif.TX = 1;
	baudGen.stop(1, vif.deubg_uart_tx_clk);

	if(ii ==  (dataQ.size() - 1)) begin // last byte of the stream
	  // send msg to scoreboard
	  msg = new("uart_tx_msg");
	  msg.data = uartData.data;
	  msg.length = uartData.length;
	  msg.addr = uartData.addr;
	  msg.dir = uartData.dir;
	  uartMsgTxPort.write(msg);
	end

	// wait for stop bauds
	baudGen.stopEvent.wait_trigger();
	$display("UART_TX: waiting for %d bauds @%t", uartData.stopBauds, $time);
	#(baudGen.getDuration() * uartData.stopBauds);
	$display("UART_TX: ended waiting for %d bauds @%t", uartData.stopBauds, $time);
      end


      seq_item_port.item_done(uartData);
      $display("\n\n<<<<<<<<<<<<<<<< UART Transaction COMPLETE >>>>>>>>>>>>>>>>\n\n\n\n");
    end 
  endtask : run_phase

endclass : UartDriver
