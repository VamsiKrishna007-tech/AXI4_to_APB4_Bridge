module binary_to_gray 
	#(parameter N = 4)
	  (input [N-1:0]binary,
	  output reg [N-1:0]gray);
				

assign	gray <= (binary >> 1) ^ binary;

endmodule
