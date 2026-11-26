`timescale 1ns/1ps
// PMU prototype: AHB registers remain clocked; gate requests wait for idle.
// busy[i] must include peripheral activity AND pending bus accesses/commands.
// HRESETn must be asserted across at least one falling HCLK edge.
module ahb_pmu(
 input wire HCLK,HRESETn,HSEL,HREADY,
 input wire [31:0] HADDR,HWDATA,
 input wire [1:0] HTRANS,input wire HWRITE,input wire [2:0] HSIZE,
 output wire [31:0] HRDATA,output wire HREADYOUT,output wire [1:0] HRESP,
 input wire [2:0] busy,
 output wire [2:0] gated_clk,
 output reg [2:0] gate_active,
 output wire [2:0] power_request,clock_request
);
 localparam [3:0] POWER=0,CLOCK=4,STATUS=8;
 reg [2:0] power_reg,clock_reg;
 reg valid_d,write_d;reg [3:0] addr_d;reg [1:0] err_state;
 wire invalid=HSIZE!=3'b010 || HADDR[11:4]!=0 || HADDR[1:0]!=0 ||
   !(HADDR[3:0]==POWER || HADDR[3:0]==CLOCK || (HADDR[3:0]==STATUS && !HWRITE));
 wire [2:0] desired=power_reg & clock_reg;
 assign power_request=power_reg;assign clock_request=clock_reg;
 assign gated_clk={3{HCLK}} & gate_active;
 assign HREADYOUT=(err_state!=1);
 assign HRESP=(err_state==0)?2'b00:2'b01;
 // STATUS [2:0] active, [10:8] busy, [18:16] pending disable.
 assign HRDATA=(!valid_d || write_d || err_state!=0)?32'b0:
   addr_d==POWER?{29'b0,power_reg}:addr_d==CLOCK?{29'b0,clock_reg}:
   addr_d==STATUS?{13'b0,(gate_active & ~desired),5'b0,busy,5'b0,gate_active}:32'b0;
 always @(posedge HCLK or negedge HRESETn) begin
  if(!HRESETn) begin
    power_reg<=3'b111;clock_reg<=3'b111;
    valid_d<=0;write_d<=0;addr_d<=0;err_state<=0;
  end else begin
    if(HREADY && valid_d && write_d && err_state==0) begin
      if(addr_d==POWER) power_reg<=HWDATA[2:0];
      if(addr_d==CLOCK) clock_reg<=HWDATA[2:0];
    end
    if(err_state==1) err_state<=2;
    else if(HREADY) begin
      valid_d<=HSEL && HTRANS[1];
      if(HSEL && HTRANS[1]) begin
        addr_d<=HADDR[3:0];write_d<=HWRITE;
        if(invalid) err_state<=1; else err_state<=0;
      end else err_state<=0;
    end
  end
 end
 // Enable may change ONLY on the falling edge. Disable is deferred when busy.
 integer i;
 always @(negedge HCLK) begin
  if(!HRESETn) gate_active<=3'b111;
  else for(i=0;i<3;i=i+1) begin
    if(desired[i]) gate_active[i]<=1'b1;
    else if(!busy[i]) gate_active[i]<=1'b0;
  end
 end
endmodule
