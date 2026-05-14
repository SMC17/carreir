# carreir

A Zig-first physical-intelligence substrate for HVAC, cold-chain, and thermal-system research. The merchant lens applied to the physical commerce of climate-controlled infrastructure: who owns the bottleneck on the flow of refrigerated commodities, conditioned air, and grid-following loads.

## What this is

A research substrate that pairs deterministic Zig kernels with first-principles thermodynamic modeling of HVAC and cold-chain systems. Companion to the [Anti-Edison content arc](https://SMC17.github.io/stax-blog/) on the NYC steam grid and [Doctrine 06: Eight-Axis Check](https://SMC17.github.io/stax-blog/posts/doctrine-06-eight-axis-check.html). Sister project to [~/steam](https://github.com/SMC17/steam) (energy-market intelligence).

The Carrier-corporation eponym signals the operator stance: Willis Carrier didn't invent air conditioning by reading the trade press; he built the substrate (centrifugal compressor, psychrometric chart, system controls) that everyone after him had to route through.

## Evidence

`v1.0.0` (2026-05-13) — research-stage substrate. The v1.x line locks
the module layout and the AGPL-vs-integrator framing, not the
thermodynamic kernels themselves.

- **compiled**: `zig build` green on Zig 0.16 / Linux x86_64.
- **unit-tested**: 3/3 tests pass via the pre-commit `--sovereign-build-gate`.
- **substrate-defined**: ~830 LOC of Zig with the module layout
  documented in `docs/`; merchant-lens framing fully articulated;
  CONTRIBUTING + SECURITY in place.
- **not yet runtime-tested** against any HVAC, cold-chain, or
  psychrometric dataset. The thermodynamic kernels exist as type
  signatures and scaffolds, not validated numerical routines.
- **no comparison** against EnergyPlus / TRNSYS / OpenStudio
  reference outputs.
- Corporate engagement is gated behind the post-ship Red Hat sequence
  (`~/AGENT_HARNESS.md` doctrine). Engineers can fork and contribute
  under AGPL today; commercial wrapping comes after the substrate
  produces a validated cold-chain or HVAC result.

## Engineering posture

- Zig 0.16 first; deterministic kernels.
- AGPL-3.0 (the integrator wraps for commercial; the substrate stays sovereign).
- First-principles thermodynamics, no vendor SCADA coupling.
- Versioned shipping per the Virgil work-in-progress convention adapted for OSS.

## License

AGPL-3.0. See [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for PR discipline. See [SECURITY.md](SECURITY.md) for vulnerability disclosure.
