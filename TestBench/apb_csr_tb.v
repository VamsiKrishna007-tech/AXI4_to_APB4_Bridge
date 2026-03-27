`timescale 1ns/1ps

module tb_apb_csr;

  parameter DW = 32;
  parameter AW = 32;
  parameter REGISTER_ADDRESS = 32'h4000_A000;

  reg PRESETn, PCLK;
  reg PSEL, PENABLE, PWRITE;
  reg [AW-1:0] PADDR;
  reg [DW-1:0] PWDATA;

  wire [DW-1:0] PRDATA;
  wire PREADY, PSLVERR;
  wire use_mwerr_resp;
  wire [2:0] wr_rd_ratio;

  // DUT
  apb_csr #(DW, AW, REGISTER_ADDRESS) dut (
    PRESETn, PCLK, PSEL, PENABLE, PWRITE,
    PREADY, PADDR, PWDATA,
    PRDATA, PSLVERR,
    use_mwerr_resp, wr_rd_ratio
  );

  // Clock
  always #5 PCLK = ~PCLK;

  // ---------------- TASKS ----------------

  task apb_write(input [31:0] addr, input [31:0] data);
    begin
      // SETUP
      @(posedge PCLK);
      PSEL = 1; PENABLE = 0; PWRITE = 1;
      PADDR = addr; PWDATA = data;

      // ENABLE
      @(posedge PCLK);
      PENABLE = 1;

      // END
      @(posedge PCLK);
      PSEL = 0; PENABLE = 0; PWRITE = 0;
    end
  endtask

  task apb_read(input [31:0] addr);
    begin
      // SETUP
      @(posedge PCLK);
      PSEL = 1; PENABLE = 0; PWRITE = 0;
      PADDR = addr;

      // ENABLE
      @(posedge PCLK);
      PENABLE = 1;

      // END
      @(posedge PCLK);
      PSEL = 0; PENABLE = 0;
    end
  endtask

  // ---------------- TEST ----------------

  initial begin
    // Init
    PCLK = 0;
    PRESETn = 0;
    PSEL = 0; PENABLE = 0; PWRITE = 0;
    PADDR = 0; PWDATA = 0;

    // Reset
    #20 PRESETn = 1;

    // ----------------
    // 1. WRITE
    // ----------------
    apb_write(REGISTER_ADDRESS, 32'h8000_0005);

    // ----------------
    // 2. READ
    // ----------------
    apb_read(REGISTER_ADDRESS);

    // ----------------
    // 3. INVALID ACCESS
    // ----------------
    apb_write(32'h4000_A004, 32'h1234_5678);

    #50;
    $finish;
  end

  // Wave dump
  initial begin
    $dumpfile("apb_csr.vcd");
    $dumpvars(0, tb_apb_csr);
  end

endmodule