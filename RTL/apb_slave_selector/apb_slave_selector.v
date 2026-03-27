// APB Slave Selector

module apb_slave_selector 
#(  parameter DW = 32,
    parameter AW = 32,

    // Slave base addresses
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
    parameter SLAVE10_BASE_ADDR  = 32'h4000_A000,  // APB CSR
    parameter OFFSET = 32'h0000_0FFF )             // OFFSET is used to ignore lower address bits so that a range of addresses maps to a single slave instead of requiring an exact match.

   (input PSEL,
    input PENABLE,
    input PWRITE,
    input [2:0]PPROT,
    input [AW-1:0]PADDR,
    input [DW-1:0]PWDATA,
    input [DW/8-1:0]PSTRB,

    // PRDATA from slaves
    input  [DW-1:0] prdata_0,
    input  [DW-1:0] prdata_1,
    input  [DW-1:0] prdata_2,
    input  [DW-1:0] prdata_3,
    input  [DW-1:0] prdata_4,
    input  [DW-1:0] prdata_5,
    input  [DW-1:0] prdata_6,
    input  [DW-1:0] prdata_7,
    input  [DW-1:0] prdata_8,
    input  [DW-1:0] prdata_9,
    input  [DW-1:0] prdata_10,
    input [10:0]pready,
    output pwrite,
	output [2:0]pprot,
	output [AW-1:0]paddr,
	output [DW-1:0]pwdata,
	output [(DW/8)-1:0]pstrb,
        output reg PSLVERR,
	output penable,
	output reg decode_err,
	output reg [10:0]pselx,
	input [10:0]pslverr,
	output reg PREADY,
	output reg [DW-1:0]PRDATA
     
);

// pwdata
assign pwdata = (!decode_err)? PWDATA : {(DW-1){1'b0}};
 
// pstrb 
assign pstrb = (!decode_err)? PSTRB : {((DW/8)-1){1'b0}};

// pprot
assign pprot = (!decode_err)? PPROT : 3'b0;

// penable
assign penable = (!decode_err)? PENABLE : 1'b0;

//paddr
assign paddr = (!decode_err)? PADDR : {(AW){1'b0}};

// pwrite
assign pwrite = (!decode_err)? PWRITE : 1'b0;

// logic to generate PRDATA
always @(*) begin
  if(!PWRITE) begin
    case(pselx)
	    11'b00000000001 : PRDATA = prdata_0;
		11'b00000000010 : PRDATA = prdata_1;
		11'b00000000100 : PRDATA = prdata_2;
		11'b00000001000 : PRDATA = prdata_3;
		11'b00000010000 : PRDATA = prdata_4;
		11'b00000100000 : PRDATA = prdata_5;
		11'b00001000000 : PRDATA = prdata_6;
		11'b00010000000 : PRDATA = prdata_7;
		11'b00100000000 : PRDATA = prdata_8;
		11'b01000000000 : PRDATA = prdata_9;
		11'b10000000000 : PRDATA = prdata_10;
		default         : PRDATA = 0;  
	endcase
  end
end
	
// logic to generate the pselx and decode_err
always @(*) begin
 if (PSEL) begin
    case(PADDR & (~OFFSET))
	    SLAVE0_BASE_ADDR : begin
		                     pselx = 11'b00000000001;
							 decode_err = 1'b0;
						   end
	    SLAVE1_BASE_ADDR : begin
		                     pselx = 11'b00000000010;
							 decode_err = 1'b0;
						   end
        SLAVE2_BASE_ADDR : begin
		                     pselx = 11'b00000000100;
							 decode_err = 1'b0;
						   end
		SLAVE3_BASE_ADDR : begin
		                     pselx = 11'b00000001000;
							 decode_err = 1'b0;
						   end
		SLAVE4_BASE_ADDR : begin
		                     pselx = 11'b00000010000;
							 decode_err = 1'b0;
						   end
		SLAVE5_BASE_ADDR : begin
		                     pselx = 11'b00000100000;
							 decode_err = 1'b0;
						   end
		SLAVE6_BASE_ADDR : begin
		                     pselx = 11'b00001000000;
							 decode_err = 1'b0;
						   end
		SLAVE7_BASE_ADDR : begin
		                     pselx = 11'b00010000000;
							 decode_err = 1'b0;
						   end
		SLAVE8_BASE_ADDR : begin
		                     pselx = 11'b00100000000;
							 decode_err = 1'b0;
						   end
		SLAVE9_BASE_ADDR : begin
		                     pselx = 11'b01000000000;
							 decode_err = 1'b0;
						   end
	    SLAVE10_BASE_ADDR : begin
		                     pselx = 11'b10000000000;
							 decode_err = 1'b0;
						   end				   
	    default : begin
	               pselx = 11'b0;
			       decode_err = 1'b1;
			      end
	endcase
  end
  else begin
    pselx = 11'b0;
	decode_err = 1'b0;
  end
end

// Logic for PREADY & PSLVERR
always @(*) begin
    if (decode_err) begin
        PREADY  = 1'b1;
        PSLVERR = 1'b1;
    end
    else begin
        case(pselx)
            11'b00000000001 : begin PREADY = pready[0];  PSLVERR = pslverr[0];  end
            11'b00000000010 : begin PREADY = pready[1];  PSLVERR = pslverr[1];  end
            11'b00000000100 : begin PREADY = pready[2];  PSLVERR = pslverr[2];  end
            11'b00000001000 : begin PREADY = pready[3];  PSLVERR = pslverr[3];  end
            11'b00000010000 : begin PREADY = pready[4];  PSLVERR = pslverr[4];  end
            11'b00000100000 : begin PREADY = pready[5];  PSLVERR = pslverr[5];  end
            11'b00001000000 : begin PREADY = pready[6];  PSLVERR = pslverr[6];  end
            11'b00010000000 : begin PREADY = pready[7];  PSLVERR = pslverr[7];  end
            11'b00100000000 : begin PREADY = pready[8];  PSLVERR = pslverr[8];  end
            11'b01000000000 : begin PREADY = pready[9];  PSLVERR = pslverr[9];  end
            11'b10000000000 : begin PREADY = pready[10]; PSLVERR = pslverr[10]; end
            default         : begin PREADY = 1'b0; PSLVERR = 1'b0; end
        endcase
    end
end

endmodule