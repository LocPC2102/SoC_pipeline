`timescale 1ns/1ps
// One-outstanding Wishbone Classic fetch with a one-entry response buffer.
module fetch_cycle(
 input wire clk,rst,PCSrcE,input wire [31:0] PCTargetE,
 output reg [31:0] InstrD,PCD,PCPlus4D,
 input wire Stall,Flush,output wire FetchWait,output reg FetchFault,
 output wire [31:0] wb_adr_o,output wire wb_cyc_o,wb_stb_o,wb_we_o,
 output wire [3:0] wb_sel_o,input wire [31:0] wb_dat_i,input wire wb_ack_i,wb_err_i
);
 reg [31:0] pc, buffered_instr;
 reg request_active,buffer_valid;
 assign wb_adr_o=pc;
 assign wb_cyc_o=request_active;
 assign wb_stb_o=request_active;
 assign wb_we_o=1'b0;
 assign wb_sel_o=4'b1111;
 assign FetchWait=!buffer_valid;
 always @(posedge clk or negedge rst) begin
  if(!rst) begin
   pc<=0;InstrD<=32'h00000013;PCD<=0;PCPlus4D<=0;
   request_active<=0;buffer_valid<=0;buffered_instr<=0;FetchFault<=0;
  end else begin
   if(!buffer_valid && !request_active && !FetchFault) request_active<=1;
   if(request_active && (wb_ack_i || wb_err_i)) begin
    request_active<=0;
    if(wb_err_i) FetchFault<=1;
    else begin buffered_instr<=wb_dat_i;buffer_valid<=1;end
   end
   if(buffer_valid && !Stall && !FetchFault) begin
    buffer_valid<=0;
    if(Flush) begin
     InstrD<=32'h00000013;PCD<=0;PCPlus4D<=0;pc<=PCTargetE;
    end else begin
     InstrD<=buffered_instr;PCD<=pc;PCPlus4D<=pc+4;pc<=pc+4;
    end
   end
  end
 end
endmodule
