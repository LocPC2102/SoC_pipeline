`timescale 1ns/1ps
module tb_soc_wishbone;
 reg clk=0,rst=0;always #5 clk=~clk;
 wire uart_tx,spi_sclk,spi_cs_n,spi_mosi,fault;tri1 sda,scl;
 integer errors=0,acks=0,waits=0;reg finished=0, outstanding=0;reg [31:0] held_address;
 soc_peripheral_top #(.WB_IMEM_WAIT(4)) dut(.clk(clk),.rst_n(rst),.uart_rx(1'b1),.spi_miso(1'b1),
  .uart_tx(uart_tx),.spi_sclk(spi_sclk),.spi_cs_n(spi_cs_n),.spi_mosi(spi_mosi),.i2c_sda(sda),.i2c_scl(scl),.bus_fault(fault));
 always @(posedge clk) if(rst) begin
  if(dut.wb_i_cyc && dut.wb_i_stb) begin
   if(!outstanding) begin outstanding<=1;held_address<=dut.wb_i_adr;end
   else if(dut.wb_i_adr!==held_address) begin $display("FAIL address changed during request");errors=errors+1;end
   if(dut.wb_i_ack) begin acks=acks+1;outstanding<=0;end else waits=waits+1;
   if(dut.wb_i_we!==0 || dut.wb_i_sel!==4'hf) begin $display("FAIL fetch controls");errors=errors+1;end
  end else if(outstanding) begin $display("FAIL request dropped before ACK");errors=errors+1;outstanding<=0;end
 end
 task check;input cond;input [400:0] label;begin if(cond!==1) begin $display("FAIL %0s",label);errors=errors+1;end else $display("PASS %0s",label);end endtask
 initial begin
  repeat(3) @(negedge clk);rst=1;repeat(1600) @(negedge clk);
  check(!fault,"no bus fault");
  check(acks>12 && waits>acks,"Wishbone fetches with wait states");
  check(dut.cpu.Decode.rf.Register[1]===32'h40000000 && dut.cpu.Decode.rf.Register[5]===32'h40001000 && dut.cpu.Decode.rf.Register[6]===32'h40002000,"instruction execution and branch loop");
  check(dut.ram.mem[0]===42 && dut.cpu.Decode.rf.Register[4]===43,"AHB RAM load dependency");
  check(dut.uart.tx_data===43 && dut.spi.tx_data===43,"AHB UART and SPI writes");
  check(dut.i2c.device_addr===43 && dut.cpu.Decode.rf.Register[9]===43,"AHB I2C read/write");
  if(errors==0) $display("PASS ALL WISHBONE SOC TESTS ack=%0d wait=%0d",acks,waits); else $display("FAIL WISHBONE SOC TESTS: %0d",errors);
  finished=1;$finish;
 end
 initial begin #100000;if(!finished) begin $display("FAIL TIMEOUT");$finish;end end
endmodule
