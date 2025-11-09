`timescale 1ns / 1ps
module P_E (
    input clk,
    input reset,        // Active-high reset (connected to ~rst_n)
    input [7:0] in_a,
    input [7:0] in_b,
    output reg [7:0] out_a,
    output reg [7:0] out_b,
    output reg [15:0] out_c
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            out_a <= 0;
            out_b <= 0;
            out_c <= 0;
        end else begin
            out_a <= in_a;
            out_b <= in_b;
            out_c <= out_c + in_a * in_b;
        end
    end
endmodule