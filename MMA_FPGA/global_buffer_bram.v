`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/09/2025 02:40:46 PM
// Design Name: 
// Module Name: global_buffer_bram
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// global_buffer_bram.v
module global_buffer_bram #(
    parameter ADDR_BITS = 8,
    parameter DATA_BITS = 8
)(
    input clk,
    input rst_n,
    input ram_en,
    input wr_en,
    input [ADDR_BITS-1:0] index,
    input [DATA_BITS-1:0] data_in,
    output reg [DATA_BITS-1:0] data_out
);
    parameter DEPTH = 1 << ADDR_BITS;
    reg [DATA_BITS-1:0] mem [0:DEPTH-1];
       integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < DEPTH; i = i + 1)
                mem[i] <= 0;
        end else if (ram_en) begin
            if (wr_en)
                mem[index] <= data_in;
            else
                data_out <= mem[index];
        end
    end
endmodule
