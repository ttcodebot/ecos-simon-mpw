Reference run of `scripts/harden.sh` (ECC v0.1.0-alpha.12, ICS55 PDK v1.10.102,
`rtl2gds` preset, 100 MHz target, fixed 1000 × 1000 µm die = the smallest MPW
die, with the standard cells kept in a compact core in the middle of the die
because ECC's timing optimiser crashes when they are spread over the full
square millimetre). The deliverable for the MPW template is
`dist/simon_mpw_top.gds` (core-level GDS with pins on the die boundary; see
the pad-ring note in the README). Equivalence checks are proven with the LEC
pairing patch (see `docs/ecc-lec-note.md`). The ring-oscillator test structure
is compiled out (`RING_OSC = 0`).

Cost estimate for this variant (see the pricing notes below): ECOS Factory
prices MPW by die area ("scales with die area, est.") and issues the quote
after review; with no public ICS55 rate, comparable 55 nm MPW services put a
1 mm² die at roughly **¥30–40k (≈ $4–6k)**, i.e. one to two orders of
magnitude above the shared-chip variants. Open-source coupons of up to 100 %
are stated to be possible subject to review.
