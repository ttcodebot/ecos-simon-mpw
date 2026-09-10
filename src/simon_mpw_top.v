// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: © 2026 Uri Shaked
//
// Simon Says memory game, dedicated-die (MPW) top level for the OpenECOS
// ICS55 shuttle. All signals are plain digital core pins.

`default_nettype none

module simon_mpw_top #(
    parameter RING_OSC = 0
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [3:0] btn,
    input  wire       seginv,
    input  wire [2:0] clk_sel,
    output wire [3:0] led,
    output wire       speaker,
    output wire [6:0] seg,
    output wire [1:0] dig,
    output wire       tick,
    output wire       rosc_out
);

  wire [9:0] tone_freq_unused;

  simon_game #(
      .RING_OSC(RING_OSC)
  ) game (
      .clk     (clk),
      .rst     (!rst_n),
      .clk_sel (clk_sel),
      .btn     (btn),
      .seginv  (seginv),
      .led     (led),
      .speaker (speaker),
      .segments(seg),
      .digits  (dig),
      .tick    (tick),
      .rosc_out(rosc_out),
      .tone_freq(tone_freq_unused)
  );

  wire _unused = &{tone_freq_unused, 1'b0};

endmodule
