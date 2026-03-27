`timescale 1ns/1ps

module tb_apb_csr;

    // ==========================================
    // Parameters
    // ==========================================
    parameter DW = 32;
    parameter AW = 32;
    parameter REGISTER_ADDRESS = 32'h4000_A000;

    // ==========================================
    // Signal Declarations
    // ==========================================
    // Clock and Reset
    reg PCLK;
    reg PRESETn;

    // APB Master Signals
    reg PSEL;
    reg PENABLE;
    reg PWRITE;
    reg [AW-1:0] PADDR;
    reg [DW-1:0] PWDATA;

    // APB Slave Responses
    wire PREADY;
    wire [DW-1:0] PRDATA;
    wire PSLVERR;

    // CSR Specific Outputs
    wire use_mwerr_resp;
    wire [2:0] wr_rd_ratio;

    // ==========================================
    // DUT Instantiation
    // ==========================================
    apb_csr #(
        .DW(DW),
        .AW(AW),
        .REGISTER_ADDRESS(REGISTER_ADDRESS)
    ) dut (
        .PRESETn(PRESETn),
        .PCLK(PCLK),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PREADY(PREADY),
        .PADDR(PADDR),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA),
        .PSLVERR(PSLVERR),
        .use_mwerr_resp(use_mwerr_resp),
        .wr_rd_ratio(wr_rd_ratio)
    );

    // ==========================================
    // Clock Generation
    // ==========================================
    initial begin
        PCLK = 0;
        forever #5 PCLK = ~PCLK; // 100MHz Clock
    end

    // ==========================================
    // APB Bus Tasks
    // ==========================================
    
    // System Reset Task
    task apply_reset;
        begin
            PRESETn = 0;
            PSEL = 0;
            PENABLE = 0;
            PWRITE = 0;
            PADDR = 0;
            PWDATA = 0;
            #25;
            PRESETn = 1;
            #15;
        end
    endtask

    // APB Write Transaction Task
    task apb_write(input [AW-1:0] addr, input [DW-1:0] data);
        begin
            // SETUP Phase
            @(posedge PCLK);
            PSEL = 1;
            PWRITE = 1;
            PADDR = addr;
            PWDATA = data;
            PENABLE = 0;

            // ACCESS Phase
            @(posedge PCLK);
            PENABLE = 1;

            // Wait for PREADY (Though this DUT always asserts PREADY in ENABLE state)
            wait(PREADY);

            // Back to IDLE
            @(posedge PCLK);
            PSEL = 0;
            PENABLE = 0;
            PWRITE = 0;
        end
    endtask

    // APB Read Transaction Task
    task apb_read(input [AW-1:0] addr);
        begin
            // SETUP Phase
            @(posedge PCLK);
            PSEL = 1;
            PWRITE = 0;
            PADDR = addr;
            PENABLE = 0;

            // ACCESS Phase
            @(posedge PCLK);
            PENABLE = 1;

            // Wait for PREADY
            wait(PREADY);

            // Back to IDLE
            @(posedge PCLK);
            PSEL = 0;
            PENABLE = 0;
        end
    endtask

    // ==========================================
    // Main Simulation Block
    // ==========================================
    initial begin
        // Setup waveform dumping
        $dumpfile("apb_csr_waveforms.vcd");
        $dumpvars(0, tb_apb_csr);

        // 1. Initialize and Reset
        apply_reset();
        $display("--- Starting APB CSR Tests ---");

        // ---------------------------------------------------------
        // Test 1: Valid Write to CSR
        // Expected: bit 31 goes high, bits [2:0] become 3'b101 (5)
        // ---------------------------------------------------------
        $display("Test 1: Valid APB Write");
        // Write: 32'h8000_0005 (1000...0101 in binary)
        apb_write(REGISTER_ADDRESS, 32'h8000_0005);
        #20;

        // ---------------------------------------------------------
        // Test 2: Valid Read from CSR
        // Expected: PRDATA should output 32'h8000_0005
        // ---------------------------------------------------------
        $display("Test 2: Valid APB Read");
        apb_read(REGISTER_ADDRESS);
        #20;

        // ---------------------------------------------------------
        // Test 3: Invalid Write (Wrong Address)
        // Expected: PSLVERR should go HIGH during the ENABLE state.
        // Data should NOT be overwritten.
        // ---------------------------------------------------------
        $display("Test 3: Invalid Write (Triggers PSLVERR)");
        apb_write(32'h4000_BEEF, 32'hFFFF_FFFF);
        #20;

        // ---------------------------------------------------------
        // Test 4: Invalid Read (Wrong Address)
        // Expected: PSLVERR should go HIGH. PRDATA should be 0.
        // ---------------------------------------------------------
        $display("Test 4: Invalid Read (Triggers PSLVERR)");
        apb_read(32'h4000_DEAD);
        #40;

        $display("--- Tests Complete ---");
        $finish;
    end

endmodule