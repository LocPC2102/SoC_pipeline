`timescale 1ns/1ps
// Read-only Wishbone Classic slave, byte addresses, fixed 4 KiB window.
// WAIT_CYCLES adds programmable wait before the registered ACK/ERR.
module wb_instruction_rom #(parameter integer WAIT_CYCLES=2)(
 input wire clk,rst_n,input wire [31:0] adr_i,input wire cyc_i,stb_i,we_i,
 input wire [3:0] sel_i,output reg [31:0] dat_o,output reg ack_o,err_o
);
 localparam IDLE=0,WAIT=1,RESPONSE=2;
 reg [1:0] state;reg [31:0] count;reg [9:0] word_addr;reg bad;
 reg [31:0] mem[0:1023];integer i;
 initial begin
  for(i=0;i<1024;i=i+1) mem[i]=32'h00000013;
  $readmemh("soc_demo.mem",mem);
 end
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin state<=IDLE;count<=0;word_addr<=0;bad<=0;ack_o<=0;err_o<=0;dat_o<=0;end
  else case(state)
   IDLE: begin
    ack_o<=0;err_o<=0;
    if(cyc_i && stb_i) begin
     word_addr<=adr_i[11:2];bad<=we_i || sel_i!=4'hf || adr_i[1:0]!=0 || adr_i[31:12]!=0;
     count<=0;state<=WAIT;
    end
   end
   WAIT: begin
    if(!(cyc_i && stb_i)) state<=IDLE;
    else if(count>=WAIT_CYCLES) begin
     if(bad) err_o<=1;else begin dat_o<=mem[word_addr];ack_o<=1;end
     state<=RESPONSE;
    end else count<=count+1'b1;
   end
   RESPONSE: if(!(cyc_i && stb_i)) begin ack_o<=0;err_o<=0;state<=IDLE;end
   default: begin state<=IDLE;ack_o<=0;err_o<=0;end
  endcase
 end
endmodule
