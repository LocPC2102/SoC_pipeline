`timescale 1ns / 1ps
module uart_controller_rx #(
    parameter D_BIT   = 8, 
    parameter SB_TICK = 16 
)(
    input  wire                 ckht,        
    input  wire                 rst,          
    input  wire                 rx,           
    input  wire                 s_tick,      
    output reg                  rx_done_tick,
    output reg                  frame_error_tick,
    output wire                 pmu_active,
    output wire [D_BIT-1:0]     rx_data    
);
    localparam [2:0] idle  = 3'd0,
                     start = 3'd1,
                     data  = 3'd2,
                     stop  = 3'd3,
                     recover = 3'd4;
                     
    reg [2:0]         state_r, state_n;
    assign pmu_active = (state_r != idle);
    reg [3:0]         s_r, s_n;  
    reg [2:0]         n_r, n_n;       
    reg [D_BIT-1:0]   b_r, b_n; 
    
    always @(negedge ckht or posedge rst) begin
        if (rst == 1'b1) begin
            state_r <= idle;
            s_r     <= 4'b0000;
            n_r     <= 3'b000;
            b_r     <= {D_BIT{1'b0}};
        end
        else begin
            state_r <= state_n;
            s_r     <= s_n;
            n_r     <= n_n;
            b_r     <= b_n;
        end
    end
    
    always @(*) begin
        state_n      = state_r;
        s_n          = s_r;
        n_n          = n_r;
        b_n          = b_r;
        rx_done_tick = 1'b0;
        frame_error_tick = 1'b0;
        
        case (state_r)
            idle: begin
                if (rx == 1'b0) begin      
                    state_n = start;
                    s_n     = 4'b0000;      
                end
            end
            start: begin
                if (s_tick == 1'b1) begin
                    if (s_r == 4'd7) begin  
                        state_n = rx ? idle : data;
                        s_n     = 4'b0000;
                        n_n     = 3'b000;   
                    end
                    else begin
                        s_n = s_r + 1'b1;
                    end
                end
            end
            data: begin
                if (s_tick == 1'b1) begin
                    if (s_r == 4'd15) begin             
                        s_n = 4'b0000;
                        b_n = {rx, b_r[D_BIT-1:1]};      
                        
                        if (n_r == (D_BIT - 1)) begin   
                            state_n = stop;
                        end
                        else begin
                            n_n = n_r + 1'b1;
                        end
                    end
                    else begin
                        s_n = s_r + 1'b1;
                    end
                end
            end
            stop: begin
                if (s_tick == 1'b1) begin
                    // Previous sample was at the middle of data bit 7;
                    // one full bit interval reaches the middle of stop.
                    if (s_r == (SB_TICK - 1)) begin
                        if (rx) begin
                            state_n = idle;
                            rx_done_tick = 1'b1;
                        end else begin
                            state_n = recover;
                            frame_error_tick = 1'b1;
                        end
                    end
                    else begin
                        s_n = s_r + 1'b1;
                    end
                end
            end
            recover: begin
                // Wait until the line is idle before seeking another start.
                if (rx) state_n = idle;
            end
            default: state_n = idle;
        endcase
    end
    
    assign rx_data = b_r;
endmodule
