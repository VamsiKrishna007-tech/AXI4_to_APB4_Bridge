// Read Response FSM

module read_response_fsm ( input wire ACLK,
                        input wire ARESETn,
						input wire RREADY, 
						input wire r_data_empty,
						output wire RVALID,
                        output wire r_data_ren);

parameter RR_IDLE  = 2'b00,            // waiting for read data
          RR_RESP_MC = 2'b01;          // sending read response to AXI
		  
reg [1:0] state, next_state;

always @(posedge ACLK or negedge ARESETn) begin
 if (!ARESETn)
    state <= RR_IDLE;
 else 
    state <= next_state; 
 end
 always @(*) begin
    case (state)
	RR_IDLE: begin
	        if (!r_data_empty)
			   next_state = RR_RESP_MC;
			else
			   next_state = RR_IDLE;
			end
	
	RR_RESP_MC: begin                     // if Master is ready to accept the data then RREADY is high 
	        if (!RREADY)
			   next_state = RR_RESP_MC;  // if Master is not ready, hold the data transaction and stay in the same state
			else
			   next_state = RR_IDLE;     // if Master is ready, complete the data transaction and return to IDLE state
			end
	
	default: next_state = RR_IDLE;
	endcase
end

assign RVALID = (state == RR_RESP_MC) ? 1'b1 : 1'b0;     // if state is RR_RESP_MC then the required data is available
assign r_data_ren = (state == RR_IDLE) & !r_data_empty;  // if FIFO is not empty and current state is IDLE state then r_data_ren is high

endmodule



/* Step-by-step:

Step 1

FIFO gets read data from APB.

r_data_empty = 0
Step 2

FSM in IDLE detects data.

RR_IDLE → RR_RESP_MC

FIFO is popped.

Step 3

AXI signals become valid.

RVALID = 1

Data is placed on bus:

RID
RDATA
RRESP
RLAST
Step 4

AXI master accepts data.

RREADY = 1

Handshake:

RVALID & RREADY
Step 5

FSM returns to IDLE.

RR_RESP_MC → RR_IDLE */