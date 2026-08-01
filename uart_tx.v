module uart_tx #(
    parameter clk_freq = 25_000_000,
    parameter baud = 115200
) (
    input wire clk,
    input wire rst,
    input wire tx_valid,
    input wire [7:0] tx_data,
    output reg tx_busy,
    output reg tx
);

parameter bit_time = clk_freq / baud;
reg [15:0] bit_cnt;
reg [3:0] bit_idx;
reg [7:0] frame;

reg [1:0] state;
parameter STATE_IDLE = 2'd0;
parameter STATE_START = 2'd1;
parameter STATE_DATA = 2'd2;
parameter STATE_STOP = 2'd3;

initial begin
    tx_busy = 1'b0;
    tx = 1'b1;
    state = STATE_IDLE;
    bit_cnt <= 16'd0;
    bit_idx <= 4'd0;
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        tx_busy <= 1'b0;
        tx <= 1'b1;
        state <= STATE_IDLE;
        bit_cnt <= 16'd0;
        bit_idx <= 4'd0;
    end else begin
        case (state)
            STATE_IDLE: begin
                if (tx_valid) begin
                    frame <= tx_data;
                    tx_busy <= 1'b1;
                    bit_cnt <= 16'd0;
                    bit_idx <= 4'd0;
                    state <= STATE_START;
                end
            end
            STATE_START: begin
                if (bit_cnt < bit_time) begin
                    bit_cnt <= bit_cnt + 1;
                end else begin
                    tx <= 1'b0; // Start bit
                    bit_idx <= 4'd0;
                    bit_cnt <= 16'd0;
                    state <= STATE_DATA;
                end
            end
            STATE_DATA: begin
                if (bit_cnt < bit_time) begin
                    bit_cnt <= bit_cnt + 1;
                end else begin
                    tx <= frame[bit_idx];
                    bit_idx <= bit_idx + 1;
                    bit_cnt <= 16'd0;
                    if (bit_idx == 7) begin // All bits sent
                        state <= STATE_STOP;
                    end
                end
            end
            STATE_STOP: begin
                if (bit_cnt < bit_time) begin
                    bit_cnt <= bit_cnt + 1;
                end else begin
                    tx_busy <= 1'b0;
                    tx <= 1'b1; // Idle state is high
                    state <= STATE_IDLE;
                end
            end
            default: begin
                tx_busy <= 1'b0;
                tx <= 1'b1;
                state <= STATE_IDLE;
                bit_cnt <= 16'd0;
                bit_idx <= 4'd0;
            end
        endcase
    end
end
endmodule