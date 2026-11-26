`timescale 1ns/1ps
// Single-controller, 7-bit address, one-byte transfer; open-drain SDA/SCL.
module i2c_master #(
  parameter integer sys_freq=100000000,
  parameter integer i2c_freq=100000
)(
  input wire clk,rst,newd,
  input wire [6:0] addr,
  input wire op,
  inout wire sda,
  inout wire scl,
  input wire [7:0] din,
  output wire [7:0] dout,
  output reg busy,ack_err,done
);
  // Rounded up: never deliberately exceed the requested bus frequency.
  localparam integer Q_RAW=(sys_freq+4*i2c_freq-1)/(4*i2c_freq);
  localparam integer Q=(Q_RAW<1)?1:Q_RAW;
  localparam integer CW=(Q<=1)?1:$clog2(Q);
  localparam [3:0] IDLE=0, START=1, ADDRESS=2, ADDR_ACK=3,
                   WRITE=4, DATA_ACK=5, READ=6, STOP=7, READ_NACK=8;
  reg [3:0] state;
  reg [1:0] phase;
  reg [CW-1:0] count;
  reg [2:0] bit_index;
  reg [7:0] address_byte,tx_byte,rx_byte;
  reg master_nack;
  wire data_state=(state==ADDRESS || state==ADDR_ACK || state==WRITE || state==DATA_ACK || state==READ || state==READ_NACK);
  wire scl_low=(data_state && phase<2) || (state==STOP && phase<2);
  reg sda_low;
  always @* begin
    sda_low=0;
    case(state)
      START: sda_low=(phase>=2);
      ADDRESS: sda_low=~address_byte[bit_index];
      WRITE: sda_low=~tx_byte[bit_index];
      STOP: sda_low=(phase<3);
      default: sda_low=0;
    endcase
  end
  assign sda=sda_low ? 1'b0 : 1'bz;
  assign scl=scl_low ? 1'b0 : 1'bz;
  assign dout=rx_byte;
  // During released-high phases a target may hold SCL low (clock stretching).
  wire wait_scl=(busy && !scl_low && (scl !== 1'b1));
  always @(posedge clk) begin
    if(rst) begin
      state<=IDLE;phase<=0;count<=0;bit_index<=7;
      address_byte<=0;tx_byte<=0;rx_byte<=0;
      busy<=0;ack_err<=0;done<=0;master_nack<=0;
    end else begin
      done<=0;
      if(state==IDLE) begin
        phase<=0; count<=0; busy<=0;
        if(newd) begin
          address_byte<={addr,op};tx_byte<=din;rx_byte<=0;
          ack_err<=0;busy<=1;state<=START;bit_index<=7;
        end
      end else if(!wait_scl) begin
        if(count==Q-1) begin
          count<=0;
          if(phase==2) begin
            if(state==ADDR_ACK || state==DATA_ACK) master_nack <= (sda !== 1'b0);
            if(state==READ) rx_byte[bit_index]<=sda;
          end
          if(phase==3) begin
            phase<=0;
            case(state)
              START: begin state<=ADDRESS;bit_index<=7; end
              ADDRESS: if(bit_index==0) state<=ADDR_ACK; else bit_index<=bit_index-1'b1;
              ADDR_ACK: begin
                if(master_nack) begin ack_err<=1;state<=STOP;end
                else begin bit_index<=7;if(address_byte[0]) state<=READ;else state<=WRITE;end
              end
              WRITE: if(bit_index==0) state<=DATA_ACK;else bit_index<=bit_index-1'b1;
              DATA_ACK: begin if(master_nack) ack_err<=1;state<=STOP;end
              READ: if(bit_index==0) state<=READ_NACK;
                    else bit_index<=bit_index-1'b1;
              READ_NACK: state<=STOP;
              STOP: begin state<=IDLE;busy<=0;done<=1;end
              default: state<=IDLE;
            endcase
          end else phase<=phase+1'b1;
        end else count<=count+1'b1;
      end
    end
  end
endmodule
