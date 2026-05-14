# carreir

A Zig-first physical-intelligence substrate for HVAC, cold-chain, and thermal-system research. The merchant lens applied to the physical commerce of climate-controlled infrastructure: who owns the bottleneck on the flow of refrigerated commodities, conditioned air, and grid-following loads.

## What this is

A research substrate that pairs deterministic Zig kernels with first-principles thermodynamic modeling of HVAC and cold-chain systems. Companion to the [Anti-Edison content arc](https://SMC17.github.io/stax-blog/) on the NYC steam grid and [Doctrine 06: Eight-Axis Check](https://SMC17.github.io/stax-blog/posts/doctrine-06-eight-axis-check.html). Sister project to [~/steam](https://github.com/SMC17/steam) (energy-market intelligence).

The Carrier-corporation eponym signals the operator stance: Willis Carrier didn't invent air conditioning by reading the trade press; he built the substrate (centrifugal compressor, psychrometric chart, system controls) that everyone after him had to route through.

## Status

**v1.0.0 (2026-05-13)** — production-grade hygiene milestone. The substrate is research-stage; the v1.x release line declares the existing architecture and surface stable. Corporate engagement is gated behind a post-ship Red Hat sequence — engineers can fork and contribute under AGPL today; commercial wrapping comes after.

## Engineering posture

- Zig 0.16 first; deterministic kernels.
- AGPL-3.0 (the integrator wraps for commercial; the substrate stays sovereign).
- First-principles thermodynamics, no vendor SCADA coupling.
- Versioned shipping per the Virgil work-in-progress convention adapted for OSS.

## License

AGPL-3.0. See [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for PR discipline. See [SECURITY.md](SECURITY.md) for vulnerability disclosure.
