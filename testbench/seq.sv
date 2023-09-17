// ******************************************************
// File	       : seq.sv
// Project     : UART to I2C-bus Bridge verification(SC18IM704)
//             : Part of EE273 Project (fall 2022)
//	       : Prepared by (Group: G01) (Members: Bhavin Patel, Neol Rajesh Solanki, Fabiha Roshni Khan, Karthik Ekke)
// Description : test sequences (including base sequences and virtual sequences) 
// ******************************************************



// ############################## 
// Base Uart sequence class
// ############################## 
class UartSequence extends uvm_sequence#(UartData);
  UartData uartData;
  UartData uartDataRx;
  rand directionT seqDir;
  rand bit[7:0] seqData[$];
  rand int seqLength;
  rand int seqStopBauds;
  rand bit[6:0] seqAddr;

  `uvm_declare_p_sequencer(BridgeVirtualSequencer)

  `uvm_object_utils_begin(UartSequence)
    `uvm_field_object(uartData, UVM_ALL_ON)
    `uvm_field_object(uartDataRx, UVM_ALL_ON)
    `uvm_field_enum(directionT, seqDir, UVM_ALL_ON)
    `uvm_field_queue_int(seqData, UVM_ALL_ON)
    `uvm_field_int(seqLength, UVM_ALL_ON)
    `uvm_field_int(seqStopBauds, UVM_ALL_ON)
    `uvm_field_int(seqAddr, UVM_ALL_ON)
  `uvm_object_utils_end


  function new(string name="BridgeSequence");
    super.new(name);
  endfunction : new

  task pre_body();
    // raise objection if started as a root sequence
    if(starting_phase != null)
      starting_phase.raise_objection(this);
  endtask

  task post_body();
    // drop objection if started as a root sequence
    if(starting_phase != null)
      starting_phase.drop_objection(this);
  endtask

  ///////////////// Constraints ////////////////
  constraint data_co{
    seqDir == READ -> soft seqData.size() == 0;
    seqDir == READ -> soft seqLength inside {[1:100]}; // some default random read length 

    seqDir == WRITE -> soft seqData.size() inside {[1:100]}; // default size
    seqDir == WRITE -> soft seqLength == seqData.size(); // length automatically adjusts to provided payload by default
  }

  constraint baud_co{
    soft seqStopBauds inside {[0:15]};
  }

  constraint order_co{
    solve seqDir before seqData.size();
    solve seqData.size() before seqLength;
  }

  ///////////////// Body ////////////////
  task body();
    fork : U1
      begin
	`uvm_do_on_with(uartData, p_sequencer.uartSeqr,
	{ 
	  dir == seqDir;
	  addr == seqAddr;
	  data.size() == seqData.size;  // number of bytes
	  stopBauds == seqStopBauds;
	  length == seqLength;
	})
	get_response(uartDataRx);
      end
      begin
	# 10s;
	`uvm_fatal("WATCHDOG_TIMEOUT", "Uart-Seq")
      end
    join_any
    disable U1;
  endtask

endclass : UartSequence





// ############################## 
// Base I2c sequence class
// ############################## 

class I2cSequence extends uvm_sequence#(I2cData);
  I2cData i2cData;
  I2cData i2cDataRx;
  rand bit[7:0] seqData[$];
  rand directionT seqDir;
  rand int seqStopClks;
  rand bit[6:0] seqAddr;

  `uvm_declare_p_sequencer(BridgeVirtualSequencer)

  `uvm_object_utils_begin(I2cSequence)
    `uvm_field_object(i2cData, UVM_ALL_ON)
    `uvm_field_object(i2cDataRx, UVM_ALL_ON)
    `uvm_field_enum(directionT, seqDir, UVM_ALL_ON)
    `uvm_field_queue_int(seqData, UVM_ALL_ON)
    `uvm_field_int(seqStopClks, UVM_ALL_ON)
    `uvm_field_int(seqAddr, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name="BridgeSequence");
    super.new(name);
  endfunction : new

  task pre_body();
    // raise objection if started as a root sequence
    if(starting_phase != null)
      starting_phase.raise_objection(this);
  endtask

  task post_body();
    // drop objection if started as a root sequence
    if(starting_phase != null)
      starting_phase.drop_objection(this);
  endtask


  ///////////////// Constraints ////////////////
  constraint data_co{
    soft seqData.size() inside {[1:100]}; // default size
    soft seqStopClks inside {[0:100]};
  }

  ///////////////// Body ////////////////
  task body();
    fork : U1
      begin
	`uvm_do_on_with(i2cData, p_sequencer.i2cSeqr,
	{ 
	  dir == seqDir;
	  addr == seqAddr;
	  data.size() == seqData.size();  // number of bytes
	  stopClks == seqStopClks;
	})
	get_response(i2cDataRx);
      end
      begin
	#1s;
	`uvm_fatal("WATCHDOG_TIMEOUT", "I2c-Seq")
      end
    join_any
    disable U1;
  endtask

endclass




// ############################## 
// Virtual sequence #1
// ############################## 
class BridgeSequence extends uvm_sequence;
  UartSequence uartSeq;
  I2cSequence i2cSeq;

  `uvm_object_utils_begin(BridgeSequence)
  `uvm_field_object(uartSeq, UVM_ALL_ON)
  `uvm_field_object(i2cSeq, UVM_ALL_ON)
  `uvm_object_utils_end

  `uvm_declare_p_sequencer(BridgeVirtualSequencer)

  function new(string name="BridgeSequence");
    super.new(name);
  endfunction : new

  task pre_body();
    // raise objection if started as a root sequence
    if(starting_phase != null)
      starting_phase.raise_objection(this);
  endtask

  task post_body();
    // drop objection if started as a root sequence
    if(starting_phase != null)
      starting_phase.drop_objection(this);
  endtask

  task body();

    repeat(2) begin
      $display("------- SEQ 1 --------");
      `uvm_do_with(uartSeq,
      { 
	seqDir == WRITE;
	seqData.size() inside {[10:20]}; 
	seqStopBauds inside {[10:20]};
	seqAddr == 'h52;
      })

      `uvm_do_with(uartSeq,
      { 
	seqDir == READ;
	seqAddr == 'h52;
	seqLength inside {[5:10]};
	seqStopBauds inside {[10:20]};
      })
    end

    // TODO: write response
    //repeat(1) begin
    //  $display("------- SEQ 2 --------");

    //  `uvm_do_with(i2cSeq, 
    //  { 
    //    seqData.size() inside {[10:20]}; 
    //    seqStopClks inside {[10:20]};
    //  })
    //end


    #250000; // drain time

  endtask : body

endclass : BridgeSequence


// TODO: Add more sequences 
//     	 Read after write, write after write, read after read, write after read
// 	 Write to internal registers
//	 Read internal registers
