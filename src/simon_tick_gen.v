// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: © 2026 Uri Shaked

`default_nettype none

// Programmable prescaler that turns the system clock into the 50 kHz game
// tick (clock enable) expected by the Simon core (ticks_per_milli = 50).
//
//   clk_sel | divide by | system clock
//   --------+-----------+-------------
//     0     |      1    |   50 kHz (external game clock, original TT mode)
//     1     |     20    |    1 MHz
//     2     |    200    |   10 MHz
//     3     |    240    |   12 MHz
//     4     |    500    |   25 MHz
//     5     |   1000    |   50 MHz (MPC / mpc-soc system clock)
//     6     |   2000    |  100 MHz
//     7     |   2400    |  120 MHz

module simon_tick_gen (
    input  wire       clk,
    input  wire       rst,
    input  wire [2:0] clk_sel,
    output reg        tick
);
  reg [11:0] counter;
  reg [11:0] limit;

  always @(*) begin
    case (clk_sel)
      3'd0: limit = 12'd0;
      3'd1: limit = 12'd19;
      3'd2: limit = 12'd199;
      3'd3: limit = 12'd239;
      3'd4: limit = 12'd499;
      3'd5: limit = 12'd999;
      3'd6: limit = 12'd1999;
      default: limit = 12'd2399;
    endcase
  end

  always @(posedge clk) begin
    if (rst) begin
      counter <= 0;
      tick <= 0;
    end else if (counter >= limit) begin
      counter <= 0;
      tick <= 1;
    end else begin
      counter <= counter + 1;
      tick <= 0;
    end
  end

endmodule
