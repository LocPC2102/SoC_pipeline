`timescale 1ns/1ps
module ahb_peripheral_fabric(
 input wire HCLK,HRESETn,input wire [31:0] HADDR,input wire [1:0] HTRANS,
 input wire [2:0] gate_active,
 output wire sel_uart,sel_spi,sel_i2c,sel_ram,sel_pmu,output wire [2:0] bus_busy,
 input wire uart_ready,spi_ready,i2c_ready,ram_ready,pmu_ready,
 input wire [1:0] uart_resp,spi_resp,i2c_resp,ram_resp,pmu_resp,
 input wire [31:0] uart_data,spi_data,i2c_data,ram_data,pmu_data,
 output wire HREADY,output wire [1:0] HRESP,output wire [31:0] HRDATA
);
 reg [2:0] target;reg default_second;
 wire raw_uart=(HADDR[31:12]==20'h40000),raw_spi=(HADDR[31:12]==20'h40001),raw_i2c=(HADDR[31:12]==20'h40002);
 assign sel_uart=raw_uart && gate_active[0];
 assign sel_spi=raw_spi && gate_active[1];
 assign sel_i2c=raw_i2c && gate_active[2];
 assign sel_ram=(HADDR[31:12]==20'h00000);
 assign sel_pmu=(HADDR[31:12]==20'h60000);
 assign bus_busy[0]=(target==1)||(HTRANS[1] && raw_uart);
 assign bus_busy[1]=(target==2)||(HTRANS[1] && raw_spi);
 assign bus_busy[2]=(target==3)||(HTRANS[1] && raw_i2c);
 assign HREADY=target==1?uart_ready:target==2?spi_ready:target==3?i2c_ready:target==4?default_second:target==5?ram_ready:target==6?pmu_ready:1'b1;
 assign HRESP=target==1?uart_resp:target==2?spi_resp:target==3?i2c_resp:target==4?2'b01:target==5?ram_resp:target==6?pmu_resp:2'b00;
 assign HRDATA=target==1?uart_data:target==2?spi_data:target==3?i2c_data:target==5?ram_data:target==6?pmu_data:32'b0;
 always @(posedge HCLK or negedge HRESETn) begin
  if(!HRESETn) begin target<=0;default_second<=0;end
  else begin
   if(target==4 && !default_second) default_second<=1;
   if(HREADY) begin
    default_second<=0;
    if(!HTRANS[1]) target<=0;
    else if(sel_uart) target<=1;
    else if(sel_spi) target<=2;
    else if(sel_i2c) target<=3;
    else if(sel_ram) target<=5;
    else if(sel_pmu) target<=6;
    else target<=4;
   end
  end
 end
endmodule
