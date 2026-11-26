`timescale 1ns/1ps
// 4 KiB AHB RAM, 32-bit aligned accesses. Registered BRAM controls introduce
// wait states; reset does not clear RAM. Writes already at the BRAM edge may
// complete on a coincident reset; system software must treat them as indeterminate.
module ahb_ram(
 input wire HCLK,HRESETn,HSEL,HREADY,
 input wire [31:0] HADDR,HWDATA,input wire [1:0] HTRANS,
 input wire HWRITE,input wire [2:0] HSIZE,
 output wire [31:0] HRDATA,output wire HREADYOUT,output wire [1:0] HRESP
);
 localparam [2:0] IDLE=0,PREPARE=1,EXECUTE=2,RESPONSE=3,ERROR1=4,ERROR2=5;
 reg [2:0] state;
 reg [31:0] mem[0:1023];
 reg [9:0] ram_addr;
 reg [31:0] ram_din,ram_dout;
 reg ram_en,ram_we,write_d;
 wire invalid=HSIZE!=3'b010 || HADDR[1:0]!=0 || HADDR[31:12]!=0;
 assign HREADYOUT=(state==IDLE || state==RESPONSE || state==ERROR2);
 assign HRESP=(state==ERROR1 || state==ERROR2)?2'b01:2'b00;
 assign HRDATA=(state==RESPONSE && !write_d)?ram_dout:32'b0;

 // These are the only direct BRAM controls. They have no asynchronous reset.
 always @(posedge HCLK) begin
  if(ram_en) begin
   if(ram_we) mem[ram_addr]<=ram_din;
   ram_dout<=mem[ram_addr];
  end
 end
 always @(posedge HCLK) begin
  if(!HRESETn) begin state<=IDLE;ram_en<=0;ram_we<=0;write_d<=0;end
  else begin
   ram_en<=0;
   case(state)
    IDLE,RESPONSE,ERROR2: if(HREADY) begin
      if(HSEL && HTRANS[1]) begin
       if(invalid) state<=ERROR1;
       else begin ram_addr<=HADDR[11:2];write_d<=HWRITE;state<=PREPARE;end
      end else state<=IDLE;
    end
    PREPARE: begin
     ram_din<=HWDATA;ram_en<=1;ram_we<=write_d;state<=EXECUTE;
    end
    EXECUTE: state<=RESPONSE;
    ERROR1: state<=ERROR2;
    default: state<=IDLE;
   endcase
  end
 end
endmodule
