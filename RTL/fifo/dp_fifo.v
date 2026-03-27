// dp_FIFO block

module dp_fifo 
#( parameter DW = 3,
   parameter AW = 8 )
( input wclk, 
  input wrstn, 
  input push,
  input [DW-1:0]wdata, 
  input rclk,
  input rrstn,
  input pop,
  output [DW-1:0]rdata,
  output empty,
  output full );

// Internal Signals 
 reg [AW:0] wp_binary;        // Write Pointer binary
 reg [AW:0] rp_binary;        // Read Pointer binary
 wire [AW:0] wp_gray;         // Write Pointer gray
 wire [AW:0] rp_gray;         // Read Pointer gray
 reg [AW:0] wp_binary_next;   // Buffer Write Pointer binary to prevent overflow
 reg [AW:0] rp_binary_next;   // Buffer Read Pointer binary to prevent underflow
 reg [AW:0] wp_sync_2r, wp_meta; // Synchronous flip flop & meta flip flop for write pointer synchronization
 reg [AW:0] rp_sync_2w, rp_meta; // Synchronous flip flop & meta flip flop for read pointer synchronization
 wire [AW:0] wp_sync_2r_binary;  // Binary Converted 
 wire [AW:0] rp_sync_2w_binary;  // Binary Converted

 // Note: wp_gray_next and rp_gray_next are declared but unused in your synchronizer logic, 
 // but I have kept them parameterized so they compile cleanly.
 wire [AW:0] wp_gray_next; 
 wire [AW:0] rp_gray_next;

// ############################### dp_sram #############################
dp_sram #(AW, DW)
fifo_mem(
    .wclk(wclk), 
    .rclk(rclk), 
    .waddr(wp_binary[AW-1:0]), 
    .raddr(rp_binary[AW-1:0]), 
    .wdata(wdata), 
    .rdata(rdata), 
    .wen(push & ~full), 
    .ren(pop & ~empty)
);

// ####################### Next State Logic #############################
always @(*) begin
    if (push && !full)
        wp_binary_next = wp_binary + 1;
    else
        wp_binary_next = wp_binary;

    if (pop && !empty)
        rp_binary_next = rp_binary + 1;
    else
        rp_binary_next = rp_binary;
end

// ######################## Binary to Gray Conversion ##########################
// FIX: Added #(.N(AW+1)) to pass the correct bit-width to the converters
binary_to_gray #(.N(AW+1)) B2GW  (.binary(wp_binary), .gray(wp_gray));
binary_to_gray #(.N(AW+1)) B2GR  (.binary(rp_binary), .gray(rp_gray));	
binary_to_gray #(.N(AW+1)) B2GW1 (.binary(wp_binary_next), .gray(wp_gray_next));
binary_to_gray #(.N(AW+1)) B2GR1 (.binary(rp_binary_next), .gray(rp_gray_next));
	
// ####################### Write Pointer Update ################################
always @(posedge wclk or negedge wrstn) begin
 if (!wrstn)
   wp_binary <= 0;
 else 
   wp_binary <= wp_binary_next;
end   
   
// ######################### Read Pointer Update ###############################
always @(posedge rclk or negedge rrstn) begin
 if (!rrstn)
   rp_binary <= 0;
 else
    rp_binary <= rp_binary_next;
end

// ############################# Synchronizer ##################################
// write pointer synchronizer with read clock
always @(posedge rclk or negedge rrstn) begin
 if (!rrstn) begin
    wp_meta <= 0;
    wp_sync_2r <= 0;
 end
 else begin
    wp_meta <= wp_gray;
	wp_sync_2r <= wp_meta;
 end
end

// read pointer synchronizer with write clock
always @(posedge wclk or negedge wrstn) begin
 if (!wrstn) begin
    rp_meta <= 0;
    rp_sync_2w <= 0;
 end
 else begin
    rp_meta <= rp_gray;
	rp_sync_2w <= rp_meta;
 end
end

// ######################### Gray to Binary ######################################
// FIX: Added #(.N(AW+1)) to pass the correct bit-width to the converters
gray_to_binary #(.N(AW+1)) G2BW (.gray(wp_sync_2r), .binary(wp_sync_2r_binary));
gray_to_binary #(.N(AW+1)) G2BR (.gray(rp_sync_2w), .binary(rp_sync_2w_binary));

// ############################### Full ###########################################
assign full = (wp_binary[AW] != rp_sync_2w_binary[AW]) && 
              (wp_binary[AW-1:0] == rp_sync_2w_binary[AW-1:0]);

// ################################ Empty #########################################
wire empty_int;
assign empty_int = (rp_binary[AW:0] == wp_sync_2r_binary[AW:0]);
assign empty = empty_int;

endmodule