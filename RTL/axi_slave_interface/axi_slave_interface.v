// AXI SLAVE Interface 

module axi_slave_interface
#( parameter AW = 32,     // Address Width
   parameter DW = 32,     // Data Width
   parameter IW = 4,      // Index Width
   parameter LW = 4 )     // Level Width
( 
// ################ AXI4 Slave Signals #####################
// Clock
input ACLK,
// Reset
input ARESETn,
// Write Address Channel (WA)
input [IW-1:0] AWID,
input [AW-1:0] AWADDR, 
input [LW-1:0] AWLEN,
input [2:0] AWSIZE, 
input [1:0] AWBURST,
input [2:0] AWPROT,
input AWVALID,                 // Write Address valid signal for AXI4 WA channel
output AWREADY,                // Write Address ready signal for AXI4 WA channel
// Write Data Channel (WD)
input [DW-1:0] WDATA,
input [(DW/8)-1:0] WSTRB, 
input WLAST, 
input WVALID,
output WREADY,
// Write Response Channel (WR)
output [IW-1:0] BID,
output [1:0] BRESP,          // Indicates the status of write response.
output BVALID,            
input BREADY,	
// Read Address Channel (RA)
input [IW-1:0] ARID,
input [AW-1:0] ARADDR,
input [LW-1:0] ARLEN,
input [2:0] ARSIZE,
input [1:0] ARBURST,
input [2:0] ARPROT,
input ARVALID,
output ARREADY,
// Read Data Channel (RD)
input RREADY,
output [IW-1:0] RID,
output [DW-1:0] RDATA,
output [1:0]RRESP,
output RLAST,
output RVALID,
// Internal Signals
output [AW+IW+LW+7:0] w_addr_ctrl,
output w_addr_wen,                 // Write address enable signal
output reg w_axi_addr_vld,         // Validity of write address for processing
input w_addr_full,                 // FIFO full indication for write address channel
output [DW+(DW/8):0] w_data_ctrl,
output w_data_wen,
input w_data_full,
output [AW+IW+LW+7:0] r_addr_ctrl,
output r_addr_wen,
output r_axi_addr_vld,
input r_addr_full,
input [DW+IW+2:0] r_data_ctrl,
output r_data_ren,
input r_data_empty,
input [1:0] wr_resp_2_axi,
input [IW-1:0] wr_bid_2_axi,
input mstr_wr_2_axi,
input use_mwerr_resp
);
wire [IW-1:0] BID_int; // Since BID & BRESP are output of axi slave and also output from
wire [1:0] BRESP_int;  // write response FSM, the declation becomes illegal and an internal wire is needed				
// ################################# Write Address Channel ######################################
assign w_addr_ctrl = {AWPROT, AWBURST, AWSIZE, AWLEN, AWADDR, AWID};   // The write address information received from AXI master is Concatinated into one signal
assign AWREADY = !w_addr_full;                                         // AWREADY is high if FIFO is not full
assign w_addr_wen = AWVALID & AWREADY;                                 // w_addr_wen is high when AWVALID & AWREADY both signals are high (Handshake Logic)

always @(posedge ACLK or negedge ARESETn) begin
	if (!ARESETn)
	  w_axi_addr_vld <= 1'b0;         
	else
	  w_axi_addr_vld <= w_addr_wen;                                    // If w_addr_wen is enabled, then internal flag w_axi_addr_vld is high which further validates write address for processing
end

// ################################# Write Data Channel ######################################
assign w_data_ctrl = {WLAST, WSTRB, WDATA};                           // Write data information is concatinated into one signal
assign WREADY = !w_data_full;                                         // WREADY is high if FIFO is not full
assign w_data_wen = WVALID & WREADY;                                  // w_data_wen is high when WVALID & WREADY both signals are high (Handshake Logic)

// ################################# Write Response FSM ######################################
write_response_fsm F1(.ACLK(ACLK), .ARESETn(ARESETn),.BREADY(BREADY),.BVALID(BVALID),.use_mwerr_resp(use_mwerr_resp),.w_axi_addr_vld(w_axi_addr_vld), .AWID(AWID), .wr_bid_2_axi(wr_bid_2_axi), .wr_resp_2_axi(wr_resp_2_axi), .mstr_wr_2_axi(mstr_wr_2_axi), .BID(BID_int), .BRESP(BRESP_int));

assign BID   = BID_int;       
assign BRESP = BRESP_int;
// ################################ Read Address Channel #####################################
assign r_axi_addr_vld = r_addr_wen;  // For Linting coverage
assign r_addr_ctrl = {ARPROT, ARBURST, ARSIZE, ARLEN, ARADDR, ARID};  // The read address information received from AXI master is Concatinated into one signal
assign ARREADY = !r_addr_full;                                        // ARREADY is high if FIFO is not full 
assign r_addr_wen = ARVALID & ARREADY;                                // r_addr_wen is high when AWVALID & AWREADY both signals are high (Handshake Logic)
													
// ################################ Read Data Channel #######################################
// r_data_ctrl = {RLAST, RRESP, RDATA, RID}; Data comes in this form from read data FIFO
assign RLAST = RVALID ? r_data_ctrl[DW+IW+2] : 1'b0;    // RLAST = r_data_ctrl[38];
assign RRESP = r_data_ctrl[DW+IW+1:DW+IW];              // RRESP = r_data_ctrl[37:36];
assign RDATA = r_data_ctrl[DW+IW-1:IW];                 // RDATA = r_data_ctrl[35:4];
assign RID = r_data_ctrl[IW-1:0];                       // RID = r_data_ctrl[3:0];

// ################################# Read Response FSM ####################################
read_response_fsm F2(.ACLK(ACLK), .ARESETn(ARESETn),.RREADY(RREADY),.r_data_empty(r_data_empty), .RVALID(RVALID), .r_data_ren(r_data_ren));

endmodule