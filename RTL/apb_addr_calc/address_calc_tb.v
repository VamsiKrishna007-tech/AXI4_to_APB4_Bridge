`timescale 1ns/1ps

module tb_apb_addr_calc;

    // ==========================================
    // Parameters
    // ==========================================
    parameter AW = 32;
    parameter LW = 4;
    parameter IW = 4;
    
    // Total input width = 3+2+3+LW+AW+IW = 48 bits
    localparam CTRL_WIDTH = AW + IW + LW + 8; 

    // ==========================================
    // Signal Declarations
    // ==========================================
    reg PCLK;
    reg PRESETn;

    // Write Channel Inputs
    reg [CTRL_WIDTH-1:0] waddr_ctrl_rdata;
    reg waddr_fifo_empty;
    wire waddr_fifo_pop;
    reg waddr_ren;
    wire w_addr_fe;
    wire [AW+IW+LW+2:0] r_write_prot_addr_id;

    // Read Channel Inputs
    reg [CTRL_WIDTH-1:0] raddr_ctrl_rdata;
    reg raddr_fifo_empty;
    wire raddr_fifo_pop;
    reg raddr_ren;
    wire r_addr_fe;
    wire [AW+IW+LW+2:0] r_read_prot_addr_id;

    // ==========================================
    // DUT Instantiation
    // ==========================================
    app_addr_calc #(
        .AW(AW), .LW(LW), .IW(IW)
    ) dut (
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        
        // Write Side
        .waddr_ctrl_rdata(waddr_ctrl_rdata),
        .waddr_fifo_empty(waddr_fifo_empty),
        .waddr_fifo_pop(waddr_fifo_pop),
        .waddr_ren(waddr_ren),
        .r_write_prot_addr_id(r_write_prot_addr_id),
        .w_addr_fe(w_addr_fe),

        // Read Side
        .raddr_ctrl_rdata(raddr_ctrl_rdata),
        .raddr_fifo_empty(raddr_fifo_empty),
        .raddr_fifo_pop(raddr_fifo_pop),
        .raddr_ren(raddr_ren),
        .r_read_prot_addr_id(r_read_prot_addr_id),
        .r_addr_fe(r_addr_fe)
    );

    // ==========================================
    // Clock Generation
    // ==========================================
    initial begin
        PCLK = 0;
        forever #5 PCLK = ~PCLK; // 100MHz clock
    end

    // ==========================================
    // Tasks
    // ==========================================
    
    task apply_reset;
        begin
            PRESETn = 0;
            waddr_fifo_empty = 1; raddr_fifo_empty = 1;
            waddr_ren = 0;        raddr_ren = 0;
            waddr_ctrl_rdata = 0; raddr_ctrl_rdata = 0;
            #25;
            PRESETn = 1;
            #15;
        end
    endtask

    // Helper task to send a write transaction and wait for the DUT to acknowledge it
    task send_write_cmd(
        input [2:0] prot, input [1:0] burst, input [2:0] size, 
        input [LW-1:0] len, input [AW-1:0] addr, input [IW-1:0] id
    );
        begin
            @(posedge PCLK);
            // Pack the data exactly as the DUT unpacks it
            waddr_ctrl_rdata = {prot, burst, size, len, addr, id};
            waddr_fifo_empty = 0; // Tell DUT data is available
            
            // Wait for DUT to pop this command
            wait(waddr_fifo_pop);
            @(posedge PCLK);
            waddr_fifo_empty = 1; // Mark empty again
        end
    endtask

    // Helper task to read out calculated addresses from the DUT's output FIFO
    task pop_write_fifo;
        begin
            @(posedge PCLK);
            if (!w_addr_fe) begin
                waddr_ren = 1;
                @(posedge PCLK);
                waddr_ren = 0;
                $display("[%0t] Write Beat Pop: Addr=0x%h, ID=%h", $time, 
                          r_write_prot_addr_id[AW+IW-1:IW],  // Extract Address
                          r_write_prot_addr_id[IW-1:0]);     // Extract ID
            end
        end
    endtask

    // ==========================================
    // Main Simulation
    // ==========================================
    initial begin
        $dumpfile("addr_calc_waveforms.vcd");
        $dumpvars(0, tb_apb_addr_calc);

        apply_reset();
        $display("--- Starting Address Calculation Tests ---");

        // ---------------------------------------------------------
        // Test 1: Write INCR Burst
        // 4 Beats (AWLEN=3), 4 Bytes/Beat (AWSIZE=2), Burst=INCR(1)
        // Base Addr: 0x1000
        // Expected Outputs: 0x1000, 0x1004, 0x1008, 0x100C
        // ---------------------------------------------------------
        $display("\nTest 1: INCR Burst (Expected 0x1000, 0x1004, 0x1008, 0x100C)");
        send_write_cmd(3'b000, 2'b01, 3'b010, 4'd3, 32'h1000, 4'hA);
        
        // Wait for calculation to finish and read out the FIFO
        #100;
        pop_write_fifo(); // Should be 0x1000
        pop_write_fifo(); // Should be 0x1004
        pop_write_fifo(); // Should be 0x1008
        pop_write_fifo(); // Should be 0x100C

        // ---------------------------------------------------------
        // Test 2: Write FIXED Burst
        // 3 Beats (AWLEN=2), 4 Bytes/Beat (AWSIZE=2), Burst=FIXED(0)
        // Base Addr: 0x2000
        // Expected Outputs: 0x2000, 0x2000, 0x2000
        // ---------------------------------------------------------
        $display("\nTest 2: FIXED Burst (Expected 0x2000, 0x2000, 0x2000)");
        send_write_cmd(3'b000, 2'b00, 3'b010, 4'd2, 32'h2000, 4'hB);
        
        #80;
        pop_write_fifo(); // Should be 0x2000
        pop_write_fifo(); // Should be 0x2000
        pop_write_fifo(); // Should be 0x2000

        #50;
        $display("--- Tests Complete ---");
        $finish;
    end

endmodule