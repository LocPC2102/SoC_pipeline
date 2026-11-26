`timescale 1ns/1ps
module tb_ahb_pmu;
 reg clk=0,resetn=0,sel=0,wr=0;
 reg [31:0] addr=0,wdata=0;reg [1:0] trans=0;reg [2:0] busy=0;
 wire [31:0] rdata;wire ready;wire [1:0] resp;
 wire [2:0] gates,active,pwr,cen;
 integer fails=0,edges0=0,edges1=0;reg finished=0;
 reg [31:0] result;integer e0,e1;
 always #5 clk=~clk;
 always @(posedge gates[0]) edges0=edges0+1;
 always @(posedge gates[1]) edges1=edges1+1;
 ahb_pmu dut(.HCLK(clk),.HRESETn(resetn),.HSEL(sel),.HREADY(ready),
  .HADDR(addr),.HWDATA(wdata),.HTRANS(trans),.HWRITE(wr),.HSIZE(3'b010),
  .HRDATA(rdata),.HREADYOUT(ready),.HRESP(resp),.busy(busy),
  .gated_clk(gates),.gate_active(active),.power_request(pwr),.clock_request(cen));
 task check;input cond;input [319:0] msg;
  begin if(cond!==1) begin $display("FAIL %0s",msg);fails=fails+1;end
   else $display("PASS %0s",msg);end endtask
 task access;input [31:0] a,d;input w,bad;output [31:0] result;
  begin @(negedge clk);sel=1;trans=2;addr=a;wr=w;
   @(posedge clk);@(negedge clk);sel=0;trans=0;wdata=d;
   @(posedge clk);
   if(bad) begin check(!ready && resp==1,"ERROR first cycle");
    @(posedge clk);check(ready && resp==1,"ERROR second cycle");end
   else check(ready && resp==0,"AHB OKAY");
   result=rdata;end
 endtask
 initial begin
  repeat(4) @(negedge clk);resetn=1;
  access(8,0,0,0,result);check(result[2:0]==7,"reset enables all gates");
  busy=3'b010;
  access(0,32'h4,1,0,result);
  repeat(3) @(negedge clk);#1;
  check(active==3'b110,"idle gate off while busy gate deferred");
  access(8,0,0,0,result);check(result[17] && result[9],"status pending and busy");
  e0=edges0;e1=edges1;repeat(8) @(negedge clk);#1;
  check(edges0==e0 && edges1>e1,"disabled clock stops; busy clock runs");
  busy=0;repeat(3) @(negedge clk);#1;
  check(active==3'b100,"busy gate stops after idle");
  access(0,32'h7,1,0,result);repeat(2) @(negedge clk);#1;
  check(active==3'b111,"power request re-enables clocks");
  access(4,32'h6,1,0,result);repeat(2) @(negedge clk);#1;
  check(active==3'b110,"clock request AND power request");
  access(4,32'h7,1,0,result);repeat(2) @(negedge clk);#1;
  check(active==3'b111,"clock request re-enables");
  access(12,0,0,1,result);
  if(fails==0) $display("PASS ALL AHB PMU TESTS");else $display("FAIL AHB PMU TESTS: %0d",fails);
  finished=1;$finish;
 end
 initial begin #100000;if(!finished) begin $display("FAIL PMU TIMEOUT");$finish;end end
endmodule
