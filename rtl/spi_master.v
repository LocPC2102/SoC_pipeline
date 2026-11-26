`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/27/2026 02:46:38 PM
// Design Name: 
// Module Name: spi_master
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module spi_master #(
    parameter CLK_DIV = 4       // sclk = sys_clk / (2*CLK_DIV)
)(
    input  wire       clk,
    input  wire       rst,
 
    // User interface
    input  wire       start,        // pulse high 1 cycle to begin
    input  wire [7:0] tx_data,      // byte to send
    output reg  [7:0] rx_data,      // byte received
    output reg        busy,         // 1 while transferring
    output reg        done,         // 1-cycle pulse when done
 
    // SPI pins
    output reg        sclk,
    output reg        cs_n,         // active LOW
    output reg        mosi,
    input  wire       miso
);
 
    // ---- Internal signals ----
    reg [7:0] shift_tx;             // shift register for TX
    reg [7:0] shift_rx;             // shift register for RX
    reg [2:0] bit_cnt;              // counts 0..7
    reg [7:0] clk_cnt;              // clock divider counter
    reg       clk_en;               // enable clock toggle
 
    // ---- States ----
    localparam IDLE     = 2'd0;
    localparam TRANSFER = 2'd1;
    localparam FINISH   = 2'd2;
 
    reg [1:0] state;
 
    // ---- FSM ----
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state    <= IDLE;
            sclk     <= 0;
            cs_n     <= 1;
            mosi     <= 0;
            busy     <= 0;
            done     <= 0;
            clk_cnt  <= 0;
            bit_cnt  <= 7;
            shift_tx <= 0;
            shift_rx <= 0;
            rx_data  <= 0;
            clk_en   <= 0;
        end else begin
            done <= 0; // default: not done
 
            case (state)
                // ---- IDLE: wait for start ----
                IDLE: begin
                    sclk    <= 0;
                    cs_n    <= 1;
                    clk_cnt <= 0;
                    bit_cnt <= 7;
                    clk_en  <= 0;
 
                    if (start) begin
                        shift_tx <= tx_data;
                        busy     <= 1;
                        cs_n     <= 0;          // assert CS
                        mosi     <= tx_data[7]; // put MSB on MOSI
                        state    <= TRANSFER;
                    end
                end
 
                // ---- TRANSFER: generate SCLK, shift bits ----
                TRANSFER: begin
                    clk_cnt <= clk_cnt + 1;
 
                    if (clk_cnt == CLK_DIV - 1) begin
                        clk_cnt <= 0;
                        sclk    <= ~sclk; // toggle SCLK
 
                        // Rising edge: sample MISO
                        if (sclk == 0) begin
                            shift_rx <= {shift_rx[6:0], miso};
                        end
 
                        // Falling edge: shift out next MOSI
                        if (sclk == 1) begin
                            if (bit_cnt == 0) begin
                                // Last bit done
                                state <= FINISH;
                            end else begin
                                bit_cnt  <= bit_cnt - 1;
                                shift_tx <= {shift_tx[6:0], 1'b0};
                                mosi     <= shift_tx[6]; // next bit
                            end
                        end
                    end
                end
 
                // ---- FINISH: deassert CS, latch rx_data ----
                FINISH: begin
                    sclk    <= 0;
                    cs_n    <= 1;
                    busy    <= 0;
                    done    <= 1;
                    rx_data <= shift_rx;
                    bit_cnt <= 7;
                    state   <= IDLE;
                end
 
                default: state <= IDLE;
            endcase
        end
    end
 
endmodule

