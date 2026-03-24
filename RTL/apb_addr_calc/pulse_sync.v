// Pulse Synchronizer ( rising edge only)
module pulse_sync (
    input rstn,
    input clk,
    input d,
    output p
);

reg meta1, meta2;

always @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        meta1 <= 1'b0;
        meta2 <= 1'b0;
    end
    else begin
        meta1 <= d;
        meta2 <= meta1;
    end
end

assign p = meta1 & ~meta2;

endmodule