# carreir status

Last touched: 2026-05-20.
current_test_count: 53

## Honest version posture

Despite the `v1.0.0` git tag, this project is **pre-1.0 in semver spirit** for two independent reasons:

1. **Zig itself is on 0.16, not 1.0.** Until the Zig language hits 1.0, no Zig project can credibly claim API stability beyond "stable on Zig 0.16 today." Tagging v1.x against a pre-1.0 substrate is a vanity claim — the language guarantees aren't there yet.
2. **No production deployment exists.** carreir has zero real-traffic operation, zero soak time, zero production-incident history. The `v1.0.0` tag was originally described as a "production-grade hygiene milestone" — the hygiene work (LICENSE / SECURITY / CONTRIBUTING / CI) is real, but those are **shipping-process hygiene**: necessary, not sufficient, for "production-grade."

The hygiene work is real. The v1.x git tag is honored for changelog continuity. But every reader should treat this as a **pre-1.0 substrate** until both gates above close.

This file is the substrate's canonical posture statement. The CHANGELOG entry on 2026-05-20 records the correction; this file is what readers should consult for current state.

## Proof-vocabulary index

The proof levels mirror the AGENT_HARNESS convention (also adopted by mast and Prism):

- `claimed` — written in a doc; no code; no test.
- `designed` — spec / API exists; no code; no test.
- `scaffold` — code exists; compiles; no test or trivial smoke only.
- `unit-tested` — code + targeted tests; passes locally.
- `audit-logged` — append-only event chain with hash continuity.
- `audited` — code + tests + adversarial self-review documented in repo.
- `mutation-proven` — survives mutation testing of load-bearing checks.
- `posture-observable-end-to-end` — visible from outside the binary via a documented integration test.
- `conformance-verified` — independent reference implementation agrees.

| Component | Proof level | Evidence |
|---|---|---|
| Psychrometric module (`src/psychrometric/mod.zig`) | `unit-tested` | 22 ERT cases pinned to ASHRAE 2021 Ch.1 reference values; verified by `zig build test --summary all` on 2026-05-20: `22 pass (22 total) 34ms` |
| Refrigerant module (`src/refrigerant/mod.zig`) | `unit-tested` | 21 ERT cases — table interpolation, monotonicity, NIST-style pinned values for R-134a / R-410A / R-32 / R-744; verified by `zig build test --summary all`: `21 pass (21 total) 26ms` |
| Cold-chain log (`src/coldchain/log.zig`) | `audit-logged` + `unit-tested` | 10 ERT cases covering SHA-256 entry hashes, replay, gap detection; verified `10 pass (10 total) 375ms` |
| Build gate (`zig build --sovereign-build-gate` pre-commit) | `posture-observable-end-to-end` | Pre-commit hook runs `zig build test` and refuses commits with red |
| Carrier audit-trail API (`experimental/carrier_core.zig`) | `scaffold` | 131 LOC; compiles; deliberately not wired into main binary |
| Carrier audit-node struct (`experimental/audit_node.zig`) | `scaffold` | 38 LOC; compiles |
| SCADA/BMS bronze ingest sketch (`experimental/ingest.zig`) | `scaffold` | 42 LOC; sketch; no real BMS data ingested |
| PTX dispatch sketch (`experimental/ptx_incursion.zig`) | `scaffold` | 43 LOC; deliberate scaffold; not yet wired |
| EnergyPlus / TRNSYS / OpenStudio cross-check | not started | named in README "Not yet" section |
| NIST REFPROP differential test | not started | named in README "Not yet" section |
| Production deployment | not started | gated behind post-ship Red Hat sequence per `~/AGENT_HARNESS.md` |

## Gate posture

carreir is past the **scaffold-and-hygiene** gate (its v1.0.0 tag) but not yet at any of these:

| Gate | Status |
|---|---|
| Zig 1.0 substrate | blocked on upstream Zig 1.0 release |
| EnergyPlus differential reference test | not started |
| NIST REFPROP cross-check on refrigerant tables | not started |
| Real BMS ingest (any building) | not started |
| PTX kernel dispatch | sketch only |
| Production soak (any duration, any deployment) | not started |
| Independent security review | not started |
| Corporate engagement / Red Hat sequence | gated behind ship-first execution doctrine (`feedback_ship_first_redhat_defense.md`) |

## What's safe to claim right now

- **53 ERT tests pass** on Zig 0.16 / Linux x86_64. Verified 2026-05-20 by `zig build test --summary all`. The test corpus pins values to:
  - ASHRAE 2021 Ch.1 psychrometric reference values (humidity ratio, enthalpy, dewpoint, saturation pressure via ASHRAE eq. 6).
  - NIST-style refrigerant table interpolation invariants (saturation-curve monotonicity, pinned values for R-134a / R-410A / R-32 / R-744).
  - Cold-chain log invariants (SHA-256-chained-append-only with gap detection between consecutive sensor reads).
- **The substrate is usable** for ASHRAE psychrometric calculations and refrigerant-table queries today.
- **Pre-commit gate works**: `zig build --sovereign-build-gate` refuses red commits.

## What's NOT safe to claim

- That carreir is production-ready.
- That it has been integrated with any real HVAC / BMS / SCADA system.
- That its calculations have been cross-validated against EnergyPlus / TRNSYS / OpenStudio / NIST REFPROP.
- That the corporate engagement layer (carrier_core audit API) is anything more than a scaffold.
- That the PTX dispatch path has any kernels.

## Audit history

- **2026-05-20 — Type-II drift caught.** README claimed 41/41 tests (16+18+7); actual is 53/53 (22+21+10). 12-test undercount, ~23% drift. Caught by `zig build test --summary all`. README + CHANGELOG corrected same commit. Logged as a calibration item in `~/agent-fleet/audit/calibration/CORPUS_PART_2.md` #039 (carreir CHANGELOG Type-I) and as a Type-II in this audit history.
- **2026-05-20 — Honesty correction.** v1.0.0 "production-grade hygiene milestone" framing identified as Type-I. Correction applied to CHANGELOG and this STATUS.md. Mirrors mast 2026-05-15 pattern.

## References

- `~/AGENT_HARNESS.md` — proof-vocabulary doctrine.
- `~/mast/STATUS.md` — the canonical model this STATUS adopts.
- `~/mast/CHANGELOG.md` §Honesty correction 2026-05-15 — the precedent.
- `~/agent-fleet/audit/calibration/CORPUS_PART_2.md` #039 — the calibration item that surfaced this correction.
- `~/agent-fleet/doclint/DESIGN.md` — the vocabulary discipline this STATUS aligns with.
- stax memory: `project_carreir.md`, `feedback_no_premature_production_claims.md`, `feedback_ship_first_redhat_defense.md`.
