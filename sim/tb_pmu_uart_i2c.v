`timescale 1ns/1ps
module tb_pmu_uart_i2c;
 reg clk=0,rst=0;always #5 clk=~clk;
 wire uart_tx,spi_sclk,spi_cs_n,spi_mosi,fault;tri1 sda,scl;
 integer i,errors=0;reg finished=0;
 reg saw_uart_busy=0,saw_i2c_busy=0,saw_uart_off=0,saw_i2c_off=0;
 reg uart_restart=0,i2c_restart=0;
 soc_peripheral_top dut(.clk(clk),.rst_n(rst),.uart_rx(1'b1),.spi_miso(1'b1),
  .uart_tx(uart_tx),.spi_sclk(spi_sclk),.spi_cs_n(spi_cs_n),.spi_mosi(spi_mosi),
  .i2c_sda(sda),.i2c_scl(scl),.bus_fault(fault));
 always @(negedge clk) if(rst) begin
  if(!dut.pmu.clock_reg[0] && dut.core_busy[0] && dut.gate_active[0]) saw_uart_busy=1;
  if(!dut.pmu.clock_reg[2] && dut.core_busy[2] && dut.gate_active[2]) saw_i2c_busy=1;
  if(!dut.gate_active[0]) begin
   saw_uart_off=1;
   if(dut.core_busy[0] || uart_tx!==1'b1) begin $display("FAIL UART gated before idle");errors=errors+1;end
  end
  if(!dut.gate_active[2]) begin
   saw_i2c_off=1;
   if(dut.core_busy[2] || sda!==1'b1 || scl!==1'b1) begin $display("FAIL I2C gated before idle");errors=errors+1;end
  end
  if(saw_uart_off && dut.gate_active[0]) uart_restart=1;
  if(saw_i2c_off && dut.gate_active[2]) i2c_restart=1;
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
  dut.imem.mem[0]=lui(1,20'h40000);
  dut.imem.mem[1]=lui(2,20'h40002);
  dut.imem.mem[2]=lui(3,20'h60000);
  dut.imem.mem[3]=addi(4,0,72);
  dut.imem.mem[4]=sw(4,1,0);
  dut.imem.mem[5]=addi(4,0,72);
  dut.imem.mem[6]=sw(4,2,0);
  dut.imem.mem[7]=addi(4,0,1);
  dut.imem.mem[8]=sw(4,2,8);
  dut.imem.mem[9]=addi(4,0,2);
  dut.imem.mem[10]=sw(4,3,4);
  dut.imem.mem[11]=lw(7,3,8);
  dut.imem.mem[12]=andi(7,7,5);
  dut.imem.mem[13]=beq(7,0,13'd8);
  dut.imem.mem[14]=beq(0,0,-13'd12);
  dut.imem.mem[15]=addi(4,0,7);
  dut.imem.mem[16]=sw(4,3,4);
  dut.imem.mem[17]=beq(0,0,0);
  repeat(4) @(negedge clk);rst=1;
  repeat(22000) @(negedge clk);
  check(saw_uart_busy && saw_i2c_busy,"disable deferred while UART and I2C busy");
  check(saw_uart_off && saw_i2c_off,"UART and I2C clocks eventually stopped");
  check(uart_restart && i2c_restart,"CPU re-enabled UART and I2C");
  check(dut.i2c.nack_sticky && dut.i2c.done_sticky,"I2C completion and NACK retained");
  check(!fault,"no bus fault");
  if(errors==0) $display("PASS ALL PMU UART I2C TESTS");
  else $display("FAIL PMU UART I2C TESTS: %0d",errors);
  finished=1;$finish;
 end
 initial begin #1000000;if(!finished) begin $display("FAIL TIMEOUT");$finish;end end
endmodule
