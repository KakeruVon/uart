`timescale 1ns/1ps
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

// ================================================================
// Clock cycles counter for baud rate generation
// For a 25MHz clock and 115200 baud rate, we need to count 217 clock cycles per bit,
// The actual boud rate is 25,000,000 / 217 = 115207.37, which is very close to 115200(0.0064% error).
// ================================================================
localparam bit_time = clk_freq / baud;
reg [$clog2(bit_time)-1:0] bit_cnt;
reg [3:0] bit_idx;

// ================================================================
// Frame register to hold the data to be received
// Garantees that the data is stable during the reception process.
// ================================================================
reg [7:0] frame;

// ================================================================
// FSM for UART reception
// States:
// - STATE_IDLE: Waiting for start bit
// - STATE_START: Waiting for a half bit time and receiving start bit (0)
// - STATE_DATA: Receiving data bits (LSB first)
// - STATE_STOP: Receiving stop bit (1)
// ================================================================
reg [1:0] state;
localparam STATE_IDLE = 2'd0;
localparam STATE_START = 2'd1;
localparam STATE_DATA = 2'd2;
localparam STATE_STOP = 2'd3;

initial begin
    rx_valid = 1'b0;
    rx_data = 8'd0;
    state = STATE_IDLE;
    bit_cnt <= 16'd0;
    bit_idx <= 4'd0;
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        rx_valid <= 1'b0;
        rx_data <= 8'd0;
        state <= STATE_IDLE;
        bit_cnt <= 16'd0;
        bit_idx <= 4'd0;
    end else begin
        case (state)
            STATE_IDLE: begin
                if (rx == 1'b0) begin // Start bit detected
                    state <= STATE_START;
                    bit_cnt <= 16'd0;
                    bit_idx <= 4'd0;
                    rx_valid <= 1'b0;
                end else if (rx_valid) begin
                    rx_valid <= 1'b0; // Clear rx_valid after 1 clock cycle
                end
            end
            STATE_START: begin
                if (bit_cnt < bit_time / 2 - 1) begin
                    if (rx == 1'b0) begin
                        bit_cnt <= bit_cnt + 1; // Wait for half bit time to sample in the middle of the start bit
                    end else begin
                        bit_cnt <= 16'd0;
                        state <= STATE_IDLE; // False start bit, go back to idle
                    end
                end else begin
                    bit_cnt <= 16'd0;
                    state <= STATE_DATA;
                end
            end
            STATE_DATA: begin
                if (bit_cnt < bit_time - 1) begin
                    bit_cnt <= bit_cnt + 1;
                end else begin
                    bit_cnt <= 16'd0;
                    frame[bit_idx] <= rx; // Sample data bit
                    if (bit_idx < 7) begin
                        bit_idx <= bit_idx + 1;
                    end else begin
                        bit_idx <= 4'd0;
                        state <= STATE_STOP;
                    end
                end
            end
            STATE_STOP: begin
                if (bit_cnt < bit_time - 1) begin
                    bit_cnt <= bit_cnt + 1;
                end else begin
                    bit_cnt <= 16'd0;
                    if (rx == 1'b1) begin // Stop bit should be high
                        rx_data <= frame; // Capture received data
                        rx_valid <= 1'b1; // Indicate valid data received
                    end
                    state <= STATE_IDLE;
                end
            end
        endcase
    end
end

endmodule