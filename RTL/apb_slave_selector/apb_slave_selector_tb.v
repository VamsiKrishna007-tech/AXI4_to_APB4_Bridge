`timescale 1ns/1ps

module tb_apb_slave_selector;

    // ==========================================
    // Parameters
    // ==========================================
    parameter DW = 32;
    parameter AW = 32;

    // ==========================================
    // Signal Declarations
    // ==========================================
    // APB Master Inputs to DUT
    reg PSEL;
    reg PENABLE;
    reg PWRITE;
    reg [2:0] PPROT;
    reg [AW-1:0] PADDR;
    reg [DW-1:0] PWDATA;
    reg [(DW/8)-1:0] PSTRB;

    // Slave Inputs to DUT
    reg [DW-1:0] prdata_0, prdata_1, prdata_2, prdata_3;
    reg [DW-1:0] prdata_4, prdata_5, prdata_6, prdata_7;
    reg [DW-1:0] prdata_8, prdata_9, prdata_10;
    
    reg [10:0] pready;
    reg [10:0] pslverr;

    // DUT Outputs
    wire pwrite;
    wire [2:0] pprot;
    wire [AW-1:0] paddr;
    wire [DW-1:0] pwdata;
    wire [(DW/8)-1:0] pstrb;
    wire PSLVERR;
    wire penable;
    wire decode_err;
    wire [10:0] pselx;
    wire PREADY;
    wire [DW-1:0] PRDATA;

    // ==========================================
    // DUT Instantiation
    // ==========================================
    apb_slave_selector #(
        .DW(DW),
        .AW(AW)
    ) dut (
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PPROT(PPROT),
        .PADDR(PADDR),
        .PWDATA(PWDATA),
        .PSTRB(PSTRB),
        
        .prdata_0(prdata_0), .prdata_1(prdata_1), .prdata_2(prdata_2), .prdata_3(prdata_3),
        .prdata_4(prdata_4), .prdata_5(prdata_5), .prdata_6(prdata_6), .prdata_7(prdata_7),
        .prdata_8(prdata_8), .prdata_9(prdata_9), .prdata_10(prdata_10),
        
        .pready(pready),
        .pslverr(pslverr),
        
        .pwrite(pwrite),
        .pprot(pprot),
        .paddr(paddr),
        .pwdata(pwdata),
        .pstrb(pstrb),
        .PSLVERR(PSLVERR),
        .penable(penable),
        .decode_err(decode_err),
        .pselx(pselx),
        .PREADY(PREADY),
        .PRDATA(PRDATA)
    );

    // ==========================================
    // Test Tasks
    // ==========================================
    
    // Initialize all inputs to 0
    task init_bus;
        begin
            PSEL = 0; PENABLE = 0; PWRITE = 0; PPROT = 0;
            PADDR = 0; PWDATA = 0; PSTRB = 0;
            pready = 11'h7FF; // Assume all slaves are ready by default
            pslverr = 11'h000;
            
            prdata_0 = 0; prdata_1 = 0; prdata_2 = 0; prdata_3 = 0;
            prdata_4 = 0; prdata_5 = 0; prdata_6 = 0; prdata_7 = 0;
            prdata_8 = 0; prdata_9 = 0; prdata_10 = 0;
        end
    endtask

    // Task: Simulate APB Write Transaction
    task apb_write(input [AW-1:0] addr, input [DW-1:0] data);
        begin
            // Setup Phase
            #10;
            PSEL = 1;
            PWRITE = 1;
            PADDR = addr;
            PWDATA = data;
            PSTRB = 4'hF;
            
            // Access Phase
            #10;
            PENABLE = 1;
            
            // Wait for transaction to complete (combinational delay)
            #10;
            PSEL = 0;
            PENABLE = 0;
            PWRITE = 0;
        end
    endtask

    // Task: Simulate APB Read Transaction
    task apb_read(input [AW-1:0] addr);
        begin
            // Setup Phase
            #10;
            PSEL = 1;
            PWRITE = 0;
            PADDR = addr;
            
            // Access Phase
            #10;
            PENABLE = 1;
            
            #10;
            PSEL = 0;
            PENABLE = 0;
        end
    endtask

    // ==========================================
    // Main Simulation Block
    // ==========================================
    initial begin
        $dumpfile("apb_selector_waves.vcd");
        $dumpvars(0, tb_apb_slave_selector);

        init_bus();
        #20;

        $display("--- Starting APB Selector Tests ---");

        // ---------------------------------------------------------
        // Test 1: Valid Write to Slave 0 (Base Addr: 0x4000_0000)
        // ---------------------------------------------------------
        $display("Test 1: Write to Slave 0");
        apb_write(32'h4000_0000, 32'hAAAA_BBBB);
        
        // ---------------------------------------------------------
        // Test 2: Valid Read from Slave 5 using OFFSET
        // Base Addr is 0x4000_5000. 
        // We will read from 0x4000_5A5A. The OFFSET mask should 
        // successfully route this to Slave 5.
        // ---------------------------------------------------------
        $display("Test 2: Read from Slave 5 with Address Offset");
        prdata_5 = 32'hDEAD_BEEF; // Setup dummy data from Slave 5
        apb_read(32'h4000_5A5A);
        
        // ---------------------------------------------------------
        // Test 3: Decode Error (Invalid Address)
        // ---------------------------------------------------------
        $display("Test 3: Accessing Invalid Address (Decode Error)");
        // 0xC000_0000 does not match any slave base address
        apb_write(32'hC000_0000, 32'h1122_3344);

        // ---------------------------------------------------------
        // Test 4: Slave Error Response
        // ---------------------------------------------------------
        $display("Test 4: Slave 10 Asserts Error on Read");
        prdata_10 = 32'h0000_0000;
        pslverr[10] = 1'b1; // Slave 10 will assert error
        apb_read(32'h4000_A000);
        pslverr[10] = 1'b0; // Reset error

        #40;
        $display("--- Tests Complete ---");
        $finish;
    end

endmodule