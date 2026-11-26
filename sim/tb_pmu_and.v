`timescale 1ns/1ps
// PMU truth table through AHB. gate_active is the stable permission signal;
// gated_clk must pulse only when the requested pair is enabled and idle.
module tb_pmu_and;
 reg clk=0,rst_n=0,sel=0,wr=0;reg [31:0] addr=0,wdata=0;
 reg [1:0] trans=0;reg [2:0] busy=0;
 wire [31:0] rdata;wire ready;wire [1:0] resp;
 wire [2:0] gated_clk,gate_active,power_request,clock_request;
 integer errors=0,p,c,lane,edges[0:2],before_count[0:2];
 reg finished=0;reg [2:0] value_p,value_c,expect;
 always #5 clk=~clk;
 always @(posedge gated_clk[0]) edges[0]=edges[0]+1;
 always @(posedge gated_clk[1]) edges[1]=edges[1]+1;
 always @(posedge gated_clk[2]) edges[2]=edges[2]+1;
 ahb_pmu dut(.HCLK(clk),.HRESETn(rst_n),.HSEL(sel),.HREADY(ready),
  .HADDR(addr),.HWDATA(wdata),.HTRANS(trans),.HWRITE(wr),.HSIZE(3'b010),
  .HRDATA(rdata),.HREADYOUT(ready),.HRESP(resp),.busy(busy),.gated_clk(gated_clk),
  .gate_active(gate_active),.power_request(power_request),.clock_request(clock_request));
 task write_reg;input [31:0] a,d;
  begin @(negedge clk);sel=1;trans=2;wr=1;addr=a;
   @(posedge clk);@(negedge clk);sel=0;trans=0;wdata=d;
   @(posedge clk);if(ready!==1 || resp!==0) begin $display("FAIL AHB write");errors=errors+1;end
  end endtask
 initial begin
  for(lane=0;lane<3;lane=lane+1) edges[lane]=0;
  repeat(4) @(negedge clk);rst_n=1;
  for(p=0;p<2;p=p+1) begin
   for(c=0;c<2;c=c+1) begin
    value_p=p ? 3'b111 : 3'b000;value_c=c ? 3'b111 : 3'b000;
    write_reg(0,{29'b0,value_p});write_reg(4,{29'b0,value_c});
    repeat(3) @(negedge clk);#1;
    expect=value_p & value_c;
    if(power_request!==value_p || clock_request!==value_c || gate_active!==expect) begin
      $display("FAIL p=%b c=%b requests=%b/%b active=%b expected=%b",p[0],c[0],power_request,clock_request,gate_active,expect);errors=errors+1;
    end else $display("PASS power=%0d clock=%0d permission=%b",p,c,gate_active);
    for(lane=0;lane<3;lane=lane+1) before_count[lane]=edges[lane];
    repeat(5) @(negedge clk);#1;
    for(lane=0;lane<3;lane=lane+1) begin
      if(expect[lane] && edges[lane]<=before_count[lane]) begin $display("FAIL lane %0d did not run",lane);errors=errors+1;end
      if(!expect[lane] && edges[lane]!=before_count[lane]) begin $display("FAIL lane %0d did not stop",lane);errors=errors+1;end
    end
   end
  end
  busy=3'b010;write_reg(4,0);repeat(3) @(negedge clk);#1;
  if(gate_active!==3'b010) begin $display("FAIL busy deferred active=%b",gate_active);errors=errors+1;end
  else $display("PASS busy peripheral stays enabled until idle");
  busy=0;repeat(3) @(negedge clk);#1;
  if(gate_active!==0) begin $display("FAIL disable after idle");errors=errors+1;end
  else $display("PASS deferred disable after idle");
  if(errors==0) $display("PASS ALL PMU AND TRUTH TABLE TESTS");
  else $display("FAIL PMU AND TRUTH TABLE TESTS: %0d",errors);
  finished=1;$finish;
 end
 initial begin #100000;if(!finished) begin $display("FAIL PMU TIMEOUT");$finish;end end
endmodule
