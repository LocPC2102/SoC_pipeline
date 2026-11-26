`timescale 1ns/1ps
// AMBA 2 AHB slave peripheral, 32-bit aligned accesses, mode-0 SPI master.
module ahb_spi_master #(parameter CLK_DIV=4)(
  input wire HCLK,HRESETn,HSEL,HREADY, input wire core_clk, output wire pmu_busy,
  input wire [31:0] HADDR,HWDATA,
  input wire [1:0] HTRANS,
  input wire HWRITE, input wire [2:0] HSIZE,
  output wire [31:0] HRDATA, output wire HREADYOUT,
  output wire [1:0] HRESP,
  output wire sclk,cs_n,mosi,input wire miso
);
  localparam TXDATA=4'h0, RXDATA=4'h4, STATUS=4'h8;
  reg valid_d,write_d;
  reg [3:0] addr_d;
  reg [1:0] err_state;
  reg start_pulse, done_sticky, rejected_sticky;
  reg [7:0] tx_data;
  wire [7:0] rx_data;
  wire busy,done;
  assign pmu_busy=busy || done || start_pulse;
  wire invalid = HSIZE!=3'b010 || HADDR[11:4]!=0 || HADDR[1:0]!=0 ||
    !((HADDR[3:0]==TXDATA && HWRITE) || (HADDR[3:0]==RXDATA && !HWRITE) || HADDR[3:0]==STATUS);
  assign HREADYOUT=(err_state!=1);
  assign HRESP=(err_state==0) ? 2'b00 : 2'b01;
  assign HRDATA=(!valid_d || write_d || err_state!=0) ? 0 :
    addr_d==RXDATA ? {24'b0,rx_data} :
    addr_d==STATUS ? {29'b0,rejected_sticky,done_sticky,(busy | start_pulse)} : 0;
  always @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
      valid_d<=0; write_d<=0; addr_d<=0; err_state<=0;
      start_pulse<=0; tx_data<=0; done_sticky<=0; rejected_sticky<=0;
    end else begin
      start_pulse<=0;
      if (HREADY && valid_d && err_state==0 && write_d) begin
        if (addr_d==TXDATA) begin
          if (busy || start_pulse) rejected_sticky<=1;
          else begin tx_data<=HWDATA[7:0]; start_pulse<=1; end
        end
        if (addr_d==STATUS) begin
          if (HWDATA[1]) done_sticky<=0;
          if (HWDATA[2]) rejected_sticky<=0;
        end
      end
      // A completion wins over a simultaneous software clear.
      if(done) done_sticky<=1;
      if(err_state==1) err_state<=2;
      else if(HREADY) begin
        valid_d<=HSEL && HTRANS[1];
        if(HSEL && HTRANS[1]) begin
          addr_d<=HADDR[3:0]; write_d<=HWRITE;
          if(invalid) err_state<=1; else err_state<=0;
        end else err_state<=0;
      end
    end
  end
  spi_master #(.CLK_DIV(CLK_DIV)) u_master (
    .clk(core_clk),.rst(~HRESETn),.start(start_pulse),.tx_data(tx_data),
    .rx_data(rx_data),.busy(busy),.done(done),
    .sclk(sclk),.cs_n(cs_n),.mosi(mosi),.miso(miso));
endmodule
