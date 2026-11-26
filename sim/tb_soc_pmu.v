`timescale 1ns/1ps
module tb_soc_pmu;
 reg clk=0,rst=0;always #5 clk=~clk;
 wire uart_tx,spi_sclk,spi_cs_n,spi_mosi,fault;tri1 sda,scl;
 integer i,errors=0,edges=0,off_edges=0;
 reg saw_busy_request=0,saw_off=0,saw_restart=0,finished=0;
 soc_peripheral_top dut(.clk(clk),.rst_n(rst),.uart_rx(1'b1),.spi_miso(1'b1),
  .uart_tx(uart_tx),.spi_sclk(spi_sclk),.spi_cs_n(spi_cs_n),.spi_mosi(spi_mosi),
  .i2c_sda(sda),.i2c_scl(scl),.bus_fault(fault));
 always @(posedge dut.gated_clk[1]) edges=edges+1;
 always @(negedge clk) if(rst) begin
  if(!dut.pmu.clock_reg[1] && dut.core_busy[1] && dut.gate_active[1]) saw_busy_request=1;
  if(!dut.gate_active[1]) begin
    if(!saw_off) begin saw_off=1;off_edges=edges;end
    if(edges!=off_edges) begin $display("FAIL clock toggled while disabled");errors=errors+1;end
  end
  if(saw_off && dut.gate_active[1]) saw_restart=1;
 end
 function [31:0] lui;input [4:0] rd;input [19:0] imm;
  begin lui={imm,rd,7'b0110111};end endfunction
 function [31:0] addi;input [4:0] rd,rs;input [11:0] imm;
  begin addi={imm,rs,3'b000,rd,7'b0010011};end endfunction
 function [31:0] andi;input [4:0] rd,rs;input [11:0] imm;
  begin andi={imm,rs,3'b111,rd,7'b0010011};end endfunction
 function [31:0] sw;input [4:0] src,base;input [11:0] imm;
  begin sw={imm[11:5],src,base,3'b010,imm[4:0],7'b0100011};end endfunction
 function [31:0] lw;input [4:0] rd,base;input [11:0] imm;
  begin lw={imm,base,3'b010,rd,7'b0000011};end endfunction
 function [31:0] beq;input [4:0] a,b;input [12:0] imm;
  begin beq={imm[12],imm[10:5],b,a,3'b000,imm[4:1],imm[11],7'b1100011};end endfunction
 task check;input cond;input [320:0] msg;
  begin if(cond!==1) begin $display("FAIL %0s",msg);errors=errors+1;end
   else $display("PASS %0s",msg);end endtask
 initial begin
  #1;for(i=0;i<1024;i=i+1) dut.imem.mem[i]=32'h00000013;
  dut.imem.mem[0]=lui(1,20'h40001);
  dut.imem.mem[1]=lui(2,20'h60000);
  dut.imem.mem[2]=addi(3,0,12'h21);
  dut.imem.mem[3]=sw(3,1,0);
  dut.imem.mem[4]=addi(4,0,5);
  dut.imem.mem[5]=sw(4,2,4);
  // Poll STATUS.active[1] until off, then re-enable SPI.
  dut.imem.mem[6]=lw(7,2,8);
  dut.imem.mem[7]=andi(7,7,2);
  dut.imem.mem[8]=beq(7,0,13'd8);
  dut.imem.mem[9]=beq(0,0,-13'd12);
  dut.imem.mem[10]=addi(4,0,7);
  dut.imem.mem[11]=sw(4,2,4);
  dut.imem.mem[12]=addi(3,0,12'h43);
  dut.imem.mem[13]=sw(3,1,0);
  dut.imem.mem[14]=beq(0,0,0);
  repeat(4) @(negedge clk);rst=1;
  repeat(7000) @(negedge clk);
  check(saw_busy_request,"SPI disable deferred while transferring");
  check(saw_off,"SPI clock stopped after idle");
  check(saw_restart,"CPU re-enabled SPI clock");
  check(dut.spi.tx_data===8'h43 && dut.spi.done_sticky,"SPI transfer after re-enable");
  check(!fault,"no bus fault");
  if(errors==0) $display("PASS ALL SOC PMU TESTS");else $display("FAIL SOC PMU TESTS: %0d",errors);
  finished=1;$finish;
 end
 initial begin #100000;if(!finished) begin $display("FAIL TIMEOUT");$finish;end end
endmodule
