// ******************************************************
// File	       : scoreaboard.sv
// Project     : UART to I2C-bus Bridge verification(SC18IM704)
//             : Part of EE273 Project (fall 2022)
//	       : Prepared by (Group: G01) (Members: Bhavin Patel, Neol Rajesh Solanki, Fabiha Roshni Khan, Karthik Ekke)
// Description : Contains all the scoreboards
// ******************************************************

// ############################## 
// scoreboard class : waits for initial OK
// ############################## 
`uvm_analysis_imp_decl(_uart_ok_byte_rx)
class UartOkScoreboard extends uvm_scoreboard;
  bit okChecked = 0;
  bit receivedFirst = 0;
  bit receivedSecond = 0;
  uvm_analysis_imp_uart_ok_byte_rx#(bit[7:0], UartOkScoreboard) uartOkByteRxImp;
  uvm_analysis_port#(bit[7:0]) uartAfterOkByteRxPort;
  uvm_analysis_port#(bit) uartOkDetectedPort;

  `uvm_component_utils_begin(UartOkScoreboard)
  `uvm_component_utils_end

  function new(string name="UartOkScoreboard", uvm_component parent = null);
    super.new(name, parent);
    uartOkByteRxImp = new("uartOkByteRxImp", this);
    uartAfterOkByteRxPort = new("uartAfterOkByteRxPort", this);
    uartOkDetectedPort = new("uartOkDetectedPort", this);
  endfunction : new

  function void write_uart_ok_byte_rx(bit[7:0] msgByte);
    if(!okChecked) begin
      if( ! receivedFirst) begin
	if(msgByte != 'h4f) begin // O
	  `uvm_error("UART_OK_ERROR", $sformatf("Did not receive first byte as 'O' (0x4f). Received 0x%x", msgByte))
	end
	else begin
	  receivedFirst = 1;
	end
      end
      else if( ! receivedSecond) begin // K
	if(msgByte != 'h4b) begin
	  `uvm_error("UART_OK_ERROR", $sformatf("Did not receive second byte as 'K' (0x4b). Received 0x%x", msgByte))
	end
	else begin
	  `uvm_info("UART_OK_CHECK", $sformatf("Received 'OK' sequence"), UVM_LOW)
	  uartOkDetectedPort.write(1);
	  receivedSecond = 1;
	  okChecked = 1;
	end
      end
    end
    else begin
      uartAfterOkByteRxPort.write(msgByte);
    end
  endfunction

endclass : UartOkScoreboard


// ############################## 
// scoreboard class : collects series of bytes after 'OK' 
// ############################## 
`uvm_analysis_imp_decl(_uart_byte_after_ok_rx)
`uvm_analysis_imp_decl(_uart_expected_byte_rx)
class UartByteScoreboard extends uvm_scoreboard;
  uvm_analysis_imp_uart_byte_after_ok_rx#(bit[7:0], UartByteScoreboard) uartAfterOkByteRxImp;
  uvm_analysis_imp_uart_expected_byte_rx#(int, UartByteScoreboard) uartExpectedByteRxImp;
  uvm_analysis_port#(Command) uartMsgRxPort;

  Command rxMsg;
  int expectedBytes = 0;
  int pendingBytes = 0;

  `uvm_component_utils(UartByteScoreboard)

  function new(string name="UartByteScoreboard", uvm_component parent = null);
    super.new(name, parent);
    uartAfterOkByteRxImp = new("uartAfterOkByteRxImp", this);
    uartExpectedByteRxImp = new("uartExpectedByteRxImp", this);
    uartMsgRxPort = new("uartMsgRxPort", this);
  endfunction : new

  function void write_uart_expected_byte_rx(int expectedBytes);
    this.expectedBytes = expectedBytes;
  endfunction

  function void write_uart_byte_after_ok_rx(bit[7:0] msgByte);

    if(rxMsg == null) begin
      rxMsg = new("uart_rx_msg");
      rxMsg.addr = 0;
      rxMsg.dir = READ;
      rxMsg.data.push_back(msgByte);
      pendingBytes = expectedBytes;
    end

    else begin
      rxMsg.data.push_back(msgByte);
      if(pendingBytes == 0) begin
	uartMsgRxPort.write(rxMsg);
	rxMsg = null;
	pendingBytes = 0;
	expectedBytes = 0;
	return;
      end
    end

    pendingBytes--;
    if(pendingBytes < 0) begin
      `uvm_error("ERR_UART_RX_PAYLOAD_OVERFLOW", $sformatf("Expected payload bytes: %d, but current stream received %d more bytes", expectedBytes, pendingBytes * -1))
    end

  endfunction

endclass :UartByteScoreboard 


// ############################## 
// scoreboard class : Compares Tx/Rx sent and received from Uart and I2c sides 
// ############################## 
`uvm_analysis_imp_decl(_uart_msg_tx)
`uvm_analysis_imp_decl(_uart_msg_rx)
`uvm_analysis_imp_decl(_i2c_msg_tx)
`uvm_analysis_imp_decl(_i2c_msg_rx)
class BridgeScoreboard extends uvm_scoreboard;
  uvm_analysis_imp_uart_msg_tx #(Command, BridgeScoreboard) uartMsgTxImp;
  uvm_analysis_imp_uart_msg_rx #(Command, BridgeScoreboard) uartMsgRxImp;
  uvm_analysis_imp_i2c_msg_tx #(Command, BridgeScoreboard) i2cMsgTxImp;
  uvm_analysis_imp_i2c_msg_rx #(Command, BridgeScoreboard) i2cMsgRxImp;

  Command uartMsgTxQ[$];
  Command uartMsgRxQ[$];
  Command i2cMsgTxQ[$];
  Command i2cMsgRxQ[$];

  `uvm_component_utils_begin(BridgeScoreboard)
  `uvm_component_utils_end

  function new(string name = "", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uartMsgTxImp = new("uartMsgTxImp", this);
    uartMsgRxImp = new("uartMsgRxImp", this);    
    i2cMsgTxImp = new("i2cMsgTxImp", this);
    i2cMsgRxImp = new("i2cMsgRxImp", this);    
  endfunction : build_phase

  function void uartCheck(Command txCmd, Command rxCmd);
    bit error = 0;
    if(txCmd == null) begin
      `uvm_error("ERR_I2C_INVALID_RX", "I2C sent a read/write request even when no UART read/write request was made")
      error = 1;
    end
    else begin
      // addr check
      if(rxCmd.addr != txCmd.addr) begin
	`uvm_error("ERR_I2C_RX_ADDR_MISMATCH", $sformatf("I2C sent a read/write request with invalid address, received: 0x%0x, expected: 0x%0x", rxCmd.addr, txCmd.addr))
	error = 1;
      end

      // dir check
      if(rxCmd.dir != txCmd.dir) begin
	`uvm_error("ERR_I2C_RX_DIRECTION_MISMATCH", $sformatf("I2C sent invalid read/write direction, received: %s, expected: %s", rxCmd.dir.name(), txCmd.dir.name()))
	error = 1;
      end

      // data check
      if(rxCmd.data.size() != txCmd.data.size()) begin
	`uvm_error("ERR_I2C_RX_DATA_LENGTH_MISMATCH", $sformatf("I2C sent a read/write request with invalid data length, received: %0d, expected: %0d", rxCmd.data.size(), txCmd.data.size()))
	error = 1;
      end
      else begin
	foreach(rxCmd.data[ii]) begin
	  if(rxCmd.data.size() != txCmd.data.size()) begin
	    `uvm_error("ERR_I2C_RX_DATA_MISMATCH", $sformatf("I2C received command has data mismatch on %0dth byte, received: 0x%x, expected: 0x%0x", ii, rxCmd.data[ii], txCmd.data[ii]))
	    error = 1;
	  end
	end
      end
    end

    if(!error) begin
      `uvm_info("UART_SCOREBOARD", $sformatf("UART read/write request with address:0x%x was properly handed over to the I2C by the bridge", rxCmd.addr), UVM_LOW)
    end

  endfunction

  function Command cloneCmd(Command cmd);
    uvm_object obj = cmd.clone();
    Command clone = new();
    $cast(obj, clone);
    return clone;
  endfunction

  virtual function void write_uart_msg_tx(Command msg);
    $display("\n\n");
    $display("--------------------------------------");
    $display("------ SCOREBOARD: Tx Uart Msg -------");
    msg.print();
    uartMsgTxQ.push_back(cloneCmd(msg));
  endfunction 

  virtual function void write_uart_msg_rx(Command msg);
    $display("\n\n");
    $display("--------------------------------------");
    $display("------ SCOREBOARD: Rx Uart Msg -------");
    msg.print();
    uartMsgRxQ.push_back(cloneCmd(msg));
  endfunction 

  virtual function void write_i2c_msg_tx(Command msg);
    $display("\n\n");
    $display("--------------------------------------");
    $display("------ SCOREBOARD: Tx I2c Msg -------");
    msg.print();
    i2cMsgTxQ.push_back(cloneCmd(msg));
  endfunction 

  virtual function void write_i2c_msg_rx(Command msg);
    $display("\n\n");
    $display("--------------------------------------");
    $display("------ SCOREBOARD: Rx I2c Msg -------");
    msg.print();
    i2cMsgTxQ.push_back(cloneCmd(msg));
    uartCheck(uartMsgTxQ.pop_front(), i2cMsgTxQ.pop_front());
  endfunction 

endclass : BridgeScoreboard



// ############################## 
// Top level scoreboard class
// ############################## 
`uvm_analysis_imp_decl(_top_uart_msg_tx)
`uvm_analysis_imp_decl(_top_uart_byte_rx)
`uvm_analysis_imp_decl(_top_i2c_msg_tx)
`uvm_analysis_imp_decl(_top_i2c_msg_rx)
class ScoreboardTop extends uvm_scoreboard;
  BridgeScoreboard bridgeScoreboard;
  UartOkScoreboard uartOkScoreboard;
  UartByteScoreboard uartByteScoreboard;

  uvm_analysis_imp_top_uart_msg_tx #(Command, ScoreboardTop) uartMsgTxTopImp;
  uvm_analysis_imp_top_uart_byte_rx #(bit[7:0], ScoreboardTop) uartByteRxTopImp;
  uvm_analysis_imp_top_i2c_msg_tx #(Command, ScoreboardTop) i2cMsgTxTopImp;
  uvm_analysis_imp_top_i2c_msg_rx #(Command, ScoreboardTop) i2cMsgRxTopImp;

  uvm_analysis_port #(Command) uartMsgTxTopPort;
  uvm_analysis_port #(bit[7:0]) uartByteRxTopPort;
  uvm_analysis_port #(Command) i2cMsgTxTopPort;
  uvm_analysis_port #(Command) i2cMsgRxTopPort;


  `uvm_component_utils_begin(ScoreboardTop)
  `uvm_component_utils_end

  function new(string name = "", uvm_component parent = null);
    super.new(name, parent);

    uartMsgTxTopImp = new("uartMsgTxTopImp", this);
    uartByteRxTopImp = new("uartByteRxTopImp", this);   
    i2cMsgTxTopImp = new("i2cMsgTxTopImp", this);
    i2cMsgRxTopImp = new("i2cMsgRxTopImp", this);   

    uartMsgTxTopPort = new("uartMsgTxTopPort", this);
    uartByteRxTopPort = new("uartByteRxTopPort", this);   
    i2cMsgTxTopPort = new("i2cMsgTxTopPort", this);
    i2cMsgRxTopPort = new("i2cMsgRxTopPort", this);   
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    bridgeScoreboard = BridgeScoreboard::type_id::create("bridgeScoreboard", this);
    uartOkScoreboard= UartOkScoreboard::type_id::create("uartOkScoreboard", this);
    uartByteScoreboard= UartByteScoreboard::type_id::create("UartByteScoreboard", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    i2cMsgTxTopPort.connect(bridgeScoreboard.i2cMsgTxImp);


    // uart connections
    // tx
    uartMsgTxTopPort.connect(bridgeScoreboard.uartMsgTxImp);
    // rx
    uartByteRxTopPort.connect(uartOkScoreboard.uartOkByteRxImp);
    uartOkScoreboard.uartAfterOkByteRxPort.connect(uartByteScoreboard.uartAfterOkByteRxImp);
    uartByteScoreboard.uartMsgRxPort.connect(bridgeScoreboard.uartMsgRxImp);

    // i2c connection
    // tx
    i2cMsgRxTopPort.connect(bridgeScoreboard.i2cMsgRxImp);
    // rx
  endfunction


  virtual function void write_top_uart_msg_tx(Command cmd);
    uartMsgTxTopPort.write(cmd);
  endfunction

  virtual function void write_top_uart_byte_rx(bit[7:0] msgByte);
    uartByteRxTopPort.write(msgByte);
  endfunction

  virtual function void write_top_i2c_msg_tx(Command cmd);
    i2cMsgTxTopPort.write(cmd);
  endfunction

  virtual function void write_top_i2c_msg_rx(Command cmd);
    i2cMsgRxTopPort.write(cmd);
  endfunction

endclass : ScoreboardTop 

