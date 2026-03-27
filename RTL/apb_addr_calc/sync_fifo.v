// Synchronous FIFO

module sync_fifo
#(parameter AW =4,
  parameter DW =8 )
( input clk, 
  input rstn, 
  input [DW-1:0]write_data,
  input push, 
  input pop, 
  output reg [DW-1:0]read_data, 
  output empty,
  output almost_full);
// Internal Signals
reg [AW:0]write_ptr, read_ptr;

// Memory
reg [(DW-1):0] memory [(1<<AW)-1:0]; 
integer i;

// Write Operation
always@ (posedge clk) begin
 if(!rstn)                   // If rstn triggered memory is cleared and write pointer is rstn to 0
  begin
   for(i = 0; i < (1<<AW); i = i + 1)
    memory[i] <= 0;    
    write_ptr <= 0;
  end
 else if(push && !almost_full)   // If push is high and memory is not almost_full
  begin
   memory[write_ptr] <= write_data;
   write_ptr <= write_ptr+1'b1;
  end
 else
   write_ptr <= write_ptr;
end
 
// Read Operation
always@ (posedge clk)
begin
 if(!rstn)                  // If rstn triggered output data is cleared and read pointer is rstn to 0
  begin
   read_data <= 0;
   read_ptr <= 0;
  end
 else if(pop && !empty)   // If pop is high and memory is not empty
  begin
   read_data <= memory[read_ptr];
   read_ptr <= read_ptr+1'b1;
  end
 else
   read_ptr <= read_ptr;
end

// almost_full Condition
assign almost_full = ((write_ptr[AW] != read_ptr[AW]) && (write_ptr[AW-1:0] == read_ptr[AW-1:0])) ? 1'b1 : 1'b0;

// Empty Condition
assign empty = (write_ptr[AW:0] == read_ptr[AW:0]);

endmodule
