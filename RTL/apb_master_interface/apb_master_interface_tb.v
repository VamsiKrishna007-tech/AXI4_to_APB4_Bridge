`timescale 1ns/1ps

module tb_apb_master_interface;

    // ==========================================
    // Parameters
    // ==========================================
    parameter DW = 32;
    parameter AW = 32;
    parameter LW = 4;
    parameter IW = 4;

    // ==========================================
    // Signal Declarations
    // ==========================================
    reg PCLK;
    reg PRESETn;

    // APB Bus (Outputs from Master)
    wire PSELx;
    wire PENABLE;
    wire PWRITE;
    wire [AW-1:0] PADDR;
    wire [2:0] PPROT;
    wire [DW-1:0] PWDATA;
    wire [(DW/8)-1:0] PSTRB;

    // APB Bus (Inputs from Slave)
    reg [DW-1:0] PRDATA;
    reg PREADY;
    reg PSLVERR;

    // Internal / FIFO Side Signals
    reg decode_err;
    reg [AW+IW+LW+2:0] awaddr_ctrl;
    wire waddr_ren;
    reg waddr_fe;
    
    reg [(DW/8)+DW:0] wdata_strb;
    wire data_ren;
    reg data_fe;
    
    reg [AW+IW+LW+2:0] araddr_ctrl;
    wire rdata_wen;
    reg rdata_ff;
    wire [DW+IW+2:0] rdata_serr;
    
    wire raddr_ren;
    wire raddr_wen;
    reg raddr_fe;
    
    wire [1:0] wr_resp_2_axi;
    wire [IW-1:0] wr_resp_id_2_axi;
    wire wr_2_axi;
    
    reg [2:0] access_ratio;

    // ==========================================
    // DUT Instantiation
    // ==========================================
    apb_master_interface #(
        .DW(DW), .AW(AW), .LW(LW), .IW(IW)
    ) dut (
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .PSELx(PSELx),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PADDR(PADDR),
        .PPROT(PPROT),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA),
        .PSTRB(PSTRB),
        .PREADY(PREADY),
        .PSLVERR(PSLVERR),
        .decode_err(decode_err),
        .awaddr_ctrl(awaddr_ctrl),
        .waddr_ren(waddr_ren),
        .waddr_fe(waddr_fe),
        .wdata_strb(wdata_strb),
        .data_ren(data_ren),
        .data_fe(data_fe),
        .araddr_ctrl(araddr_ctrl),
        .rdata_wen(rdata_wen),
        .rdata_ff(rdata_ff),
        .rdata_serr(rdata_serr),
        .raddr_ren(raddr_ren),
        .raddr_wen(raddr_wen),
        .raddr_fe(raddr_fe),
        .wr_resp_2_axi(wr_resp_2_axi),
        .wr_resp_id_2_axi(wr_resp_id_2_axi),
        .wr_2_axi(wr_2_axi),
        .access_ratio(access_ratio)
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
            PRDATA = 0; PREADY = 1; PSLVERR = 0; decode_err = 0;
            awaddr_ctrl = 0; waddr_fe = 1;
            wdata_strb = 0;  data_fe = 1;
            araddr_ctrl = 0; raddr_fe = 1;
            rdata_ff = 0;
            access_ratio = 3'b000; // Round robin or equal priority
            #25;
            PRESETn = 1;
            #15;
        end
    endtask

    // Pack AXI write data into the control vectors and clear empty flags
    task send_write_cmd(
        input [2:0] prot, input [3:0] len, input [31:0] addr, input [3:0] id,
        input last, input [3:0] strb, input [31:0] data
    );
        begin
            @(posedge PCLK);
            awaddr_ctrl = {prot, len, addr, id};
            wdata_strb  = {last, strb, data};
            waddr_fe = 0;
            data_fe = 0;
            
            // Wait for APB state machine to transition into WSETUP
            wait(PSELx && PWRITE);
            @(posedge PCLK);
            // APB goes to WACTIVE. Clear the FIFO empty flags since data was popped.
            waddr_fe = 1;
            data_fe = 1;
            
            // Wait for transfer to complete (PREADY)
            wait(PENABLE && PREADY);
            @(posedge PCLK);
        end
    endtask

    // Pack AXI read data into the control vector
    task send_read_cmd(
        input [2:0] prot, input [3:0] len, input [31:0] addr, input [3:0] id
    );
        begin
            @(posedge PCLK);
            araddr_ctrl = {prot, len, addr, id};
            raddr_fe = 0;
            
            wait(PSELx && !PWRITE);
            @(posedge PCLK);
            raddr_fe = 1;
            
            wait(PENABLE && PREADY);
            @(posedge PCLK);
        end
    endtask

    // ==========================================
    // Main Simulation Block
    // ==========================================
    initial begin
        $dumpfile("apb_master_waveforms.vcd");
        $dumpvars(0, tb_apb_master_interface);

        apply_reset();
        $display("--- Starting APB Master Interface Tests ---");

        // ---------------------------------------------------------
        // Test 1: Standard APB Write (No Wait States)
        // ---------------------------------------------------------
        $display("Test 1: Normal APB Write");
        // prot=0, len=0, addr=0x4000_A000, id=1, last=1, strb=0xF, data=0xDEADBEEF
        send_write_cmd(3'b000, 4'h0, 32'h4000_A000, 4'h1, 1'b1, 4'hF, 32'hDEADBEEF);
        #30;

        // ---------------------------------------------------------
        // Test 2: Standard APB Read (No Wait States)
        // ---------------------------------------------------------
        $display("Test 2: Normal APB Read");
        // Setup APB slave to respond with data 0x11223344
        PRDATA = 32'h11223344;
        send_read_cmd(3'b000, 4'h0, 32'h4000_B000, 4'h2);
        PRDATA = 32'h0; // clear bus
        #30;

        // ---------------------------------------------------------
        // Test 3: APB Write WITH Slave Wait States (PREADY = 0)
        // ---------------------------------------------------------
        $display("Test 3: APB Write with Wait States");
        PREADY = 0; // Force APB slave to stall
        
        // Push write command into FIFO
        awaddr_ctrl = {3'b000, 4'h0, 32'h4000_C000, 4'h3};
        wdata_strb  = {1'b1, 4'hF, 32'hCAFEBABE};
        waddr_fe = 0; data_fe = 0;
        
        // Wait for it to hit WACTIVE, then wait 3 more clock cycles
        wait(PENABLE);
        #30; 
        
        // Release the stall
        PREADY = 1; 
        waddr_fe = 1; data_fe = 1;
        
        wait(!PENABLE); // Wait for transaction to clear
        #50;

        $display("--- Tests Complete ---");
        $finish;
    end
endmodule