# Simon Says — OpenECOS ICS55 MPW (dedicated die)

![](../../workflows/gds/badge.svg) ![](../../workflows/test/badge.svg)

Port of the [Tiny Tapeout Simon Says game](https://github.com/urish/tt-simon-game)
to the [OpenECOS ECOS Factory](https://factory.openecos.com) **MPW** template:
a dedicated 1 mm × 1 mm die on the ICsprout 55 nm open PDK (ICS55), delivered
as a single GDS file.

This is one of three variants of the same design:

| Variant | Template | Handoff | Repository |
| --- | --- | --- | --- |
| **MPW** (this repo) | Dedicated die, ≥ 1 × 1 mm² | one `.gds` | [ecos-simon-mpw](https://github.com/ttcodebot/ecos-simon-mpw) |
| MPC-Frame | Shared chip, 73 user pads, 0.07 × 0.07 – 1 × 1 mm² | `.def` + gate-level `.v` | [ecos-simon-mpc-frame](https://github.com/ttcodebot/ecos-simon-mpc-frame) |
| MPC-SoC | Shared RISC-V SoC chip, AXI4 core slot, 0.1 × 0.1 – 1 × 1 mm² | `.def` + gate-level `.v` | [ecos-simon-mpc-soc](https://github.com/ttcodebot/ecos-simon-mpc-soc) |

![Simon Says](docs/tt-simon-game.jpg)

## About the game

Simon says is a simple electronic memory game: the user has to repeat a growing
sequence of colors. The sequence is displayed by lighting up the LEDs. Each color
also has a corresponding tone. In each turn, the game plays the sequence, then
waits for the user to repeat it by pressing the buttons. A correct repeat plays a
"leveling-up" sound, adds a color, and moves to the next turn; a mistake plays a
game-over sound and restarts the game. The score is shown on a two digit
7-segment display. Online simulation (with wiring diagram):
https://wokwi.com/projects/408757730664700929

## What changed in the ICS55 port

The game core (`simon.v`, `sound_gen.v`, `score.v`, `galois_lfsr.v`) is the
original RTL with one addition: every module takes a clock-enable (`ena` /
`tick`) so the game advances one tick per enable pulse instead of one tick per
clock. `simon_tick_gen.v` derives the 50 kHz game tick from the system clock:

| `clk_sel` | divide by | system clock |
| --- | --- | --- |
| 0 | 1 | 50 kHz (original Tiny Tapeout mode, external game clock) |
| 1 | 20 | 1 MHz |
| 2 | 200 | 10 MHz |
| 3 | 240 | 12 MHz |
| 4 | 500 | 25 MHz |
| 5 | 1000 | 50 MHz |
| 6 | 2000 | 100 MHz |
| 7 | 2400 | 120 MHz |

With `clk_sel = 0` the design is cycle-equivalent to the Tiny Tapeout version,
which is how the original cocotb tests are reused unchanged. The Tiny Tapeout
ring-oscillator clock source is kept in the sources as an optional **test
structure** (`RING_OSC` parameter; `rosc_out` carries its divided output) but
it is **off by default**: the ECC flow's Yosys equivalence check and STA do not
handle the combinational loop of the inverter chain (208 unproven equivalence
points with it enabled), so the game runs from the single external clock only.

## Pinout (`simon_mpw_top`)

| Port | Dir | Description |
| --- | --- | --- |
| `clk` | in | system clock (see `clk_sel`) |
| `rst_n` | in | active-low reset (synchronous) |
| `btn[3:0]` | in | buttons 1–4 (active high, pull-down) |
| `seginv` | in | 7-segment polarity: 1 = common anode, 0 = common cathode |
| `clk_sel[2:0]` | in | game tick prescaler select (table above) |
| `led[3:0]` | out | LEDs 1–4 |
| `speaker` | out | tone output (square wave) |
| `seg[6:0]` | out | 7-segment segments a–g |
| `dig[1:0]` | out | digit common pins (dig1 = tens, dig2 = ones) |
| `tick` | out | 50 kHz game tick (debug) |
| `rosc_out` | out | divided ring-oscillator clock (test structure, constant 0 unless built with `RING_OSC=1`) |

> **Pad ring:** ECOS Factory's MPW template requires a complete die GDS. The
> current OpenECOS Chip Compiler (ECC) flow hardens a core-level block with
> pins on MET3/MET4 at the die boundary; ICS55 IO pad cells
> (`ICsprout_55LLULP1233_IO`) are not inserted by the flow. The GDS produced
> here is therefore the 1 × 1 mm core; adding the pad ring / power pads is
> the remaining step to close with ECOS Factory during signoff review.

## Repository layout

```
src/         RTL (game core + simon_mpw_top.v)
test/        cocotb testbench (RTL and gate-level), same tests as the TT project
harden/      ECC project (ecc.toml, sources.txt) — 1000 × 1000 µm die, compact core
scripts/     install_ecc.sh, harden.sh, summarize.py, patch_ecc_lec.py
dist/        deliverables written by scripts/harden.sh (CI artifact)
```

## Tests

```sh
pip install -r test/requirements.txt      # cocotb 2.0, pytest
sudo apt install iverilog
make -C test -B                            # RTL: test_simon, test_long_game_sequence
make -C test -B GATES=yes                  # gate-level netlist from dist/ (needs the ICS55 PDK)
```

The `test` workflow runs Verilator lint and the RTL cocotb tests on every push;
the `gds` workflow hardens the design and then runs the same cocotb tests on
the gate-level netlist with the ICS55 standard-cell Verilog models.

## Hardening (RTL → GDS on ICS55)

```sh
scripts/install_ecc.sh     # ECC CLI + OSS CAD Suite (Yosys) + ICS55 PDK (~6 GB)
scripts/harden.sh          # 15-step ECC rtl2gds flow, writes dist/
```

`dist/` contains: `simon_mpw_top.gds` (**the MPW upload**: the full 1 × 1 mm
layout with all standard-cell geometry, fillers and power grid),
`simon_mpw_top_harden_abstract.gds` (pins + obstruction only, for integration),
`simon_mpw_top.def`, `simon_mpw_top.v` (final gate-level netlist), `.lef`/`.lib`/`.png`,
`simon_mpw_top_signoff_package.tar.gz` (full ECC signoff package), the ECC
design summary / QoR / checklist reports and `summary.md` (area, utilization,
timing, DRC/LVS).

### ECC LEC note

ECC's Yosys equivalence step only pairs top-level ports (it purges internal
net names before `equiv_make`), so any design with state that is not visible
at the ports is reported "unproven" even when the netlists are equivalent.
`scripts/patch_ecc_lec.py` (applied by `install_ecc.sh`) pairs flip-flop
outputs as well; with it the LEC proves all equivalence points.

## Results

See `dist/summary.md` in the latest `gds` workflow artifact. The numbers from
the reference run are in [docs/results.md](docs/results.md).

## Cost (ECOS Factory, estimate)

ECOS Factory prices the MPW template by die area ("scales with die area,
estimate") with the final quote issued after signoff review; public
55 nm MPW reference rates are roughly ¥30–40k / mm², and eligible open-source
work can receive coupons of up to 100 %. See [docs/results.md](docs/results.md).

## License

Apache-2.0 (same as the original project). © 2023–2026 Uri Shaked.
