`timescale 1ns/1ps
// Single-master I2C controller exposed as a 32-bit AMBA 2 AHB slave.
module ahb_i2c_master #(parameter integer sys_freq=100000000, i2c_freq=100000)(
  input wire HCLK,HRESETn,HSEL,HREADY, input wire core_clk, output wire pmu_busy,
  input wire [31:0] HADDR,HWDATA,
  input wire [1:0] HTRANS,input wire HWRITE,input wire [2:0] HSIZE,
  output wire [31:0] HRDATA,output wire HREADYOUT,output wire [1:0] HRESP,
  inout wire sda,scl
);
  localparam [4:0] ADDR=0,TXDATA=4,CONTROL=8,RXDATA=12,STATUS=16;
  reg valid_d,write_d;reg [4:0] addr_d;reg [1:0] err_state;
  reg [6:0] device_addr;reg [7:0] tx_data;reg op,start;
  reg done_sticky,nack_sticky,rejected_sticky;
  wire busy,done,ack_err;
  assign pmu_busy=busy || done || start;wire [7:0] rx_data;
  wire invalid=HSIZE!=3'b010 || HADDR[11:5]!=0 || HADDR[1:0]!=0 ||
    !(HADDR[4:0]==ADDR || HADDR[4:0]==TXDATA ||
      (HADDR[4:0]==CONTROL && HWRITE) || (HADDR[4:0]==RXDATA && !HWRITE) || HADDR[4:0]==STATUS);
  assign HREADYOUT=(err_state!=1);
  assign HRESP=err_state==0 ? 2'b00 : 2'b01;
  assign HRDATA=(!valid_d || write_d || err_state!=0) ? 0 :
    addr_d==ADDR ? {25'b0,device_addr} : addr_d==TXDATA ? {24'b0,tx_data} :
    addr_d==RXDATA ? {24'b0,rx_data} :
    addr_d==STATUS ? {28'b0,rejected_sticky,nack_sticky,done_sticky,(busy|start)} : 0;
  always @(posedge HCLK or negedge HRESETn) begin
    if(!HRESETn) begin
      valid_d<=0;write_d<=0;addr_d<=0;err_state<=0;
      device_addr<=0;tx_data<=0;op<=0;start<=0;
      done_sticky<=0;nack_sticky<=0;rejected_sticky<=0;
    end else begin
      start<=0;
      if(HREADY && valid_d && err_state==0 && write_d) begin
        case(addr_d)
          ADDR:device_addr<=HWDATA[6:0];
          TXDATA:tx_data<=HWDATA[7:0];
          CONTROL:if(HWDATA[0]) begin
            if(busy || start) rejected_sticky<=1;
            else begin op<=HWDATA[1];start<=1;end
          end
          STATUS:begin
            if(HWDATA[1]) done_sticky<=0;
            if(HWDATA[2]) nack_sticky<=0;
            if(HWDATA[3]) rejected_sticky<=0;
          end
          default:;
        endcase
      end
      if(done) begin done_sticky<=1;if(ack_err) nack_sticky<=1;end
      if(err_state==1) err_state<=2;
      else if(HREADY) begin
        valid_d<=HSEL && HTRANS[1];
        if(HSEL && HTRANS[1]) begin
          addr_d<=HADDR[4:0];write_d<=HWRITE;
          if(invalid) err_state<=1;else err_state<=0;
        end else err_state<=0;
      end
    end
  end
  i2c_master #(.sys_freq(sys_freq),.i2c_freq(i2c_freq)) u_master (
    .clk(core_clk),.rst(~HRESETn),.newd(start),.addr(device_addr),.op(op),
    .sda(sda),.scl(scl),.din(tx_data),.dout(rx_data),
    .busy(busy),.ack_err(ack_err),.done(done));
endmodule
