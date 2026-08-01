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
parameter bit_time = clk_freq / baud;
reg [15:0] bit_cnt;
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
// - STATE_DATA: Receiving data bits (LSB first)
// - STATE_STOP: Receiving stop bit (1)
// ================================================================
reg [1:0] state;
parameter STATE_IDLE = 2'd0;
parameter STATE_DATA = 2'd1;
parameter STATE_STOP = 2'd2;

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
                    state <= STATE_DATA;
                    bit_cnt <= 16'd0;
                    bit_idx <= 4'd0;
                    rx_valid <= 1'b0;
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
                        state <= STATE_STOP;
                    end
                end
            end
            STATE_STOP: begin
                if (bit_cnt < bit_time - 1) begin
                    bit_cnt <= bit_cnt + 1;
                end else begin
                    rx_valid <= 1'b1; // Data reception complete
                    rx_data <= frame; // Output received data
                    state <= STATE_IDLE;
                end
            end
        endcase
    end
end

endmodule