`timescale 1ns/1ps
// One outstanding aligned 32-bit CPU access, AMBA 2 AHB master signals.
// All 2-bit responses are passed to the CPU; RETRY/SPLIT are not replayed.
module ahb_master_adapter (
  input wire HCLK,HRESETn,
  input wire req_valid,output wire req_ready,input wire req_write,
  input wire [31:0] req_addr,req_wdata,
  output reg rsp_valid,input wire rsp_ready,
  output reg [31:0] rsp_rdata,output reg [1:0] rsp_resp,
  output wire [31:0] HADDR,HWDATA,output wire HWRITE,
  output wire [1:0] HTRANS,output wire [2:0] HSIZE,HBURST,
  output wire [3:0] HPROT,output wire HLOCK,
  input wire HREADY,input wire [1:0] HRESP,input wire [31:0] HRDATA
);
  localparam IDLE=2'd0,ADDRESS=2'd1,DATA=2'd2,RESPONSE=2'd3;
  reg [1:0] state;
  reg [31:0] addr_r,wdata_r;
  reg write_r;
  assign req_ready=(state==IDLE);
  assign HADDR=addr_r;
  assign HWDATA=wdata_r;
  assign HWRITE=write_r;
  assign HTRANS=(state==ADDRESS)?2'b10:2'b00;
  assign HSIZE=3'b010;
  assign HBURST=3'b000;
  assign HPROT=4'b0011;
  assign HLOCK=1'b0;
  // Address is consumed only after a request is accepted; do not async-reset
  // the register driving BRAM address pins.
  always @(posedge HCLK) begin
    if(HRESETn && state==IDLE && req_valid) addr_r<=req_addr;
  end
  always @(posedge HCLK or negedge HRESETn) begin
    if(!HRESETn) begin
      state<=IDLE;wdata_r<=0;write_r<=0;
      rsp_valid<=0;rsp_rdata<=0;rsp_resp<=0;
    end else case(state)
      IDLE: if(req_valid) begin
        wdata_r<=req_wdata;write_r<=req_write;state<=ADDRESS;
      end
      ADDRESS: if(HREADY) state<=DATA;
      DATA: if(HREADY) begin
        rsp_rdata<=HRDATA;rsp_resp<=HRESP;rsp_valid<=1;state<=RESPONSE;
      end
      RESPONSE: if(rsp_valid && rsp_ready) begin rsp_valid<=0;state<=IDLE;end
      default:begin state<=IDLE;rsp_valid<=0;end
    endcase
  end
endmodule
