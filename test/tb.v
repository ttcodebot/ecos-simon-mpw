`default_nettype none
`timescale 1ns / 1ps

// Testbench wrapper for the simon_game core (RTL and gate-level). Exposes the
// same signal names the original Tiny Tapeout cocotb tests used.
module tb ();

`ifndef NO_VCD
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end
`endif

  reg clk;
  reg rst_n;
  reg ena;
  reg [3:0] btn;
  reg seginv;
  reg [2:0] clk_sel;
  wire [3:0] led;
  wire speaker;
  wire [6:0] seg;
  wire [1:0] dig;
  wire tick;
  wire rosc_out;
  wire dig1 = dig[0];
  wire dig2 = dig[1];


  simon_mpw_top #(.RING_OSC(0)) dut (
      .clk(clk),
      .rst_n(rst_n),
      .btn(btn),
      .seginv(seginv),
      .clk_sel(clk_sel),
      .led(led),
      .speaker(speaker),
      .seg(seg),
      .dig(dig),
      .tick(tick),
      .rosc_out(rosc_out)
  );

  initial clk_sel = 3'd0;

endmodule
