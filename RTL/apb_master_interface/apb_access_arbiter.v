// APB Access Arbiter


module apb_access_arbiter (
    input        rstn,
    input        clk,
    input  [2:0] ratio,
    input        ra_avail,
    input        rd_avail,
    input        wr_avail,
    input        rd,
	input        wr,
	output reg   rd_en,
    output reg   wr_en
);

// Definitions
parameter IDLE   = 5'b00001;
parameter RSTART = 5'b00010;
parameter RWAIT  = 5'b00100;
parameter WSTART = 5'b01000;
parameter WWAIT  = 5'b10000;


reg [4:0] cstate, nstate;
reg [2:0] ratio_r;
wire cmd;
reg [2:0] cmd_cnt;
wire both_avail;
wire r_avail;
wire w_avail;
reg wr_temp, rd_temp;
wire wr_temp1, rd_temp1;

// Ratio Register
always @(posedge clk or negedge rstn) begin
    if (!rstn)
        ratio_r <= 3'b000;
    else if (cstate == IDLE)
        ratio_r <= ratio;
    else
        ratio_r <= ratio_r;
end

assign cmd = ratio_r[2] ? wr : rd;

// Command Counter
always @(posedge clk or negedge rstn) begin
    if (!rstn)
        cmd_cnt <= 3'b000;
    else if (cstate == IDLE & (~r_avail & w_avail))
        cmd_cnt <= 3'b000;
    else if (cmd_cnt[1:0] == ratio_r[1:0])
        cmd_cnt <= 3'b000;
    else
        cmd_cnt <= cmd_cnt + 1;
end

// Availability
assign r_avail = rd_avail;
assign w_avail = wr_avail;
assign both_avail = r_avail & w_avail;

// Arbiter FSM
always @(posedge clk or negedge rstn) begin
    if (!rstn)
        cstate <= IDLE;
    else
        cstate <= nstate;
end

always @(*) begin
    case (cstate)
    IDLE: begin
        if (both_avail)
            nstate = (ratio_r[2]) ?
            WSTART : RSTART;
        else if (rd_avail)
            nstate = RSTART;
        else if (wr_avail)
            nstate = WSTART;
        else
            nstate = IDLE;
    end
    RSTART: begin
        nstate = RWAIT;
    end

    RWAIT: begin
        if (!rd_avail)
            nstate = (wr_avail) ?
            WSTART : IDLE;

        else if (both_avail && (cmd_cnt[1:0] == ratio_r[1:0]))
            nstate = (ratio_r[2]) ?
            WSTART : RSTART;

        else
            nstate = RWAIT;
    end
    WSTART: begin
        nstate = WWAIT;
    end

    WWAIT: begin
        if (!wr_avail)
            nstate = (rd_avail) ?
            RSTART : IDLE;

        else if (both_avail && (cmd_cnt[1:0] == ratio_r[1:0]))
            nstate = (ratio_r[2]) ?
            WSTART : RSTART;

        else
            nstate = WWAIT;
    end
    default: nstate = IDLE;

    endcase
end

// Read Enable Logic
always @(*) begin
    if (cstate == IDLE) begin
        if ((ratio_r[1:0] <= 2'b01) && (~ratio_r[2] & both_avail))
            rd_temp = 1'b1;
        else if ((r_avail & ~wr_avail) || (~ratio_r[2] & both_avail))
            rd_temp = 1'b1;
        else
            rd_temp = 1'b0;
    end
    else begin
        rd_temp = 1'b0;
    end
end

// Write Enable Logic
always @(*) begin
    if (cstate == IDLE) begin
        if ((ratio_r[1:0] <= 2'b01) && (ratio_r[2] & both_avail))
            wr_temp = 1'b1;
        else if ((~r_avail & w_avail) || (ratio_r[2] & both_avail))
            wr_temp = 1'b1;
        else
            wr_temp = 1'b0;
    end
    else begin
        wr_temp = 1'b0;
    end
end

// Output Registers (2-cycle pipeline)
pulse_sync u_wr_temp_sync (
    .rstn (rstn),
    .clk  (clk),
    .d    (wr_temp),
    .p    (wr_temp1)
);
pulse_sync u_rd_temp_sync (
    .rstn (rstn),
    .clk  (clk),
    .d    (rd_temp),
    .p    (rd_temp1)
);

// Final Enables
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        wr_en <= 1'b0;
        rd_en <= 1'b0;
    end
    else begin
        wr_en <= wr_temp1;
        rd_en <= rd_temp1;
    end
end

endmodule