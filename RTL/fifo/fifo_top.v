// FIFO Top Block

module fifo_top 
( input sclk,
  input s_rstn,
  input wa_push,
  input [48:0]wa_wdata,
  output wa_full,
  input wd_push,
  input wa_pop,
  input [37:0]wd_wdata,
  output wd_full,
  input ra_push,
  input [48:0]ra_wdata,
  output ra_full,
  input rd_pop,
  output [39:0] rd_rdata,
  output rd_empty,
  input m_rstn,
  input mclk,
  output [48:0] wa_rdata,
  output wa_empty,
  input wd_pop,
  output [37:0] wd_rdata,
  output wd_empty,
  input ra_pop,
  output [48:0]ra_rdata,
  output ra_empty,
  input rd_push,
  input [39:0]rd_wdata,
  output rd_full );
  
// ############################### Write Address FIFO ##############################
dp_fifo #(48,3)
WA (.wclk(sclk), 
    .wrstn(s_rstn), 
    .push(wa_push),
    .wdata(wa_wdata), 
    .rclk(mclk),
    .rrstn(m_rstn),
    .pop(wa_pop),
    .rdata(wa_rdata),
    .empty(wa_empty),
    .full(wa_full) );
  
// ############################### Write Data FIFO ##############################
dp_fifo #(37,8)
WD (.wclk(sclk), 
    .wrstn(s_rstn), 
    .push(wd_push),
    .wdata(wd_wdata), 
    .rclk(mclk),
    .rrstn(m_rstn),
    .pop(wd_pop),
    .rdata(wd_rdata),
    .empty(wd_empty),
    .full(wd_full) );


// ############################### Read Address FIFO ##############################
dp_fifo #(48,3)
RA (.wclk(sclk), 
    .wrstn(s_rstn), 
    .push(ra_push),
    .wdata(ra_wdata), 
    .rclk(mclk),
    .rrstn(m_rstn),
    .pop(ra_pop),
    .rdata(ra_rdata),
    .empty(ra_empty),
    .full(ra_full) );


// ############################### Read Data FIFO ##############################
dp_fifo #(38,8)
RD (.wclk(sclk), 
    .wrstn(s_rstn), 
    .push(rd_push),
    .wdata(rd_wdata), 
    .rclk(mclk),
    .rrstn(m_rstn),
    .pop(rd_pop),
    .rdata(rd_rdata),
    .empty(rd_empty),
    .full(rd_full) );
	
endmodule	