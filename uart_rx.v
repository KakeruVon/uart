module uart_rx #(
    parameter clk_freq = 25_000_000,
    parameter baud = 115200
) (
    input wire clk,
    input wire rst,
    input wire rx,
    output reg rx_valid,
    output reg [7:0] rx_data
);

endmodule