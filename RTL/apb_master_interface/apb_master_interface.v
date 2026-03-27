// APB Master Interface

module apb_master_interface #(
    parameter DW = 32,
    parameter AW = 32,
	parameter LW = 4,
    parameter IW = 4
)
(
// APB4 Interface Signals ..
input              PCLK,
input              PRESETn,
output             PSELx,
output             PENABLE,
output             PWRITE,
output [AW-1:0]    PADDR,
output [2:0]       PPROT,
output [DW-1:0]    PWDATA,
input  [DW-1:0]    PRDATA,
output [(DW/8)-1:0] PSTRB,
input              PREADY,
input              PSLVERR,

// Internal Signals ..
input              decode_err,
input [AW+IW+LW+2:0]awaddr_ctrl,
output              waddr_ren,
input              waddr_fe,
input [(DW/8)+DW:0] wdata_strb,
output              data_ren,
input              data_fe,
input [AW+IW+LW+2:0] araddr_ctrl,
output              rdata_wen,
input              rdata_ff,
output [DW+IW+2:0] rdata_serr,
output              raddr_ren,
output              raddr_wen,
input              raddr_fe,
output [1:0]       wr_resp_2_axi,
output reg[IW-1:0]  wr_resp_id_2_axi,
output reg          wr_2_axi,
input [2:0]         access_ratio
);

// Definitions ..
parameter IDLE    = 3'b000;
parameter WSETUP  = 3'b001;
parameter WACTIVE = 3'b010;
parameter RSETUP  = 3'b011;
parameter RACTIVE = 3'b100;


// State Registers ..
reg [2:0] state, next_state;


// Internal Registers
wire wfifo_ren;
wire wlast;
wire RLAST;
wire apb_wr;
wire apb_rd;
wire apb_wr_complete;
wire [IW-1:0] RID;
reg [(2**LW):0]err;
reg [(2**LW):0]d_err;
reg [(2**LW):0]pslverr;
reg [(2**LW):0] dec_err;
reg [LW-1:0] w_count, r_count;
wire [LW-1:0]awlen, arlen;
wire [IW-1:0] awid, arid;
wire wr_resp_slv_err, wr_resp_d_err;
wire [1:0] rd_resp;

// Assignments
assign PADDR  = PWRITE ? awaddr_ctrl[AW+IW-1:IW] : araddr_ctrl[AW+IW-1:IW];
assign PWDATA = wdata_strb[DW-1:0];
assign PPROT  = PWRITE ?
awaddr_ctrl[(AW+IW+LW+2):(AW+IW+LW)] : araddr_ctrl[(AW+IW+LW+2):(AW+IW+LW)];
assign awlen = awaddr_ctrl[(AW+IW+LW-1):(AW+IW)];
assign arlen = araddr_ctrl[(AW+IW+LW-1):(AW+IW)];
assign awid = awaddr_ctrl[IW-1:0];
assign arid = araddr_ctrl[IW-1:0];
assign PSTRB = PWRITE ? wdata_strb[(DW/8)+DW-1 : DW] : {((DW/8)){1'b0}};
assign raddr_wen = 1'b0;
assign apb_wr = PSELx & PENABLE & PWRITE & PREADY;
assign apb_rd = PSELx & PENABLE & ~PWRITE & PREADY;
assign apb_wr_complete = PSELx & PENABLE & PWRITE & PREADY & wlast;
assign rd_resp = (PSELx && ~PWRITE) ?
{PSLVERR, decode_err} : 2'b00;
assign rdata_serr = {RLAST, rd_resp, PRDATA, RID};
assign rdata_wen = apb_rd;
assign wr_resp_slv_err = |(PSLVERR);
// OR all bits in PSLVERR together
assign wr_resp_d_err   = |(decode_err);
// OR all bits in decode_err together
assign wr_resp_2_axi = {wr_resp_slv_err, wr_resp_d_err};
assign waddr_ren = wfifo_ren;
assign data_ren  = wfifo_ren;

// PSELx, PWRITE & PENABLE 

assign PSELx   = (state != IDLE);
assign PWRITE  = (state == WSETUP) || (state == WACTIVE);  
assign PENABLE = (state == WACTIVE) ||
(state == RACTIVE);
assign wlast = wdata_strb[(DW/8)+DW];
assign RID = arid;

// APB FSM 
always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn)
        state <= IDLE;
    else
        state <= next_state;
end
always @(*) begin
    case (state)
        IDLE: begin
            if (wfifo_ren)
                next_state = WSETUP;
            else if (raddr_ren)
                next_state = RSETUP;
            else
                next_state = IDLE;
        end

        WSETUP: begin
            next_state = WACTIVE;
        end

        WACTIVE: begin
            if (!PREADY)
                next_state = WACTIVE;
            else if (wfifo_ren)
                next_state = WSETUP;
            else if (raddr_ren)
			    next_state = RSETUP;
			else
                next_state = IDLE;
        end

        RSETUP: begin
            next_state = RACTIVE;
        end

        RACTIVE: begin
            if (!PREADY)
                next_state = RACTIVE;
            else if (raddr_ren)
                next_state = RSETUP;
            else if (wfifo_ren)
			    next_state = WSETUP;
			else
                next_state = IDLE;
        end
        default: next_state = IDLE;
    endcase
end


// Write Response ID Logic
always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn)
        wr_resp_id_2_axi <= 0;
    else if (wlast)
        wr_resp_id_2_axi <= awid;
    else
        wr_resp_id_2_axi <= wr_resp_id_2_axi;
end


// Write Complete Signal
always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn)
        wr_2_axi <= 1'b0;
    else
        wr_2_axi <= apb_wr_complete;
end

// Arbiter ..
apb_access_arbiter u_apb_access_arb (
	.rstn(PRESETn),
	.clk (PCLK),
	.ratio(access_ratio),
	.ra_avail(!raddr_fe),
	.rd_avail(!rdata_ff),
	.wr_avail(!data_fe && !waddr_fe),
	.rd(apb_rd),
	.wr(apb_wr),
	.rd_en(raddr_ren),
	.wr_en(wfifo_ren)
	);

// FIFO


// PSLVERR & Decode Error Logic  (issue)

always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
        err     <= 1'b0;
        d_err   <= 0;
        pslverr <= 0;
        dec_err <= 0;
        w_count <= 0;
    end
    else begin
        if(w_count <= awlen) begin
         if (PWRITE && PSELx && PENABLE && PREADY) begin
            if (w_count == 0) begin
                err <= {16'b0, PSLVERR};
				d_err <= {16'b0, decode_err};
            end
            else begin
			    d_err[w_count] <= decode_err;
                err[w_count] <= PSLVERR;
            end 
		    if(w_count == awlen) begin
		        pslverr <= err;
				dec_err <= d_err;
				w_count <= 0;
            end
			else begin
			  pslverr <= pslverr;
		      dec_err <= dec_err;
			  w_count <= w_count + 1'b1;
            end     
		 end
		end 
	 else begin
            w_count <= w_count;
			err <= err;
			d_err <= d_err;
			pslverr <= pslverr;
			dec_err <= dec_err;
        end
    end
end


// RCOUNT & RLAST Logic ..

always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn)
        r_count <= 0;
    else begin
        if (r_count <= arlen) begin
            if (!PWRITE && PSELx && PENABLE && PREADY) begin
                if (r_count == arlen)
                    r_count <= 0;
                else
                    r_count <= r_count + 1'b1;
            end
            else begin
                r_count <= r_count;
            end
        end
        else begin
            r_count <= 0;
        end
    end
end

assign RLAST = (r_count == arlen) ? 1'b1 : 1'b0;

endmodule