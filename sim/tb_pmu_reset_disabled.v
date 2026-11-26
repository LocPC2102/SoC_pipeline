`timescale 1ns/1ps
// CPU-driven PMU test. This checks RTL behavior, not gate-level glitches.
module tb_pmu_reset_disabled;
 reg clk=0,rst=0;always #5 clk=~clk;
 wire uart_tx,spi_sclk,spi_cs_n,spi_mosi,fault;tri1 sda,scl;
 integer i,errors=0;reg finished=0;
 reg saw_disabled=0,saw_error_low=0,saw_error_high=0;
 reg saw_all_off=0,saw_all_on_again=0,monitor_toggle=0;
 soc_peripheral_top dut(.clk(clk),.rst_n(rst),.uart_rx(1'b1),.spi_miso(1'b1),
  .uart_tx(uart_tx),.spi_sclk(spi_sclk),.spi_cs_n(spi_cs_n),.spi_mosi(spi_mosi),
  .i2c_sda(sda),.i2c_scl(scl),.bus_fault(fault));
 function [31:0] lui;input [4:0] rd;input [19:0] imm;
  begin lui={imm,rd,7'b0110111};end endfunction
 function [31:0] addi;input [4:0] rd,rs;input [11:0] imm;
  begin addi={imm,rs,3'b000,rd,7'b0010011};end endfunction
 function [31:0] sw;input [4:0] src,base;input [11:0] imm;
  begin sw={imm[11:5],src,base,3'b010,imm[4:0],7'b0100011};end endfunction
 function [31:0] lw;input [4:0] rd,base;input [11:0] imm;
  begin lw={imm,base,3'b010,rd,7'b0000011};end endfunction
 function [31:0] beq;input [4:0] a,b;input [12:0] imm;
  begin beq={imm[12],imm[10:5],b,a,3'b000,imm[4:1],imm[11],7'b1100011};end endfunction
 task check;input cond;input [320:0] msg;
  begin if(cond!==1) begin $display("FAIL %0s",msg);errors=errors+1;end
   else $display("PASS %0s",msg);end endtask
 always @(negedge clk) if(rst) begin
  if(!dut.gate_active[0]) saw_disabled=1;
  if(dut.hresp==2'b01 && !dut.hready) saw_error_low=1;
  if(dut.hresp==2'b01 && dut.hready) saw_error_high=1;
  if(monitor_toggle) begin
   if(dut.gate_active==0) saw_all_off=1;
   if(saw_all_off && dut.gate_active==7) saw_all_on_again=1;
  end
 end
 initial begin
  #1;for(i=0;i<1024;i=i+1) dut.imem.mem[i]=32'h00000013;
  dut.cpu.Decode.rf.Register[6]=0;
  // Disable UART then deliberately access it: fabric must return ERROR.
  dut.imem.mem[0]=lui(1,20'h60000);
  dut.imem.mem[1]=addi(2,0,6);
  dut.imem.mem[2]=sw(2,1,4);
  dut.imem.mem[3]=lui(4,20'h40000);
  dut.imem.mem[4]=lw(5,4,8);
  dut.imem.mem[5]=addi(6,0,99);
  repeat(4) @(negedge clk);rst=1;
  repeat(1000) @(negedge clk);
  check(saw_disabled && saw_error_low && saw_error_high && fault,
    "disabled UART access returns two-cycle ERROR and halts CPU");
  check(dut.cpu.Decode.rf.Register[6]===32'd0,"instruction after bus fault does not commit");
  // Reset while UART clock is disabled. Reset must cover falling and rising edges.
  @(negedge clk);rst=0;
  repeat(5) @(negedge clk);#1;
  check(dut.gate_active===3'b111 && !fault,"reset re-enables gates and clears fault");
  check(!dut.spi.busy && !dut.i2c.busy && uart_tx===1'b1,
    "peripheral cores reach reset idle");
  // New program: all gates off, all gates back on, then write UART.
  for(i=0;i<1024;i=i+1) dut.imem.mem[i]=32'h00000013;
  dut.imem.mem[0]=lui(1,20'h60000);
  dut.imem.mem[1]=addi(2,0,0);
  dut.imem.mem[2]=sw(2,1,4);
  dut.imem.mem[3]=addi(2,0,7);
  dut.imem.mem[4]=sw(2,1,4);
  dut.imem.mem[5]=lui(4,20'h40000);
  dut.imem.mem[6]=addi(5,0,72);
  dut.imem.mem[7]=sw(5,4,0);
  dut.imem.mem[8]=beq(0,0,0);
  monitor_toggle=1;@(negedge clk);rst=1;
  repeat(2000) @(negedge clk);
  check(saw_all_off && saw_all_on_again,"consecutive disable and enable across three gates");
  check(!fault && dut.uart.tx_data===8'h48,"UART accepts CPU write after re-enable");
  if(errors==0) $display("PASS ALL PMU RESET DISABLED TESTS");
  else $display("FAIL PMU RESET DISABLED TESTS: %0d",errors);
  finished=1;$finish;
 end
 initial begin #100000;if(!finished) begin $display("FAIL TIMEOUT");$finish;end end
endmodule
