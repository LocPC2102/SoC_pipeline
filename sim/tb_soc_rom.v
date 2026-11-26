`timescale 1ns/1ps
module tb_soc_rom;
 reg clk=0,rst=0;always #5 clk=~clk;
 wire uart_tx,spi_sclk,spi_cs_n,spi_mosi,fault;tri1 sda,scl;
 integer errors=0;reg finished=0;
 soc_peripheral_top dut(.clk(clk),.rst_n(rst),.uart_rx(1'b1),.spi_miso(1'b1),
  .uart_tx(uart_tx),.spi_sclk(spi_sclk),.spi_cs_n(spi_cs_n),.spi_mosi(spi_mosi),
  .i2c_sda(sda),.i2c_scl(scl),.bus_fault(fault));
 task check;input cond;input [320:0] label;
  begin if(cond!==1) begin $display("FAIL %0s",label);errors=errors+1;end
  else $display("PASS %0s",label);end endtask
 initial begin
  repeat(3) @(negedge clk);rst=1;
  repeat(1600) @(negedge clk);
  check(!fault,"no bus fault");
  check(dut.cpu.Decode.rf.Register[1]===32'h40000000 &&
        dut.cpu.Decode.rf.Register[5]===32'h40001000 &&
        dut.cpu.Decode.rf.Register[6]===32'h40002000,"LUI creates peripheral base addresses");
  check(dut.ram.mem[0]===42 && dut.cpu.Decode.rf.Register[4]===43,"RAM load dependency");
  check(dut.uart.tx_data===43 && dut.spi.tx_data===43,"ROM program writes UART and SPI");
  check(dut.i2c.device_addr===43 && dut.cpu.Decode.rf.Register[9]===43,"ROM program writes and reads I2C");
  if(errors==0) $display("PASS ALL SOC ROM TESTS"); else $display("FAIL SOC ROM TESTS: %0d",errors);
  finished=1;$finish;
 end
 initial begin #100000;if(!finished) begin $display("FAIL TIMEOUT");$finish;end end
endmodule
