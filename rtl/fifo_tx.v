`timescale 1ns / 1ps
module fifo_tx #(
    parameter B = 8,  
    parameter W = 2  
)(
    input  wire         ckht,    
    input  wire         rst,     
    input  wire         rd,      
    input  wire         wr,    
    input  wire [B-1:0] wr_data,  
    output wire         empty,  
    output wire         full,     
    output wire [B-1:0] rd_data  
);
    localparam DEPTH = 1 << W;
    reg [B-1:0] array_r [0:DEPTH-1];
    reg [W-1:0] wr_ptr_r, wr_ptr_n;
    wire [W-1:0] wr_ptr_s; 
    
    reg [W-1:0] rd_ptr_r, rd_ptr_n;
    wire [W-1:0] rd_ptr_s; 
    reg full_r, full_n;
    reg empty_r, empty_n;
    wire [1:0] wr_op; 
    wire wr_en;      
    
    // At full, allow a write only when a valid read frees the same slot.
    assign wr_en = wr & (~full_r | (rd & ~empty_r));
    
    always @(negedge ckht) begin
        if (wr_en == 1'b1) begin
            array_r[wr_ptr_r] <= wr_data;
        end
    end
    assign rd_data = array_r[rd_ptr_r];
    
    always @(negedge ckht or posedge rst) begin
        if (rst == 1'b1) begin
            wr_ptr_r <= {W{1'b0}};
            rd_ptr_r <= {W{1'b0}};
            full_r   <= 1'b0;
            empty_r  <= 1'b1; 
        end
        else begin
            wr_ptr_r <= wr_ptr_n;
            rd_ptr_r <= rd_ptr_n;
            full_r   <= full_n;
            empty_r  <= empty_n;
        end
    end
    
    assign wr_ptr_s = wr_ptr_r + 1'b1;
    assign rd_ptr_s = rd_ptr_r + 1'b1;
    assign wr_op = {wr, rd};
    
    always @(*) begin
        wr_ptr_n = wr_ptr_r;
        rd_ptr_n = rd_ptr_r;
        full_n   = full_r;
        empty_n  = empty_r;
        case (wr_op)
            2'b00: begin
            end
            2'b01: begin
                if (empty_r == 1'b0) begin 
                    rd_ptr_n = rd_ptr_s;   
                    full_n   = 1'b0;  
                    if (rd_ptr_s == wr_ptr_r) begin
                        empty_n = 1'b1;
                    end
                end
            end
            2'b10: begin
                if (full_r == 1'b0) begin
                    wr_ptr_n = wr_ptr_s;  
                    empty_n  = 1'b0;       
                    if (wr_ptr_s == rd_ptr_r) begin
                        full_n = 1'b1; 
                    end
                end
            end
            2'b11: begin
                if (empty_r) begin
                    // No bypass: reject the empty read and enqueue new data.
                    wr_ptr_n = wr_ptr_s;
                    empty_n  = 1'b0;
                    if (wr_ptr_s == rd_ptr_r)
                        full_n = 1'b1;
                end
                else begin
                    // Both operations succeed; occupancy and flags are held.
                    wr_ptr_n = wr_ptr_s;
                    rd_ptr_n = rd_ptr_s;
                end
            end
        endcase
    end
    
    assign full  = full_r;
    assign empty = empty_r;
endmodule
