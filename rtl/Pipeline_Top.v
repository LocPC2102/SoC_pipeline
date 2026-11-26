`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/05/2026 10:50:50 AM
// Design Name: 
// Module Name: Pipeline_Top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Pipeline_Top(clk,rst,HADDR,HWDATA,HWRITE,HTRANS,HSIZE,HBURST,HPROT,HLOCK,HREADY,HRESP,HRDATA,bus_fault,WBI_ADR,WBI_CYC,WBI_STB,WBI_WE,WBI_SEL,WBI_DAT,WBI_ACK,WBI_ERR);

    // Declaration of I/O
    input clk, rst;
    output [31:0] HADDR,HWDATA;output HWRITE,HLOCK;
    output [1:0] HTRANS;output [2:0] HSIZE,HBURST;output [3:0] HPROT;
    input HREADY;input [1:0] HRESP;input [31:0] HRDATA;
    output wire bus_fault;
    output [31:0] WBI_ADR; output WBI_CYC,WBI_STB,WBI_WE; output [3:0] WBI_SEL;
    input [31:0] WBI_DAT; input WBI_ACK,WBI_ERR;
    // Declaration of Interim Wires
    wire PCSrcE, RegWriteW, RegWriteE, ALUSrcE, MemWriteE, ResultSrcE, BranchE, RegWriteM, MemWriteM, ResultSrcM, ResultSrcW;
    wire [2:0] ALUControlE;
    wire [4:0] RD_E, RD_M, RDW;
    wire [31:0] PCTargetE, InstrD, PCD, PCPlus4D, ResultW, RD1_E, RD2_E, Imm_Ext_E, PCE, PCPlus4E, PCPlus4M, WriteDataM, ALU_ResultM;
    wire [31:0] PCPlus4W, ALU_ResultW, ReadDataW;
    wire [4:0] RS1_E, RS2_E;
    wire [1:0] ForwardBE, ForwardAE;
    // Detect load dependencies using only register operands actually read.
    wire [6:0] opcodeD = InstrD[6:0];
    wire uses_rs1 = opcodeD==7'b0000011 || opcodeD==7'b0100011 || opcodeD==7'b0110011 || opcodeD==7'b0010011 || opcodeD==7'b1100011;
    wire uses_rs2 = opcodeD==7'b0100011 || opcodeD==7'b0110011 || opcodeD==7'b1100011;
    wire load_stall = ResultSrcE && RegWriteE && RD_E!=0 &&
       ((uses_rs1 && InstrD[19:15]==RD_E) || (uses_rs2 && InstrD[24:20]==RD_E));

    

    wire request_ready, response_valid;wire [31:0] response_data;wire [1:0] response_code;
    wire bus_access=MemWriteM | ResultSrcM;
    wire fetch_wait, fetch_fault;
    reg data_fault;
    assign bus_fault=data_fault | fetch_fault;
    wire bus_stall=(bus_access && !response_valid) || bus_fault;
    wire pipeline_hold=bus_stall || fetch_wait;
    always @(posedge clk or negedge rst) begin
      if(!rst) data_fault<=0;
      else if(response_valid && response_code!=0) data_fault<=1;
    end
    ahb_master_adapter bus_master(.HCLK(clk),.HRESETn(rst),
      .req_valid(bus_access && !response_valid && !bus_fault),.req_ready(request_ready),
      .req_write(MemWriteM),.req_addr(ALU_ResultM),.req_wdata(WriteDataM),
      .rsp_valid(response_valid),.rsp_ready(!fetch_wait && !bus_fault),.rsp_rdata(response_data),.rsp_resp(response_code),
      .HADDR(HADDR),.HWDATA(HWDATA),.HWRITE(HWRITE),.HTRANS(HTRANS),.HSIZE(HSIZE),
      .HBURST(HBURST),.HPROT(HPROT),.HLOCK(HLOCK),.HREADY(HREADY),.HRESP(HRESP),.HRDATA(HRDATA));


    wire stall_pipeline = pipeline_hold || (load_stall && !PCSrcE);
    // Module Initiation
    // Fetch Stage
    fetch_cycle Fetch (
                        .clk(clk), 
                        .rst(rst), 
                        .PCSrcE(PCSrcE), 
                        .PCTargetE(PCTargetE), 
                        .InstrD(InstrD), 
                        .PCD(PCD), 
                        .PCPlus4D(PCPlus4D),
                        .Stall(stall_pipeline), .Flush(PCSrcE && !pipeline_hold),
                        .FetchWait(fetch_wait), .FetchFault(fetch_fault),
                        .wb_adr_o(WBI_ADR), .wb_cyc_o(WBI_CYC), .wb_stb_o(WBI_STB), .wb_we_o(WBI_WE),
                        .wb_sel_o(WBI_SEL), .wb_dat_i(WBI_DAT), .wb_ack_i(WBI_ACK), .wb_err_i(WBI_ERR)
                    );

    // Decode Stage
    decode_cycle Decode (
                        .clk(clk), 
                        .rst(rst), 
                        .InstrD(InstrD), 
                        .PCD(PCD), 
                        .PCPlus4D(PCPlus4D), 
                        .RegWriteW(RegWriteW), 
                        .RDW(RDW), 
                        .ResultW(ResultW), 
                        .RegWriteE(RegWriteE), 
                        .ALUSrcE(ALUSrcE), 
                        .MemWriteE(MemWriteE), 
                        .ResultSrcE(ResultSrcE),
                        .BranchE(BranchE),  
                        .ALUControlE(ALUControlE), 
                        .RD1_E(RD1_E), 
                        .RD2_E(RD2_E), 
                        .Imm_Ext_E(Imm_Ext_E), 
                        .RD_E(RD_E), 
                        .PCE(PCE), 
                        .PCPlus4E(PCPlus4E),
                        .RS1_E(RS1_E),
                        .RS2_E(RS2_E),
                        .FlushE(PCSrcE | load_stall), .Stall(pipeline_hold)
                    );

    // Execute Stage
    execute_cycle Execute (
                        .clk(clk), 
                        .rst(rst), 
                        .RegWriteE(RegWriteE), 
                        .ALUSrcE(ALUSrcE), 
                        .MemWriteE(MemWriteE), 
                        .ResultSrcE(ResultSrcE), 
                        .BranchE(BranchE), 
                        .ALUControlE(ALUControlE), 
                        .RD1_E(RD1_E), 
                        .RD2_E(RD2_E), 
                        .Imm_Ext_E(Imm_Ext_E), 
                        .RD_E(RD_E), 
                        .PCE(PCE), 
                        .PCPlus4E(PCPlus4E), 
                        .PCSrcE(PCSrcE), 
                        .PCTargetE(PCTargetE), 
                        .RegWriteM(RegWriteM), 
                        .MemWriteM(MemWriteM), 
                        .ResultSrcM(ResultSrcM), 
                        .RD_M(RD_M), 
                        .PCPlus4M(PCPlus4M), 
                        .WriteDataM(WriteDataM), 
                        .ALU_ResultM(ALU_ResultM),
                        .ResultW(ResultW),
                        .ForwardA_E(ForwardAE),
                        .ForwardB_E(ForwardBE), .Stall(pipeline_hold)
                    );
    
    // Memory Stage
    memory_cycle Memory (
                        .clk(clk), 
                        .rst(rst), 
                        .RegWriteM(RegWriteM), 
                        .MemWriteM(MemWriteM), 
                        .ResultSrcM(ResultSrcM), 
                        .RD_M(RD_M), 
                        .PCPlus4M(PCPlus4M), 
                        .WriteDataM(WriteDataM), 
                        .ALU_ResultM(ALU_ResultM), 
                        .RegWriteW(RegWriteW), 
                        .ResultSrcW(ResultSrcW), 
                        .RD_W(RDW), 
                        .PCPlus4W(PCPlus4W), 
                        .ALU_ResultW(ALU_ResultW), 
                        .ReadDataW(ReadDataW),
                        .Stall(pipeline_hold), .BusData(response_data), .BusResp(response_code)
                    );

    // Write Back Stage
    writeback_cycle WriteBack (
                        .clk(clk), 
                        .rst(rst), 
                        .ResultSrcW(ResultSrcW), 
                        .PCPlus4W(PCPlus4W), 
                        .ALU_ResultW(ALU_ResultW), 
                        .ReadDataW(ReadDataW), 
                        .ResultW(ResultW)
                    );

    // Hazard Unit
    hazard_unit Forwarding_block (
                        .rst(rst), 
                        .RegWriteM(RegWriteM), 
                        .RegWriteW(RegWriteW), 
                        .RD_M(RD_M), 
                        .RD_W(RDW), 
                        .Rs1_E(RS1_E), 
                        .Rs2_E(RS2_E), 
                        .ForwardAE(ForwardAE), 
                        .ForwardBE(ForwardBE)
                        );
endmodule


