// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: © 2026 Uri Shaked

`default_nettype none

// Simon Says game core with a system-clock prescaler and an optional
// ring-oscillator test structure. This is the technology-independent block
// shared by the OpenECOS MPC-Frame, MPC-SoC and MPW variants.

module simon_game #(
    parameter RING_OSC = 0  // 1: include the ring oscillator test structure
) (
    input  wire       clk,
    input  wire       rst,        // synchronous, active high
    input  wire [2:0] clk_sel,    // see simon_tick_gen
    input  wire [3:0] btn,
    input  wire       seginv,
    output wire [3:0] led,
    output wire       speaker,
    output wire [6:0] segments,
    output wire [1:0] digits,
    output wire       tick,       // 50 kHz game tick, for debugging / clock check
    output wire       rosc_out,   // divided ring oscillator output (0 when RING_OSC=0)
    output wire [9:0] tone_freq   // current tone frequency in Hz (0 = silence)
);

  simon_tick_gen tick_gen (
      .clk    (clk),
      .rst    (rst),
      .clk_sel(clk_sel),
      .tick   (tick)
  );

  simon simon1 (
      .clk            (clk),
      .rst            (rst),
      .ena            (tick),
      .ticks_per_milli(6'd50),
      .btn            (btn),
      .led            (led),
      .segments       (segments),
      .segment_digits (digits),
      .segments_invert(seginv),
      .sound          (speaker),
      .tone_freq      (tone_freq)
  );

  generate
    if (RING_OSC) begin : g_ring_osc
      wire clk_ring_osc;
      ring_osc #(
          .CHAIN_LENGTH(13),
          .DIVIDER_BITS(14)
      ) ring_osc_inst (
          .clk_out    (clk_ring_osc),
          .clk_out_div(rosc_out)
      );
    end else begin : g_no_ring_osc
      assign rosc_out = 1'b0;
    end
  endgenerate

endmodule
