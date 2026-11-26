`timescale 1ns/1ps
module soc_peripheral_top #(parameter integer WB_IMEM_WAIT=2)(
 input wire clk,rst_n,uart_rx,spi_miso,
 output wire uart_tx,spi_sclk,spi_cs_n,spi_mosi,
 inout wire i2c_sda,i2c_scl,output wire bus_fault
);
 wire [31:0] ha,hwd,hrd,ud,sd,id,md,pd;
 wire hw,hl,hready,su,ss,si,sm,s_pmu,ur,sr,ir,mr,pr;
 wire [1:0] ht,hresp,up,sp,ip,mp,pp;
 wire [2:0] hs,hb,gate_active,gated_clk,core_busy,bus_busy;wire [3:0] hp;
 wire [31:0] wb_i_adr,wb_i_dat; wire wb_i_cyc,wb_i_stb,wb_i_we,wb_i_ack,wb_i_err; wire [3:0] wb_i_sel;
 wb_instruction_rom #(.WAIT_CYCLES(WB_IMEM_WAIT)) imem(.clk(clk),.rst_n(rst_n),
  .adr_i(wb_i_adr),.cyc_i(wb_i_cyc),.stb_i(wb_i_stb),.we_i(wb_i_we),.sel_i(wb_i_sel),
  .dat_o(wb_i_dat),.ack_o(wb_i_ack),.err_o(wb_i_err));
 Pipeline_Top cpu(.clk(clk),.rst(rst_n),.HADDR(ha),.HWDATA(hwd),.HWRITE(hw),
  .HTRANS(ht),.HSIZE(hs),.HBURST(hb),.HPROT(hp),.HLOCK(hl),
  .HREADY(hready),.HRESP(hresp),.HRDATA(hrd),.bus_fault(bus_fault),
  .WBI_ADR(wb_i_adr),.WBI_CYC(wb_i_cyc),.WBI_STB(wb_i_stb),.WBI_WE(wb_i_we),
  .WBI_SEL(wb_i_sel),.WBI_DAT(wb_i_dat),.WBI_ACK(wb_i_ack),.WBI_ERR(wb_i_err));
 ahb_peripheral_fabric fabric(.HCLK(clk),.HRESETn(rst_n),.HADDR(ha),.HTRANS(ht),
  .gate_active(gate_active),.sel_uart(su),.sel_spi(ss),.sel_i2c(si),.sel_ram(sm),.sel_pmu(s_pmu),.bus_busy(bus_busy),
  .uart_ready(ur),.spi_ready(sr),.i2c_ready(ir),.ram_ready(mr),.pmu_ready(pr),
  .uart_resp(up),.spi_resp(sp),.i2c_resp(ip),.ram_resp(mp),.pmu_resp(pp),
  .uart_data(ud),.spi_data(sd),.i2c_data(id),.ram_data(md),.pmu_data(pd),.HREADY(hready),.HRESP(hresp),.HRDATA(hrd));
 ahb_pmu pmu(.HCLK(clk),.HRESETn(rst_n),.HSEL(s_pmu),.HREADY(hready),.HADDR(ha),
  .HWDATA(hwd),.HTRANS(ht),.HWRITE(hw),.HSIZE(hs),.HRDATA(pd),.HREADYOUT(pr),.HRESP(pp),
  .busy(core_busy | bus_busy),.gated_clk(gated_clk),.gate_active(gate_active),.power_request(),.clock_request());
 ahb_uart uart(.HCLK(clk),.core_clk(gated_clk[0]),.pmu_busy(core_busy[0]),.HRESETn(rst_n),.HSEL(su),.HREADY(hready),.HADDR(ha),
  .HTRANS(ht),.HWRITE(hw),.HSIZE(hs),.HWDATA(hwd),.HRDATA(ud),.HREADYOUT(ur),.HRESP(up),.uart_rx(uart_rx),.uart_tx(uart_tx));
 ahb_spi_master spi(.HCLK(clk),.core_clk(gated_clk[1]),.pmu_busy(core_busy[1]),.HRESETn(rst_n),.HSEL(ss),.HREADY(hready),.HADDR(ha),
  .HTRANS(ht),.HWRITE(hw),.HSIZE(hs),.HWDATA(hwd),.HRDATA(sd),.HREADYOUT(sr),.HRESP(sp),.sclk(spi_sclk),.cs_n(spi_cs_n),.mosi(spi_mosi),.miso(spi_miso));
 ahb_i2c_master i2c(.HCLK(clk),.core_clk(gated_clk[2]),.pmu_busy(core_busy[2]),.HRESETn(rst_n),.HSEL(si),.HREADY(hready),.HADDR(ha),
  .HTRANS(ht),.HWRITE(hw),.HSIZE(hs),.HWDATA(hwd),.HRDATA(id),.HREADYOUT(ir),.HRESP(ip),.sda(i2c_sda),.scl(i2c_scl));
 ahb_ram ram(.HCLK(clk),.HRESETn(rst_n),.HSEL(sm),.HREADY(hready),.HADDR(ha),
  .HTRANS(ht),.HWRITE(hw),.HSIZE(hs),.HWDATA(hwd),.HRDATA(md),.HREADYOUT(mr),.HRESP(mp));
endmodule
