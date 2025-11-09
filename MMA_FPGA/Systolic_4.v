`timescale 1ns / 1ps
module Systolic_4 (
    clk, reset,
    a1,a2,a3,a4, b1,b2,b3,b4,
    c1,c2,c3,c4,c5,c6,c7,c8,c9,c10,c11,c12,c13,c14,c15,c16
);
  parameter data_size = 8;
  input clk, reset;
  input  [data_size-1:0] a1,a2,a3,a4,b1,b2,b3,b4;
  output [(2*data_size)-1:0] c1,c2,c3,c4,c5,c6,c7,c8,c9,c10,c11,c12,c13,c14,c15,c16;

  wire [data_size-1:0] a12,a23,a34;
  wire [data_size-1:0] b14,b25,b36,b47;

  // Row 0
  P_E PE0 (.clk(clk),.reset(reset),.in_a(a1),.in_b(b1),.out_a(a12),.out_b(b14),.out_c(c1));
  P_E PE1 (.clk(clk),.reset(reset),.in_a(a12),.in_b(b2),.out_a(a23),.out_b(b25),.out_c(c2));
  P_E PE2 (.clk(clk),.reset(reset),.in_a(a23),.in_b(b3),.out_a(a34),.out_b(b36),.out_c(c3));
  P_E PE3 (.clk(clk),.reset(reset),.in_a(a34),.in_b(b4),.out_a(),   .out_b(b47),.out_c(c4));

  // Row 1
  P_E PE4 (.clk(clk),.reset(reset),.in_a(a2),.in_b(b14),.out_a(),.out_b(),.out_c(c5));
  P_E PE5 (.clk(clk),.reset(reset),.in_a(),  .in_b(b25),.out_a(),.out_b(),.out_c(c6));
  P_E PE6 (.clk(clk),.reset(reset),.in_a(),  .in_b(b36),.out_a(),.out_b(),.out_c(c7));
  P_E PE7 (.clk(clk),.reset(reset),.in_a(),  .in_b(b47),.out_a(),.out_b(),.out_c(c8));

  // Row 2
  P_E PE8  (.clk(clk),.reset(reset),.in_a(a3),.in_b(),.out_a(),.out_b(),.out_c(c9));
  P_E PE9  (.clk(clk),.reset(reset),.in_a(), .in_b(),.out_a(),.out_b(),.out_c(c10));
  P_E PE10 (.clk(clk),.reset(reset),.in_a(), .in_b(),.out_a(),.out_b(),.out_c(c11));
  P_E PE11 (.clk(clk),.reset(reset),.in_a(), .in_b(),.out_a(),.out_b(),.out_c(c12));

  // Row 3
  P_E PE12 (.clk(clk),.reset(reset),.in_a(a4),.in_b(),.out_a(),.out_b(),.out_c(c13));
  P_E PE13 (.clk(clk),.reset(reset),.in_a(), .in_b(),.out_a(),.out_b(),.out_c(c14));
  P_E PE14 (.clk(clk),.reset(reset),.in_a(), .in_b(),.out_a(),.out_b(),.out_c(c15));
  P_E PE15 (.clk(clk),.reset(reset),.in_a(), .in_b(),.out_a(),.out_b(),.out_c(c16));
endmodule