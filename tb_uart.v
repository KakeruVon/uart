`timescale 1ns/1ps

module tb_uart;
    localparam CLK_FREQ = 1_000_000;
    localparam BAUD     = 100_000;
    localparam BIT_TIME = CLK_FREQ / BAUD;
    localparam CLK_HALF = 5;

    reg clk;
    reg rst;

    reg        rx_line;
    wire       rx_valid;
    wire [7:0] rx_data;

    reg        top_tx_valid;
    reg  [7:0] top_tx_data;
    wire       top_tx_busy;
    wire       top_tx;
    wire       top_rx_valid;
    wire [7:0] top_rx_data;

    integer error_count;

    uart_rx #(
        .clk_freq(CLK_FREQ),
        .baud(BAUD)
    ) dut_rx (
        .clk(clk),
        .rst(rst),
        .rx(rx_line),
        .rx_valid(rx_valid),
        .rx_data(rx_data)
    );

    uart_top #(
        .clk_freq(CLK_FREQ),
        .baud(BAUD)
    ) dut_top (
        .clk(clk),
        .rst(rst),
        .tx_valid(top_tx_valid),
        .tx_data(top_tx_data),
        .tx_busy(top_tx_busy),
        .tx(top_tx),
        .rx(top_tx),
        .rx_valid(top_rx_valid),
        .rx_data(top_rx_data)
    );

    initial begin
        clk = 1'b0;
        forever #CLK_HALF clk = ~clk;
    end

    task tick;
        input integer cycles;
        integer i;
        begin
            for (i = 0; i < cycles; i = i + 1) begin
                @(posedge clk);
            end
        end
    endtask

    task apply_reset;
        begin
            rst = 1'b1;
            rx_line = 1'b1;
            top_tx_valid = 1'b0;
            top_tx_data = 8'h00;
            tick(5);
            rst = 1'b0;
            tick(2);
        end
    endtask

    task drive_uart_byte;
        input [7:0] data;
        integer i;
        begin
            rx_line = 1'b1;
            tick(2);

            rx_line = 1'b0;          // start bit
            tick(BIT_TIME);

            for (i = 0; i < 8; i = i + 1) begin
                rx_line = data[i];   // data bits, LSB first
                tick(BIT_TIME);
            end

            rx_line = 1'b1;          // stop bit
            tick(BIT_TIME);
            tick(2);
        end
    endtask

    task wait_for_direct_rx_valid;
        input integer timeout_cycles;
        output [7:0] got_data;
        integer cycles;
        begin
            cycles = 0;
            got_data = 8'hxx;
            while ((rx_valid !== 1'b1) && (cycles < timeout_cycles)) begin
                @(posedge clk);
                cycles = cycles + 1;
            end

            if (rx_valid === 1'b1) begin
                got_data = rx_data;
            end else begin
                $display("[%0t] FAIL: uart_rx timed out waiting for rx_valid", $time);
                error_count = error_count + 1;
            end
        end
    endtask

    task wait_for_top_rx_valid;
        input integer timeout_cycles;
        output [7:0] got_data;
        integer cycles;
        begin
            cycles = 0;
            got_data = 8'hxx;
            while ((top_rx_valid !== 1'b1) && (cycles < timeout_cycles)) begin
                @(posedge clk);
                cycles = cycles + 1;
            end

            if (top_rx_valid === 1'b1) begin
                got_data = top_rx_data;
            end else begin
                $display("[%0t] FAIL: uart_top loopback timed out waiting for rx_valid", $time);
                error_count = error_count + 1;
            end
        end
    endtask

    task expect_direct_rx_byte;
        input [7:0] expected;
        reg [7:0] got;
        begin
            fork
                drive_uart_byte(expected);
                wait_for_direct_rx_valid(12 * BIT_TIME, got);
            join

            if (got !== expected) begin
                $display("[%0t] FAIL: uart_rx expected 0x%02h, got 0x%02h", $time, expected, got);
                error_count = error_count + 1;
            end else begin
                $display("[%0t] PASS: uart_rx received 0x%02h", $time, got);
            end
        end
    endtask

    task send_top_byte;
        input [7:0] data;
        begin
            @(posedge clk);
            top_tx_data = data;
            top_tx_valid = 1'b1;
            @(posedge clk);
            top_tx_valid = 1'b0;
        end
    endtask

    task expect_top_loopback_byte;
        input [7:0] expected;
        reg [7:0] got;
        begin
            send_top_byte(expected);
            wait_for_top_rx_valid(25 * BIT_TIME, got);

            if (got !== expected) begin
                $display("[%0t] FAIL: uart_top loopback expected 0x%02h, got 0x%02h", $time, expected, got);
                error_count = error_count + 1;
            end else begin
                $display("[%0t] PASS: uart_top loopback received 0x%02h", $time, got);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_uart.vcd");
        $dumpvars(0, tb_uart);

        error_count = 0;
        apply_reset();

        expect_direct_rx_byte(8'ha5);

        apply_reset();
        expect_top_loopback_byte(8'h3c);

        tick(5);
        if (error_count == 0) begin
            $display("[%0t] TEST PASSED", $time);
            $finish;
        end else begin
            $display("[%0t] TEST FAILED with %0d error(s)", $time, error_count);
            $fatal(1);
        end
    end
endmodule
