`timescale 1ns/1ps

module tb_axi_slave_interface;

parameter AW = 32;
parameter DW = 32;
parameter IW = 4;

// Clock & Reset
reg ACLK;
reg ARESETn;

// AXI Write Address
reg [AW-1:0] AWADDR;
reg [3:0] AWLEN;
reg [2:0] AWSIZE;
reg [1:0] AWBURST;
reg [2:0] AWPROT;
reg [IW-1:0] AWID;
reg AWVALID;
wire AWREADY;

// AXI Write Data
reg [DW-1:0] WDATA;
reg [(DW/8)-1:0] WSTRB;
reg WLAST;
reg WVALID;
wire WREADY;

// AXI Write Response
reg BREADY;
wire [IW-1:0] BID;
wire [1:0] BRESP;
wire BVALID;

// AXI Read Address
reg [AW-1:0] ARADDR;
reg [3:0] ARLEN;
reg [2:0] ARSIZE;
reg [1:0] ARBURST;
reg [2:0] ARPROT;
reg [IW-1:0] ARID;
reg ARVALID;
wire ARREADY;

// AXI Read Data
reg RREADY;
wire [DW-1:0] RDATA;
wire [1:0] RRESP;
wire RLAST;
wire [IW-1:0] RID;
wire RVALID;

// FIFO / internal signals
reg w_addr_full, w_data_full, r_addr_full, r_data_empty;
reg use_mwerr_resp;
reg [IW-1:0] wr_bid_2_axi;
reg [1:0] wr_resp_2_axi;
reg mstr_wr_2_axi;

reg [DW+IW+2:0] r_data_ctrl;

wire w_addr_wen, w_data_wen;
wire r_addr_wen, r_data_ren;

wire [AW+IW+8:0] w_addr_ctrl;
wire [AW+IW+8:0] r_addr_ctrl;
wire [DW+(DW/8):0] w_data_ctrl;

wire w_axi_addr_vld;
wire r_axi_addr_vld;

// DUT
axi_slave_interface DUT (
    .ACLK(ACLK),
    .ARESETn(ARESETn),

    .AWADDR(AWADDR),
    .AWLEN(AWLEN),
    .AWSIZE(AWSIZE),
    .AWBURST(AWBURST),
    .AWPROT(AWPROT),
    .AWID(AWID),
    .AWVALID(AWVALID),
    .AWREADY(AWREADY),

    .WDATA(WDATA),
    .WSTRB(WSTRB),
    .WLAST(WLAST),
    .WVALID(WVALID),
    .WREADY(WREADY),

    .BREADY(BREADY),
    .BID(BID),
    .BRESP(BRESP),
    .BVALID(BVALID),

    .ARADDR(ARADDR),
    .ARLEN(ARLEN),
    .ARSIZE(ARSIZE),
    .ARBURST(ARBURST),
    .ARPROT(ARPROT),
    .ARID(ARID),
    .ARVALID(ARVALID),
    .ARREADY(ARREADY),

    .RREADY(RREADY),
    .RDATA(RDATA),
    .RRESP(RRESP),
    .RLAST(RLAST),
    .RID(RID),
    .RVALID(RVALID),

    .w_addr_full(w_addr_full),
    .w_data_full(w_data_full),
    .r_addr_full(r_addr_full),
    .r_data_empty(r_data_empty),

    .w_addr_wen(w_addr_wen),
    .w_data_wen(w_data_wen),
    .r_addr_wen(r_addr_wen),
    .r_data_ren(r_data_ren),

    .w_addr_ctrl(w_addr_ctrl),
    .r_addr_ctrl(r_addr_ctrl),
    .w_data_ctrl(w_data_ctrl),
    .r_data_ctrl(r_data_ctrl),

    .w_axi_addr_vld(w_axi_addr_vld),
    .r_axi_addr_vld(r_axi_addr_vld),

    .use_mwerr_resp(use_mwerr_resp),
    .wr_bid_2_axi(wr_bid_2_axi),
    .wr_resp_2_axi(wr_resp_2_axi),
    .mstr_wr_2_axi(mstr_wr_2_axi)
);

// Clock
always #5 ACLK = ~ACLK;

// ---------------- TASKS ----------------

// Reset
task reset_dut;
begin
    ARESETn = 0;
    AWVALID = 0; WVALID = 0; ARVALID = 0;
    BREADY = 0; RREADY = 0;
    #20;
    ARESETn = 1;
end
endtask

// Write transaction
task axi_write;
input [AW-1:0] addr;
input [DW-1:0] data;
begin
    @(posedge ACLK);
    AWADDR = addr;
    AWLEN = 0;
    AWSIZE = 3'b010;
    AWBURST = 2'b01;
    AWPROT = 0;
    AWID = 1;
    AWVALID = 1;

    wait(AWREADY);
    @(posedge ACLK) AWVALID = 0;

    WDATA = data;
    WSTRB = 4'hF;
    WLAST = 1;
    WVALID = 1;

    wait(WREADY);
    @(posedge ACLK) WVALID = 0;

    BREADY = 1;
    wait(BVALID);
    @(posedge ACLK) BREADY = 0;
end
endtask

// Read transaction
task axi_read;
input [AW-1:0] addr;
begin
    @(posedge ACLK);
    ARADDR = addr;
    ARLEN = 0;
    ARSIZE = 3'b010;
    ARBURST = 2'b01;
    ARPROT = 0;
    ARID = 2;
    ARVALID = 1;

    wait(ARREADY);
    @(posedge ACLK) ARVALID = 0;

    RREADY = 1;
    wait(RVALID);
    @(posedge ACLK) RREADY = 0;
end
endtask

// ---------------- TEST ----------------

initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_axi_slave_interface);

    ACLK = 0;

    // Defaults
    w_addr_full = 0;
    w_data_full = 0;
    r_addr_full = 0;
    r_data_empty = 0;

    use_mwerr_resp = 0;
    wr_bid_2_axi = 4'h3;
    wr_resp_2_axi = 2'b00;
    mstr_wr_2_axi = 1;

    r_data_ctrl = {1'b1, 2'b00, 32'hA5A5A5A5, 4'h2};

    reset_dut;

    // WRITE
    axi_write(32'h1000_0000, 32'hDEADBEEF);

    #20;

    // READ
    axi_read(32'h1000_0000);

    #100;
    $finish;
end

endmodule