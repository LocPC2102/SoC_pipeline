`timescale 1ns/1ps
// AMBA 2 AHB slave; 32-bit aligned register accesses only.
module ahb_uart #(
    parameter integer DVSR = 54,
    parameter integer DVSR_BIT = 6,
    parameter integer FIFO_W = 2
)(
    input wire HCLK, input wire core_clk, output wire pmu_busy, 
    input wire HRESETn,
    input wire HSEL, 
    input wire HREADY, 
    input wire [31:0] HADDR,
    input wire [1:0] HTRANS, 
    input wire HWRITE, 
    input wire [2:0] HSIZE,
    input wire [31:0] HWDATA,
    output wire [31:0] HRDATA, 
    output wire HREADYOUT,
    output wire [1:0] HRESP,
    input wire uart_rx, 
    output wire uart_tx
);
    localparam TXDATA=4'h0, 
               RXDATA=4'h4, 
               STATUS=4'h8;
    reg valid_d, write_d;
    reg [3:0] addr_d;
    reg [1:0] err_state; // 0=OKAY, 1=first ERROR cycle, 2=second
    reg tx_wr, rx_rd;
    reg [7:0] tx_data;
    reg tx_overflow, rx_underflow;
    reg clear_rx_overrun, clear_rx_frame_error;
    wire rx_overrun, rx_frame_error;
    wire uart_busy;

    wire tx_full, rx_empty;
    wire [7:0] rx_data;
    (* ASYNC_REG = "TRUE" *) reg rx_meta, rx_sync;

    assign pmu_busy = uart_busy || tx_wr || rx_rd || clear_rx_overrun || clear_rx_frame_error || !rx_sync;
    wire invalid = (HSIZE != 3'b010) || (HADDR[11:4] != 0) || (HADDR[1:0] != 2'b00) ||
        !((HADDR[3:0] == TXDATA && HWRITE) ||
          (HADDR[3:0] == RXDATA && !HWRITE) ||
          (HADDR[3:0] == STATUS));
    assign HREADYOUT = (err_state != 1);
    assign HRESP = (err_state == 0) ? 2'b00 : 2'b01;
    assign HRDATA = !valid_d || write_d || err_state != 0 ? 32'b0 :
        addr_d == RXDATA ? (rx_empty ? 32'b0 : {24'b0,rx_data}) :
        addr_d == STATUS ? {26'b0,rx_frame_error,rx_overrun,rx_underflow,tx_overflow,rx_empty,tx_full} : 32'b0;

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            rx_meta <= 1'b1; rx_sync <= 1'b1;
        end else begin
            rx_meta <= uart_rx; rx_sync <= rx_meta;
        end
    end

    // Commands are registered on the completing HCLK edge; the UART FIFO
    // consumes them on the following falling edge. Reads expose the old head
    // throughout the completing data phase.
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            valid_d <= 0; write_d <= 0; addr_d <= 0; err_state <= 0;
            tx_wr <= 0; rx_rd <= 0; tx_data <= 0;
            tx_overflow <= 0; rx_underflow <= 0;
            clear_rx_overrun <= 0; clear_rx_frame_error <= 0;
        end else begin
            tx_wr <= 0; rx_rd <= 0;
            clear_rx_overrun <= 0; clear_rx_frame_error <= 0;
            if (HREADY && valid_d && err_state == 0) begin
                if (write_d && addr_d == TXDATA) begin
                    if (tx_full) tx_overflow <= 1;
                    else begin tx_data <= HWDATA[7:0]; tx_wr <= 1; end
                end
                if (!write_d && addr_d == RXDATA) begin
                    if (rx_empty) rx_underflow <= 1;
                    else rx_rd <= 1;
                end
                if (write_d && addr_d == STATUS) begin
                    if (HWDATA[2]) tx_overflow <= 0;
                    if (HWDATA[3]) rx_underflow <= 0;
                    if (HWDATA[4]) clear_rx_overrun <= 1;
                    if (HWDATA[5]) clear_rx_frame_error <= 1;
                end
            end
            if (err_state == 1) err_state <= 2;
            else if (HREADY) begin
                valid_d <= HSEL && HTRANS[1];
                if (HSEL && HTRANS[1]) begin
                    addr_d <= HADDR[3:0]; write_d <= HWRITE;
                    if (invalid) err_state <= 1;
                    else err_state <= 0;
                end else err_state <= 0;
            end
        end
    end
    uart #(.D_BIT(8), .SB_TICK(16), .DVSR(DVSR),
           .DVSR_BIT(DVSR_BIT), .FIFO_W(FIFO_W)) u_uart (
        .ckht(core_clk), .rst(~HRESETn), .uart_rx(rx_sync), .uart_tx(uart_tx),
        .fifo_rx_ena_rd(rx_rd), .fifo_rx_data_out(rx_data), .fifo_rx_empty(rx_empty),
        .fifo_tx_ena_wr(tx_wr), .fifo_tx_data_in(tx_data), .fifo_tx_full(tx_full),
        .clear_rx_overrun(clear_rx_overrun), .clear_rx_frame_error(clear_rx_frame_error),
        .rx_overrun(rx_overrun), .rx_frame_error(rx_frame_error), .pmu_busy(uart_busy)
    );
endmodule

