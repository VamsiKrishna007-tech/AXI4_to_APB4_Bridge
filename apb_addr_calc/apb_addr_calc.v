// Address Calculation Block

module app_addr_calc
#( parameter AW = 32,
   parameter LW = 4,
   parameter IW = 4);

( input [AW+IW+LW+7:0] waddr_ctrl_rdata,
  input waddr_fifo_empty,
  output waddr_fifo_pop,
  input PCLK,
  input PRESETn,
  input waddr_ren,
  input raddr_ren,
  input [AW+IW+LW+7:0] raddr_ctrl_rdata,
  input raddr_fifo_empty,
  output raddr_fifo_pop,
  output [AW+IW+LW+2:0] r_write_prot_addr_id,
  output [AW+IW+LW+2:0] r_read_prot_addr_id,
  output w_addr_fe,
  output r_addr_fe );
  
  
// Internal Signals
reg waddr_calc_progress;
reg raddr_calc_progress;

reg raddr_pop, waddr_pop;
reg w_pop, r_pop;

wire [2:0] awprot, arprot;
wire [IW-1:0] awid, arid;

reg w_addr_push, r_addr_push;
wire w_addr_ff, r_addr_ff;

wire [AW-1:0] write_start_address;
reg [AW-1:0] write_next_address;
wire [LW-1:0] awlen;
wire [2:0] awsize;
wire [1:0] awburst;

wire [AW-1:0] read_start_address;
reg [AW-1:0] read_next_address;
wire [LW-1:0] arlen;
wire [2:0] arsize;
wire [1:0] arburst; 

wire [8:0] w_no_of_bytes;
wire [8:0] r_no_of_bytes;
wire [AW+IW+LW+2:0] w_write_prot_addr_id, w_read_prot_addr_id;

reg [LW:0] w_count;
reg [LW:0] r_count;

// Extracting info from write address
assign  write_start_address = waddr_ctrl_rdata[(AW+IW-1):IW];
assign w_write_prot_addr_id = {awprot, awlen, write_next_address, awid};
assign w_no_of_bytes = 2**awsize;
assign awid = waddr_ctrl_rdata[(IW-1):0];
assign awlen = waddr_ctrl_rdata[(AW+IW+LW-1):(AW+IW)];
assign awsize = waddr_ctrl_rdata[(AW+IW+LW+2):(AW+IW+LW)];
assign awburst = waddr_ctrl_rdata[(AW+IW+LW+4):(AW+IW+LW+3)];
assign awprot = waddr_ctrl_rdata[(AW+IW+LW+7):(AW+IW+LW+5)];

// Extracting info for read address
assign read_start_address = raddr_ctrl_rdata[(AW+IW-1):IW];
assign w_read_prot_addr_id = {arprot, arlen, read_next_address, arid};
assign r_no_of_bytes = 2**arsize;
assign arid = raddr_ctrl_rdata[(IW-1):0];
assign arlen = raddr_ctrl_rdata[(AW+IW+LW-1):(AW+IW)];
assign arsize = raddr_ctrl_rdata[(AW+IW+LW+2):(AW+IW+LW)];
assign arburst = raddr_ctrl_rdata[(AW+IW+LW+4):(AW+IW+LW+3)];
assign arprot = raddr_ctrl_rdata[(AW+IW+LW+7):(AW+IW+LW+5)];


// Logic to generate the write address pop
always @(*) begin
  if ((!waddr_fifo_empty) &&       // FIFO should not be empty
      (!waddr_calc_progress) &&    // No ongoing calculation
	  (!w_addr_ff) &&              // The internal FIFO should not be full
      (!w_pop))                    // No Double pop in same cycle
    waddr_pop = 1'b1;
  else
    waddr_pop = 1'b0;
end


// Logic to generate the read address pop
always @(*) begin
  if ((!raddr_fifo_empty) &&       // FIFO should not be empty
      (!raddr_calc_progress) &&    // No ongoing calculation
	  (!r_addr_ff) &&              // The internal FIFO should not be full
      (!r_pop))                    // No Double pop in same cycle
    raddr_pop = 1'b1;
  else
    raddr_pop = 1'b0;
end

// Logic to calculate the write next address based on the awburst
// two burst types supported fixed & increment
always @(posedge PCLK or negedge PRESETn)
  begin
    if(!PRESETn) begin
	   w_count <= 0;              // Beat Count
	   waddr_calc_progress <= 0;  // Busy Flag
	   w_addr_push <= 0;          // FIFO push disable
	   w_pop <= 0;                // POP control reset
	end
	else begin
	   if(w_count <= {1'b0, awlen}) begin   // Generate address untill all beats are done 
	     if(!w_addr_ff) begin               // Internal FIFO not full
		   w_pop <= 1'b0;                   // Diable pop
           waddr_calc_progress <= 1'b1;     // Address calculation in progress
		   w_addr_push <= 1'b1;             // Write enable for internal FIFO
		   if(awburst == 2'b00) begin       // Burst type Fixed
      		 write_next_address <= (write_start_address / w_no_of_bytes) *w_no_of_bytes;
			 w_count <= w_count + 1'b1;     
 		   end
		   else begin                       // Burst type Increment
		     write_next_address <= ((write_start_address / w_no_of_bytes) * w_no_of_bytes) + (w_count * w_no_of_bytes);
             w_count <= w_count + 1'b1;     // Increament counter per beat
           end
	     else begin                         // If internal FIFO is full, hold everything
		   w_pop <= w_pop;                  
		   w_count <= w_count;
		   waddr_calc_progress <= waddr_calc_progress;
		   w_addr_push <= 1'b0;
		 end
		 end	
       else begin
	     if(waddr_fifo_pop) begin           // If new transaction available, pop next entry
		   w_count <= 0;
		   w_pop <= 1'b1;
		 end
		 else begin                         // If no new transaction available hold 
		   w_count <= w_count;
		   w_pop <= w_pop;
		 end
		 waddr_calc_progress <= 1'b0;
		 w_addr_push <= 1'b0;
	   end
	end   
end


// Logic to calculate the read next address based on the arburst 

// two burst types supported fixed & increment
always @(posedge PCLK or negedge PRESETn)
  begin
    if(!PRESETn) begin
	   r_count <= 0;              // Beat Count
	   raddr_calc_progress <= 0;  // Busy Flag
	   r_addr_push <= 0;          // FIFO push disable
	   r_pop <= 0;                // POP control reset
	end
	else begin
	   if(r_count <= {1'b0, arlen}) begin
	     if(!r_addr_ff) begin
		   r_pop <= 1'b0;
           raddr_calc_progress <= 1'b1;
		   r_addr_push <= 1'b1;
		   if(arburst == 2'b00) begin
      		 read_next_address <= (read_start_address / r_no_of_bytes) *r_no_of_bytes;
			 r_count <= r_count + 1'b1;
 		   end
		   else begin
		     read_next_address <= ((read_start_address / r_no_of_bytes) * r_no_of_bytes) + (r_count * r_no_of_bytes);
             r_count <= r_count + 1'b1;
           end
	     else begin
		   r_pop <= r_pop;
		   r_count <= r_count;
		   raddr_calc_progress <= raddr_calc_progress;
		   r_addr_push <= 1'b0;
		 end
		 end	
       else begin
	     if(raddr_fifo_pop) begin
		   r_count <= 0;
		   r_pop <= 1'b1;
		 end
		 else begin
		   r_count <= r_count;
		   r_pop <= r_pop;
		 end
		 raddr_calc_progress <= 1'b0;
		 r_addr_push <= 1'b0;
	   end
	end   
end

// Pulse Synchronization for write pop signal 
pulse_sync u_waddr_pop_sync (.rstn(PRESETn), .clk(PCLK), .d(waddr_pop), .p(waddr_fifo_pop));

// Pulse Synchronization for read pop signal 
pulse_sync u_raddr_pop_sync (.rstn(PRESETn), .clk(PCLK), .d(raddr_pop), .p(raddr_fifo_pop));

// Synchronous FIFO to store the write address along with control info after address calculation
sync_fifo #(.AW(2+LW), .DW(AW+IW+LW+3))
u_write_address_fifo (
.clk(PCLK), 
.rstn(PRESETn), 
.write_data(w_write_prot_addr_id), 
.push(w_addr_push), 
.pop(waddr_ren), 
.read_data(r_write_prot_addr_id), 
.empty(w_addr_fe), 
.almost_full(w_addr_ff));

// Synchronous FIFO to store the read address along with control info after address calculation
sync_fifo #(.AW(2+LW), .DW(AW+IW+LW+3))
u_read_address_fifo (
.clk(PCLK), 
.rstn(PRESETn), 
.write_data(w_read_prot_addr_id), 
.push(r_addr_push), 
.pop(raddr_ren), 
.read_data(r_read_prot_addr_id), 
.empty(r_addr_fe), 
.almost_full(r_addr_ff));

endmodule