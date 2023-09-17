# UART to I2C Bridge Verification
In this project, I verified the basic features of SC18IM704 bridge in UVM.  
The goal was to build a UVM testbench from scratch with all the below standard components to detect bugs from an encrypted design.

- Test, Environment, Agent, Driver, Monitor
- Virtual Sequencer, Virtual Sequence
- Top, Virtual Interfaces, and reference DUT

The bridge operates in a full duplex mode, and it uses a FIFO for CDC between different speeds of I2C and UART. The test library uses UART to communicate with I2C slaves under different valid conditions such as read-after-write, baud rate update, and also error injections such as FIFO full, invalid UART format, and more. With consideration of these conditions, the scoreboard would compare the read/write responses coming in and out of the bridge to verify the functionality.

Please look into the testbench block diagrams, UVM code, test plan, and results below.

## Testbench Setup
The setup is similar to a standard UVM testbench. The virtual sequencer is used to drive both UART and I2C sides simultaneously from test sequence.

![EE273 Box Diagram-Page-2 drawio](https://github.com/bhavinpt/uart-to-i2c-bridge-verification/assets/117598876/0c48b7dd-8ac1-4d5f-b8dd-a587bf2d0bec)

This is the scoreboard compare setup. It receives Tx packets from drivers and Rx packets from the monitor to compare and check that the bridge properly transfers the packets.

![EE273 Box Diagram-Page-1 drawio](https://github.com/bhavinpt/uart-to-i2c-bridge-verification/assets/117598876/b6b7cf45-fa1a-4214-84b6-d8800b033b70)

## Task
The goal was to capture the bugs from a given encrypted DUT.

### List of checkers implemented
- [**UART_OK_ERROR**] Did not receive first byte as 'O' (0x4f). Received 0x%x
- [**UART_OK_ERROR**] Did not receive second byte as 'K' (0x4b). Received 0x%x
- [**ERR_UART_RX_PAYLOAD_OVERFLOW**] Expected payload bytes: %d, but current stream received %d more bytes
- [**ERR_I2C_INVALID_RX**] I2C sent a read/write request even when no UART read/write request was made
- [**ERR_I2C_RX_ADDR_MISMATCH**] I2C sent a read/write request with invalid address, received: 0x%0x, expected: 0x%0x
- [**ERR_I2C_RX_DIRECTION_MISMATCH**] I2C sent invalid read/write direction, received: %s, expected: %s
- [**ERR_I2C_RX_DATA_LENGTH_MISMATCH**] I2C sent a read/write request with invalid data length, received: %0d, expected: %0d
- [**ERR_I2C_RX_DATA_MISMATCH**] I2C received command has data mismatch on %0dth byte, received: 0x%x, expected: 0x%0x

### List of checkers triggered (can be found in the simulation log)

- [**ERR_I2C_INVALID_RX**] I2C sent a read/write request even when no UART read/write request was made
- [**ERR_UART_RX_PAYLOAD_OVERFLOW**] Expected payload bytes: 0, but current stream received 1 more bytes
