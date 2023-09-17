// ******************************************************//
// File	       : top.sv
// Project     : UART to I2C-bus Bridge verification(SC18IM704)
//             : Part of EE273 Project (fall 2022)
//	       : Prepared by (Group: G01) (Members: Bhavin Patel, Neol Rajesh Solanki, Fabiha Roshni Khan, Karthik Ekke)
// Description : Top-level verification file
// ******************************************************//

`timescale 1ns/10ps

// Uart interfaces
interface UART_interface_master (input reset,input RX, output TX, output reg deubg_uart_tx_clk);
endinterface
interface UART_interface_slave (input reset,input RX, input TX, output reg deubg_uart_rx_clk);
endinterface 

// I2c interfaces
interface I2C_interface_master (input reset, output reg SCL, output reg SDA);
endinterface 
interface I2C_interface_slave (input reset, input SCL, input SDA);
endinterface 

// Dut definition -- encrypted
`include "dut.svp"


// top level module
module top();

  reg reset;
  wire RX;
  wire TX;
  wire sSDA;
  wire sSCL;
  reg mSDA;
  reg mSCL;
  reg deubg_uart_tx_clk;
  reg deubg_uart_rx_clk;
  
  // DUT instance
  dut D0 (.reset(reset), .rx(TX), .tx(RX), .scl(sSCL), .sdatx(sSDA), .sdarx(mSDA));

  // interface instances
  UART_interface_master uart_master_intf (.TX(TX), .RX(RX), .reset(reset), .deubg_uart_tx_clk(deubg_uart_tx_clk));
  UART_interface_slave uart_slave_intf (.TX(TX), .RX(RX), .reset(reset), .deubg_uart_rx_clk(deubg_uart_rx_clk));
  I2C_interface_master i2c_master_intf (.SCL(mSCL), .SDA(mSDA), .reset(reset));
  I2C_interface_slave i2c_slave_intf (.SCL(sSCL), .SDA(sSDA), .reset(reset));
  
  // ---------------------------------------------------------------------------------
  // testbench -- components 
  // ---------------------------------------------------------------------------------
  
  import uvm_pkg::*;
  `include "types.sv"
  `include "seq_item.sv"
  `include "sequencer.sv"
  `include "uart_driver.sv"
  `include "uart_monitor.sv"
  `include "uart_agent.sv"
  `include "i2c_driver.sv"
  `include "i2c_monitor.sv"
  `include "i2c_agent.sv"
  `include "scoreboard.sv"
  `include "env.sv"
  `include "seq.sv"
  `include "test.sv"
  
  // ---------------------------------------------------------------------------------
  // top
  // ---------------------------------------------------------------------------------
  
  initial begin
    reset = 1;
    #100000 reset = 0;
    #100000 reset = 1;
  end
  
  initial begin
    $dumpfile("waves.vcd");
    $dumpvars;
    $timeformat(-9, 3, "ns", 8);
    uvm_config_db #(virtual UART_interface_master)::set(null, "*", "uart_intf_master" , uart_master_intf);
    uvm_config_db #(virtual UART_interface_slave)::set(null, "*", "uart_intf_slave" , uart_slave_intf);
    uvm_config_db #(virtual I2C_interface_master)::set(null, "*", "i2c_intf_master" , i2c_master_intf);
    uvm_config_db #(virtual I2C_interface_slave)::set(null, "*", "i2c_intf_slave" , i2c_slave_intf);
    run_test("BridgeTest");
    $finish;
  end

endmodule : top




