`timescale 1ns/1ps
module tb_ahb_ram_reset;
 reg clk=0,rst_n=0,sel=0,wr=0;reg [31:0] addr=0,wdata=0;reg [1:0] trans=0;
 wire [31:0] rdata;wire ready;wire [1:0] resp;
 integer errors=0;reg finished=0;reg [31:0] val;
 always #5 clk=~clk;
 ahb_ram dut(.HCLK(clk),.HRESETn(rst_n),.HSEL(sel),.HREADY(ready),
  .HADDR(addr),.HWDATA(wdata),.HTRANS(trans),.HWRITE(wr),.HSIZE(3'b010),
  .HRDATA(rdata),.HREADYOUT(ready),.HRESP(resp));
 task check;input cond;input [319:0] msg;
  begin if(cond!==1) begin $display("FAIL %0s",msg);errors=errors+1;end
   else $display("PASS %0s",msg);end endtask
 task access;input w;input [31:0] a,d;output [31:0] out;
  begin @(negedge clk);sel=1;trans=2;wr=w;addr=a;
   @(posedge clk);@(negedge clk);sel=0;trans=0;wdata=d;
   @(posedge clk);
   while(ready!==1'b1) @(posedge clk);
   out=rdata;
   if(ready!==1 || resp!==0) begin $display("FAIL response");errors=errors+1;end
  end endtask
 initial begin
  repeat(4) @(negedge clk);rst_n=1;
  access(1,4,32'h12345678,val);access(0,4,0,val);
  check(val===32'h12345678,"RAM write/read before reset");
  @(negedge clk);sel=1;trans=2;wr=1;addr=4;
  @(posedge clk);@(negedge clk);sel=0;trans=0;wdata=32'hdeadbeef;rst_n=0;
  repeat(3) @(negedge clk);rst_n=1;
  access(0,4,0,val);
  check(val===32'h12345678,"reset aborts pending write and retains RAM");
  access(1,8,32'h89abcdef,val);access(0,8,0,val);
  check(val===32'h89abcdef,"RAM accepts new transfer after reset");
  if(errors==0) $display("PASS ALL AHB RAM RESET TESTS");
  else $display("FAIL AHB RAM RESET TESTS: %0d",errors);
  finished=1;$finish;
 end
 initial begin #10000;if(!finished) begin $display("FAIL TIMEOUT");$finish;end end
endmodule
