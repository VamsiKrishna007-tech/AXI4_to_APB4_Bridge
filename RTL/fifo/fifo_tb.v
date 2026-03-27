`timescale 1ns/1ps

module tb_fifo_top;

    // ==========================================
    // Signal Declarations
    // ==========================================
    reg         sclk, mclk;
    reg         s_rstn, m_rstn;

    // Write-side inputs
    reg         wa_push, wd_push, ra_push, rd_push;
    reg  [48:0] wa_wdata, ra_wdata;
    reg  [37:0] wd_wdata;
    reg  [39:0] rd_wdata;

    // Read-side inputs
    reg         wa_pop, wd_pop, ra_pop, rd_pop;

    // Status & Data outputs
    wire        wa_full, wd_full, ra_full, rd_full;
    wire        wa_empty, wd_empty, ra_empty, rd_empty;
    wire [48:0] wa_rdata, ra_rdata;
    wire [37:0] wd_rdata;
    wire [39:0] rd_rdata;

    // ==========================================
    // DUT Instantiation
    // ==========================================
    fifo_top dut (
        .sclk(sclk),           .s_rstn(s_rstn),
        .mclk(mclk),           .m_rstn(m_rstn),
        
        .wa_push(wa_push),     .wa_wdata(wa_wdata), .wa_full(wa_full),
        .wa_pop(wa_pop),       .wa_rdata(wa_rdata), .wa_empty(wa_empty),
        
        .wd_push(wd_push),     .wd_wdata(wd_wdata), .wd_full(wd_full),
        .wd_pop(wd_pop),       .wd_rdata(wd_rdata), .wd_empty(wd_empty),
        
        .ra_push(ra_push),     .ra_wdata(ra_wdata), .ra_full(ra_full),
        .ra_pop(ra_pop),       .ra_rdata(ra_rdata), .ra_empty(ra_empty),
        
        .rd_push(rd_push),     .rd_wdata(rd_wdata), .rd_full(rd_full),
        .rd_pop(rd_pop),       .rd_rdata(rd_rdata), .rd_empty(rd_empty)
    );

    // ==========================================
    // Clock Generation (Asynchronous domains)
    // ==========================================
    initial begin
        sclk = 0;
        forever #5 sclk = ~sclk; // 100 MHz write clock
    end

    initial begin
        mclk = 0;
        forever #7 mclk = ~mclk; // ~71 MHz read clock
    end

    // ==========================================
    // Tasks
    // ==========================================
    
    // Task 1: Initialize and Reset
    task apply_reset;
        begin
            s_rstn = 0; m_rstn = 0;
            wa_push = 0; wd_push = 0; ra_push = 0; rd_push = 0;
            wa_pop  = 0; wd_pop  = 0; ra_pop  = 0; rd_pop  = 0;
            wa_wdata = 0; wd_wdata = 0; ra_wdata = 0; rd_wdata = 0;
            
            #20; 
            s_rstn = 1; m_rstn = 1;
            #20;
        end
    endtask

    // Task 2: Push Data (Synchronous to sclk)
    task push_all(input [48:0] d_wa, input [37:0] d_wd, input [48:0] d_ra, input [39:0] d_rd);
        begin
            @(posedge sclk);
            wa_push = 1; wa_wdata = d_wa;
            wd_push = 1; wd_wdata = d_wd;
            ra_push = 1; ra_wdata = d_ra;
            rd_push = 1; rd_wdata = d_rd;
            @(posedge sclk);
            wa_push = 0; wd_push = 0; ra_push = 0; rd_push = 0;
        end
    endtask

    // Task 3: Pop Data (Synchronous to mclk)
    task pop_all;
        begin
            @(posedge mclk);
            wa_pop = 1; wd_pop = 1; ra_pop = 1; rd_pop = 1;
            @(posedge mclk);
            wa_pop = 0; wd_pop = 0; ra_pop = 0; rd_pop = 0;
        end
    endtask

    // ==========================================
    // Main Simulation Block
    // ==========================================
    initial begin
        // Enable waveform dumping
        $dumpfile("fifo_waveforms.vcd");
        $dumpvars(0, tb_fifo_top);

        // 1. Reset the system
        apply_reset();

        // 2. Write two sets of data into the FIFOs
        push_all(49'h1_AAAA_BBBB_CCCC, 38'h2_1111_2222, 49'h0_1234_5678_9ABC, 40'h55_AA_55_AA_55);
        push_all(49'h1_1111_2222_3333, 38'h1_AAAA_BBBB, 49'h0_DEAD_BEEF_CAFE, 40'hFF_00_FF_00_FF);
        
        // 3. Wait for synchronization (pointers crossing clock domains)
        #80; 

        // 4. Read the two sets of data out
        pop_all();
        pop_all();

        // 5. Let the simulation run a bit longer to see empty flags assert
        #80;
        $finish;
    end

endmodule