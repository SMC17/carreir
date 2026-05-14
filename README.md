# carreir

A Zig-first physical-intelligence substrate for HVAC, cold-chain, and thermal-system research. The merchant lens applied to the physical commerce of climate-controlled infrastructure: who owns the bottleneck on the flow of refrigerated commodities, conditioned air, and grid-following loads.

## What this is

A research substrate that pairs deterministic Zig kernels with first-principles thermodynamic modeling of HVAC and cold-chain systems. Companion to the [Anti-Edison content arc](https://SMC17.github.io/stax-blog/) on the NYC steam grid and [Doctrine 06: Eight-Axis Check](https://SMC17.github.io/stax-blog/posts/doctrine-06-eight-axis-check.html). Sister project to [~/steam](https://github.com/SMC17/steam) (energy-market intelligence).

The Carrier-corporation eponym signals the operator stance: Willis Carrier didn't invent air conditioning by reading the trade press; he built the substrate (centrifugal compressor, psychrometric chart, system controls) that everyone after him had to route through.

## What this is — honest state

`v1.0.0` (2026-05-13). The previous README said "thermodynamic kernels
exist as type signatures and scaffolds, not validated numerical
routines" and gave a stale "~830 LOC" count. Both were Type-II
underclaims. Every number below was read off `wc -l` and
`zig build test`.

**Modules (11 files, 1,487 LOC Zig — `zig-cache/` and tests excluded
from "source" count below):**

| Module | Lines | Purpose | Evidence |
|---|---:|---|---|
| `src/main.zig` | 160 | Entry point; CLI dispatch; `--sovereign-build-gate` pre-commit hook | `compiled`, `unit-tested` (via dependents) |
| `src/psychrometric/mod.zig` | 120 | Moist-air primitives at std atmospheric pressure — saturation pressure (ASHRAE 2021 eq 6), humidity ratio, enthalpy, dewpoint. SI throughout, °C / kPa / kg-water-per-kg-dry-air. | `unit-tested` (16/16) |
| `src/psychrometric/tests.zig` | 154 | 16 ERT cases pinned to ASHRAE 2021 Ch.1 reference values | — |
| `src/refrigerant/mod.zig` | 205 | Refrigerant lookup tables + saturation-curve queries; R-134a / R-410A / R-32 / R-744 (CO₂) | `unit-tested` (18/18) |
| `src/refrigerant/tests.zig` | 149 | 18 ERT cases — table interpolation, monotonicity, NIST-style pinned values | — |
| `src/coldchain/log.zig` | 354 | Append-only cold-chain event log; SHA-256 entry hashes; replay; gap detection between sensor readings | `unit-tested` (7/7) |
| `experimental/carrier_core.zig` | 131 | Audit-trail node API the Red Hat sequence is being designed around | `scaffold` |
| `experimental/audit_node.zig` | 38 | Node-state struct for the carrier_core audit chain | `scaffold` |
| `experimental/ingest.zig` | 42 | Bronze-ingest sketch for SCADA / BMS sensor streams | `scaffold` |
| `experimental/main.zig` | 91 | Experimental binary entry — keeps the audit node out of the main build | `scaffold` |
| `experimental/ptx_incursion.zig` | 43 | Sketch for NVIDIA-PTX dispatch of thermodynamic kernels — *deliberate scaffold, not yet wired* | `scaffold` |

**Tests: 41/41 pass on Zig 0.16 / Linux x86_64.** Three test binaries:
psychrometric (16), refrigerant (18), cold-chain log (7).

**Verification axes:**

- `compiled` — `zig build` green; pre-commit `--sovereign-build-gate` runs `zig build test` and refuses commits with red.
- `unit-tested` — 41 ERT cases against ASHRAE 2021 Ch.1 reference values (psychrometric) and refrigerant table-interpolation invariants (saturation-curve monotonicity, NIST-pinned saturation points for R-134a / R-410A / R-32 / R-744).
- `audit-logged` — cold-chain log shape is SHA-256-chained-append-only with gap-detection between consecutive sensor reads.
- `scaffold` — the experimental/ tree (carrier_core / audit_node / ingest / ptx_incursion) is declared scaffold; it compiles but is *deliberately not wired into the main binary* until a real ingest source lands.

**Not yet:**

- **No comparison against EnergyPlus / TRNSYS / OpenStudio** reference simulations on a full HVAC system run. We pin psychrometric values to ASHRAE 2021 Ch.1 textbook examples, not to a third-party simulator's output.
- **No NIST REFPROP cross-check** for the refrigerant tables — saturation curves are pinned to published NIST-style values but not yet differential-tested against the REFPROP library.
- **No SCADA / BMS bronze ingest** — `experimental/ingest.zig` is a 42-line sketch; no real building-management-system data has been ingested.
- **No PTX dispatch** — `experimental/ptx_incursion.zig` is a 43-line API sketch with no kernels.
- **No production deployment.** Corporate engagement is gated behind the post-ship Red Hat sequence (`~/AGENT_HARNESS.md` doctrine).

The substrate is genuinely usable for ASHRAE psychrometric calculations and refrigerant-table queries today; the corporate-grade SCADA / EnergyPlus / NIST-REFPROP differential layers are explicit roadmap work for the v1.x series.

## Engineering posture

- Zig 0.16 first; deterministic kernels.
- AGPL-3.0 (the integrator wraps for commercial; the substrate stays sovereign).
- First-principles thermodynamics, no vendor SCADA coupling.
- Versioned shipping per the Virgil work-in-progress convention adapted for OSS.

## License

AGPL-3.0. See [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for PR discipline. See [SECURITY.md](SECURITY.md) for vulnerability disclosure.
