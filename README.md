# Verilog UART

Configurable Verilog UART transceiver with 8 data bits, 1 stop bit, and no parity. The default clock frequency is 25 MHz with a baud rate of 115200. Includes independent TX/RX modules, a top-level `uart_top` wrapper, and a testbench for RX and TX-RX loopback verification.