module write_response_fsm (
    input  wire        ACLK,
    input  wire        ARESETn,
    input  wire        BREADY,
    input  wire        use_mwerr_resp,
    input  wire        w_axi_addr_vld,
    input  wire [3:0]  AWID,

    input  wire [3:0]  wr_bid_2_axi,
    input  wire [1:0]  wr_resp_2_axi,
    input  wire        mstr_wr_2_axi,

    output reg  [3:0]  BID,
    output reg  [1:0]  BRESP,
    output wire        BVALID
);

wire mstr_wr_2_axi_s;

parameter WR_IDLE  = 2'b00,
          WR_WRESP = 2'b01,
          WR_IRESP = 2'b10,
          WR_MRESP = 2'b11;

reg [1:0] state, next_state;

always @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn)
        state <= WR_IDLE;
    else
        state <= next_state;
end

always @(*) begin
    next_state = state;

    case (state)

        WR_IDLE:
            if (use_mwerr_resp && w_axi_addr_vld)
                next_state = WR_WRESP;
            else if (!use_mwerr_resp && w_axi_addr_vld)
                next_state = WR_IRESP;

        WR_WRESP:
            next_state = WR_MRESP;

        WR_MRESP:
            if (BREADY)
                next_state = WR_IDLE;

        WR_IRESP:
            if (BREADY)
                next_state = WR_IDLE;

    endcase
end

always @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn)
        BRESP <= 2'b00;
    else if (state == WR_MRESP)
        BRESP <= wr_resp_2_axi;
	else
	    BRESP <= BRESP;
end

always @(*) begin
    if (state == WR_IRESP)
        BID <= AWID;
    else if (state == WR_MRESP)
        BID <= wr_bid_2_axi;
    else
        BID <= 4'b0000;
end

assign BVALID = use_mwerr_resp ? ((state == WR_MRESP) && mstr_wr_2_axi_s) : (state == WR_IRESP);

pulse_sync u_mstr_wr_2_axi (
    .rstn(ARESETn),
    .clk (ACLK),
    .d   (mstr_wr_2_axi),
    .p   (mstr_wr_2_axi_s)
);

endmodule