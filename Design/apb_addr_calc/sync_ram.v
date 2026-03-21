// Synchronous RAM

module sync_ram 
#( parameter AW = 32,         // Depth = 2^AW
   parameter DW = 32);        // Width = DW
( input clk,                 // Clock
  input [AW-1:0]waddr,        // Write Pointer
  input [AW-1:0]raddr,        // Read Pointer
  input [DW-1:0]wdata,        // Carries data to be written at specified location
  output reg [DW-1:0]rdata,   // Carries data to be read from specified location
  input wen,                  // Write Enable
  input ren);                 // Read Enable
  
reg [(DW-1):0] memory [(1<<AW)-1:0]; // Memory
  
// #################### Write Side #############################  
always@ (posedge clk)
  if (wen)
   memory[waddr] <= wdata;

// #################### Read Side #############################
always@ (posedge clk)
  if (ren)
   rdata <= memory[raddr];
   
endmodule
