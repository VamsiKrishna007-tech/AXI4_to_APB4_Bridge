module axi4_to_apb4 #(
    parameter AW = 32,
    parameter DW = 32,
    parameter LW = 4,
    parameter IW = 4,
    // Slaves Address
    parameter SLAVE0_BASE_ADDR  = 32'h4000_0000,
    parameter SLAVE1_BASE_ADDR  = 32'h4000_1000,
    parameter SLAVE2_BASE_ADDR  = 32'h4000_2000,
    parameter SLAVE3_BASE_ADDR  = 32'h4000_3000,
    parameter SLAVE4_BASE_ADDR  = 32'h4000_4000,
    parameter SLAVE5_BASE_ADDR  = 32'h4000_5000,
    parameter SLAVE6_BASE_ADDR  = 32'h4000_6000,
    parameter SLAVE7_BASE_ADDR  = 32'h4000_7000,
    parameter SLAVE8_BASE_ADDR  = 32'h4000_8000,
    parameter SLAVE9_BASE_ADDR  = 32'h4000_9000,
    parameter SLAVE10_BASE_ADDR = 32'h4000_A000,     // APB CSR 
    parameter OFFSET            = 32'h0000_0FFF      // OFFSET is used to ignore lower address bits so that a range of addresses maps to a single slave instead of requiring an exact match.
)
(
//############### APB4 Master Interface Signals #######################
	output [9:0]PSELx_o,
	input PCLK_i,
	input PRESENTn_i,
	output [AW-1:0] PADDR_o,
	output PENABLE_o,
	output PWRITE_o,
	output [2:0] PPROT_o,
	output [DW-1:0] PWDATA_o,
	output [(DW/8)-1:0] PSTRB_o,
	input [9:0] PREADY_i,
	input [DW-1:0] PRDATA_i_0,
	input [DW-1:0] PRDATA_i_1,
	input [DW-1:0] PRDATA_i_2,
	input [DW-1:0] PRDATA_i_3,
	input [DW-1:0] PRDATA_i_4,
	input [DW-1:0] PRDATA_i_5,
	input [DW-1:0] PRDATA_i_6,
	input [DW-1:0] PRDATA_i_7,
	input [DW-1:0] PRDATA_i_8,
	input [DW-1:0] PRDATA_i_9,
	input [9:0] PSLVERR_i,
	
//##################### AXI4 Slave Signals #############################
    input ACLK_i,
    input ARESETn_i,
    // AXI WRITE ADDRESS CHANNEL Signals
    input  [IW-1:0] AWID_i,
    input  [AW-1:0] AWADDR_i,
    input  [LW-1:0] AWLEN_i,
    input  [2:0]    AWSIZE_i,
    input  [1:0]    AWBURST_i,
    input  [2:0]    AWPROT_i,
    input           AWVALID_i,
    output          AWREADY_o,
    // AXI WRITE DATA CHANNEL Signals
    input  [DW-1:0] WDATA_i,
    input  [(DW/8)-1:0] WSTRB_i,
    input           WLAST_i,
    input           WVALID_i,
    output          WREADY_o,
    // AXI WRITE RESPONSE CHANNEL Signals
    output [IW-1:0] BID_o,
    output [1:0]    BRESP_o,
    output          BVALID_o,
    input           BREADY_i,
    // AXI READ ADDRESS CHANNEL Signals
    input  [IW-1:0] ARID_i,
    input  [AW-1:0] ARADDR_i,
    input  [LW-1:0] ARLEN_i,
    input  [2:0]    ARSIZE_i,
    input  [1:0]    ARBURST_i,
    input  [2:0]    ARPROT_i,
    input           ARVALID_i,
    output          ARREADY_o,
    // AXI READ DATA CHANNEL Signals
    output [IW-1:0] RID_o,
    output [DW-1:0] RDATA_o,
    output [1:0]    RRESP_o,
    output          RLAST_o,
    output          RVALID_o,
    input           RREADY_i
);

//################### Interal wires to connect sub-modules ##############
// FIFO Signals
wire [AW+IW+LW+7:0] waddr_ctrl_wdata, waddr_ctrl_rdata;
wire waddr_wen_push, waddr_wen_pop;
wire waddr_fifo_full, waddr_fifo_empty;
wire [(DW/8)+DW:0] wdata_ctrl_wdata, wdata_ctrl_rdata;
wire wdata_wen_push, wdata_wen_pop;
wire wdata_fifo_full, wdata_fifo_empty;
wire [AW+IW+LW+7:0] raddr_ctrl_wdata, raddr_ctrl_rdata;
wire raddr_wen_push, raddr_wen_pop;
wire raddr_fifo_full, raddr_fifo_empty;
wire [DW+IW+2:0] rdata_ctrl_wdata, rdata_ctrl_rdata;
wire rdata_wen_push, rdata_wen_pop;

// APB Signals
wire psel_ss, penable_ss, pwrite_ss;
wire [AW-1:0] paddr_ss;
wire [DW-1:0] pwdata_ss;
wire [(DW/8)-1:0] pstrb_ss;

wire [DW-1:0] prdata_ss;
wire pready_ss, pslverr_ss;

// CSR Signals
wire PSEL_CSR, PREADY_CSR, PSLVERR_CSR;
wire [DW-1:0] PRDATA_CSR;

//###################### Module Instantiations #########################

//AXI4 Slave Module
axi4_slave_interface #(
    .AW(AW), .DW(DW), .IW(IW), .LW(LW)
) u_axi4_slave (
    .ACLK(ACLK_i),
    .ARESETn(ARESETn_i),

    .AWID(AWID_i),
    .AWADDR(AWADDR_i),
    .AWLEN(AWLEN_i),
    .AWSIZE(AWSIZE_i),
    .AWBURST(AWBURST_i),
    .AWPROT(AWPROT_i),
    .AWVALID(AWVALID_i),
    .AWREADY(AWREADY_o),

    .WDATA(WDATA_i),
    .WSTRB(WSTRB_i),
    .WLAST(WLAST_i),
    .WVALID(WVALID_i),
    .WREADY(WREADY_o),

    .BID(BID_o),
    .BRESP(BRESP_o),
    .BVALID(BVALID_o),
    .BREADY(BREADY_i),

    .ARID(ARID_i),
    .ARADDR(ARADDR_i),
    .ARLEN(ARLEN_i),
    .ARSIZE(ARSIZE_i),
    .ARBURST(ARBURST_i),
    .ARPROT(ARPROT_i),
    .ARVALID(ARVALID_i),
    .ARREADY(ARREADY_o),

    .RID(RID_o),
    .RDATA(RDATA_o),
    .RRESP(RRESP_o),
    .RLAST(RLAST_o),
    .RVALID(RVALID_o),
    .RREADY(RREADY_i)
);

// FIFO BLOCK
fifos #(.DW(DW), .AW(AW), .IW(IW), .LW(LW)) u_fifos (
    .s_rstn(ARESETn_i),
    .s_clk(ACLK_i),
    .m_rstn(PRESENTn_i),
    .m_clk(PCLK_i),

    .wa_push(waddr_wen_push),
    .wa_pop(waddr_wen_pop),
    .wa_wdata(waddr_ctrl_wdata),
    .wa_rdata(waddr_ctrl_rdata),
    .wa_empty(waddr_fifo_empty),
    .wa_full(waddr_fifo_full),

    .wd_push(wdata_wen_push),
    .wd_pop(wdata_wen_pop),
    .wd_wdata(wdata_ctrl_wdata),
    .wd_rdata(wdata_ctrl_rdata),
    .wd_empty(wdata_fifo_empty),
    .wd_full(wdata_fifo_full),

    .ra_push(raddr_wen_push),
    .ra_pop(raddr_wen_pop),
    .ra_wdata(raddr_ctrl_wdata),
    .ra_rdata(raddr_ctrl_rdata),
    .ra_empty(raddr_fifo_empty),
    .ra_full(raddr_fifo_full),

    .rd_push(rdata_wen_push),
    .rd_pop(rdata_wen_pop),
    .rd_wdata(rdata_ctrl_wdata),
    .rd_rdata(rdata_ctrl_rdata)
);

// APB MASTER
apb_master_interface #(
    .AW(AW), .DW(DW), .IW(IW), .LW(LW)
) u_apb_master_interface (
    .PCLK(PCLK_i),
    .PRESETn(PRESENTn_i),
    .PSELx(psel_ss),
    .PENABLE(penable_ss),
    .PADDR(paddr_ss),
    .PPROT(PPROT_o),
    .PWRITE(pwrite_ss),
    .PWDATA(pwdata_ss),
    .PSTRB(pstrb_ss),
    .PREADY(pready_ss),
    .PRDATA(prdata_ss),
    .PSLVERR(pslverr_ss)
);

// APB SLAVE SELECTOR
apb_slave_selector #(
    .DW(DW),
    .AW(AW),
    .SLAVE0_BASE_ADDR(SLAVE0_BASE_ADDR),
    .SLAVE1_BASE_ADDR(SLAVE1_BASE_ADDR),
    .SLAVE2_BASE_ADDR(SLAVE2_BASE_ADDR),
    .SLAVE3_BASE_ADDR(SLAVE3_BASE_ADDR),
    .SLAVE4_BASE_ADDR(SLAVE4_BASE_ADDR),
    .SLAVE5_BASE_ADDR(SLAVE5_BASE_ADDR),
    .SLAVE6_BASE_ADDR(SLAVE6_BASE_ADDR),
    .SLAVE7_BASE_ADDR(SLAVE7_BASE_ADDR),
    .SLAVE8_BASE_ADDR(SLAVE8_BASE_ADDR),
    .SLAVE9_BASE_ADDR(SLAVE9_BASE_ADDR),
    .SLAVE10_BASE_ADDR(SLAVE10_BASE_ADDR),
    .OFFSET(OFFSET)
) u_apb_slave_selector (
    .PSEL(psel_ss),
    .PWRITE(pwrite_ss),
    .PENABLE(penable_ss),
    .PADDR(paddr_ss),
    .PWDATA(pwdata_ss),
    .PSTRB(pstrb_ss),
    .PRDATA(prdata_ss)
);

// APB CSR BLOCK
apb_csr #(
    .DW(DW),
    .AW(AW),
    .REGISTER_ADDRESS(SLAVE10_BASE_ADDR)
) u_apb_csr (
    .PRESETn(ARESETn_i),
    .PCLK(ACLK_i),
    .PSEL(PSEL_CSR),
    .PENABLE(penable_ss),
    .PWRITE(pwrite_ss),
    .PREADY(PREADY_CSR),
    .PADDR(paddr_ss),
    .PWDATA(pwdata_ss),
    .PRDATA(PRDATA_CSR),
    .PSLVERR(PSLVERR_CSR)
);

//###################### APB SLAVE RETURN PATH #########################

// Select Read Data from active APB slave
// Only one PSELx_o bit should be high at a time (one-hot selection)
assign prdata_slv = (PSELx_o[0]) ? PRDATA_i_0 :
                    (PSELx_o[1]) ? PRDATA_i_1 :
                    (PSELx_o[2]) ? PRDATA_i_2 :
                    (PSELx_o[3]) ? PRDATA_i_3 :
                    (PSELx_o[4]) ? PRDATA_i_4 :
                    (PSELx_o[5]) ? PRDATA_i_5 :
                    (PSELx_o[6]) ? PRDATA_i_6 :
                    (PSELx_o[7]) ? PRDATA_i_7 :
                    (PSELx_o[8]) ? PRDATA_i_8 :
                    (PSELx_o[9]) ? PRDATA_i_9 : {DW{1'b0}};

// Combine READY signals from slaves
// Only the selected slave should assert PREADY → AND with PSELx_o ensures correctness
assign pready_slv  = |(PREADY_i  & PSELx_o);

// Combine ERROR signals from slaves
// Only error from selected slave should be propagated back
assign pslverr_slv = |(PSLVERR_i & PSELx_o);



//###################### APB RETURN PATH ###############################

// Final response mux between CSR and external slaves
// CSR is given higher priority since it is an internal register block
// If CSR is selected → take CSR response
// Else → take response from external APB slaves

assign prdata_ss  = (PSEL_CSR) ? PRDATA_CSR  : prdata_slv;
assign pready_ss  = (PSEL_CSR) ? PREADY_CSR  : pready_slv;
assign pslverr_ss = (PSEL_CSR) ? PSLVERR_CSR : pslverr_slv;

endmodule