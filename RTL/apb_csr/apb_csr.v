// APB CSR Block (Control & Status Register)
module apb_csr
#(parameter DW = 32,
  parameter AW = 32,
  parameter REGISTER_ADDRESS = 32'h4000_A000)
( input PRESETn,
  input PCLK,
  input PSEL,
  input PENABLE,
  input PWRITE,
  output PREADY,
  input [AW-1:0] PADDR,
  input [DW-1:0] PWDATA,
  output [DW-1:0] PRDATA,
  output PSLVERR,
  output use_mwerr_resp,
  output [2:0] wr_rd_ratio );

localparam IDLE = 2'b00;
localparam SETUP = 2'b01;
localparam ENABLE = 2'b10;

reg [1:0] state, next_state;
wire rd_en, wr_en;
reg [31:0] csr_use_mwerr_resp_wr_rd_ratio;

always @(posedge PCLK or negedge PRESETn) begin
  if (!PRESETn)
   state = IDLE;
  else 
   state = next_state;
end

always @(*) begin
case (state)
IDLE: begin
        if (PSEL && !PENABLE)
		  next_state = SETUP;
		else
		  next_state = IDLE;
	  end
SETUP: begin
        if (PSEL && PENABLE)
		  next_state = ENABLE;
		else if (PSEL && !PENABLE)
		  next_state = SETUP;
		else 
		  next_state = IDLE;
	   end   
ENABLE: begin 
	     if (PSEL) 
		   next_state = SETUP;
		 else 
		   next_state = IDLE;
		end
		
default: next_state = IDLE;
endcase
end

// Logic for PREADY & PSLVERR signals
assign PREADY = (state == ENABLE) ? 1'b1 : 1'b0;                                  // Indicates APB slave ready to transfer
assign PSLVERR = (state == ENABLE) && (PADDR != REGISTER_ADDRESS) ? 1'b1 : 1'b0;  // APB Slave error indicator
		  
// Read & Write Enable Logic
assign wr_en = (state == ENABLE) && PSEL && (PWRITE == 1'b1) && (PADDR == REGISTER_ADDRESS) ? 1'b1 : 1'b0;
assign rd_en = (state == ENABLE) && PSEL && (PWRITE == 1'b0) && (PADDR == REGISTER_ADDRESS) ? 1'b1 : 1'b0;

// Logic to update CSR
always @(posedge PCLK or negedge PRESETn) begin
  if (!PRESETn)
    csr_use_mwerr_resp_wr_rd_ratio <= 32'b0;
  else if (wr_en)
    csr_use_mwerr_resp_wr_rd_ratio <= {
    PWDATA[31],   // use_mwerr_resp
    28'b0,        // reserved
    PWDATA[2:0]   // wr_rd_ratio
};
  else
    csr_use_mwerr_resp_wr_rd_ratio <= csr_use_mwerr_resp_wr_rd_ratio;
end

// Logic for PRDATA
assign PRDATA = rd_en ? csr_use_mwerr_resp_wr_rd_ratio : 32'b0;

assign use_mwerr_resp = csr_use_mwerr_resp_wr_rd_ratio[31];
assign wr_rd_ratio = csr_use_mwerr_resp_wr_rd_ratio[2:0];

endmodule