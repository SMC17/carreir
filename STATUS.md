# carreir status

Last touched: 2026-05-27.
current_test_count: 54

## Version posture

**`v0.1.0`** — first explicit pre-1.0 tag. The earlier `v1.0.0` tag is
preserved in git history for changelog continuity but was a Type-I
overclaim (corrected 2026-05-20; see `CHANGELOG.md`). The substrate is
pre-1.0 in semver spirit for two reasons:

1. **Zig itself is on 0.16, not 1.0.** Until the Zig language hits 1.0,
   no Zig project can credibly claim API stability beyond "stable on
   Zig 0.16 today."
2. **No production deployment exists.** Zero real-traffic operation;
   zero soak time; zero production-incident history.

Versions from this point follow normal semver against the pre-1.0
convention: 0.1.0 → 0.1.1 (patch) → 0.2.0 (breaking) until both gates
above close, at which point a real v1.0 may issue.

## Proof-vocabulary index

- `claimed` — written in a doc; no code; no test.
- `designed` — spec / API exists; no code; no test.
- `scaffold` — code exists; compiles; no test or trivial smoke only.
- `unit-tested` — code + targeted tests; passes locally.
- `audit-logged` — append-only event chain with hash continuity.
- `model-checked` — formal spec exists and the model is mechanically
  verified by TLC.
- `audited` — code + tests + adversarial self-review documented.
- `posture-observable-end-to-end` — visible from outside the binary
  via a documented integration test.
- `conformance-verified` — independent reference implementation agrees.

| Component | Proof level | Evidence |
|---|---|---|
| Psychrometric module (`src/psychrometric/mod.zig`) | `unit-tested` | 22 cases pinned to ASHRAE 2021 Ch.1 reference values |
| Refrigerant module (`src/refrigerant/mod.zig`) | `unit-tested` | 21 cases — table interpolation, monotonicity, NIST-pinned values for R-134a / R-410A / R-32 / R-1234yf / R-744 |
| Cold-chain log (`src/coldchain/log.zig`) | `audit-logged` + `unit-tested` + `model-checked` | 10 cases covering HMAC chain, replay, tamper detection (incl. property-based fuzzing); TLA+ spec `Coldchain.tla` model-checked by CI |
| Chiller invariants (`src/chiller/mod.zig`) | `unit-tested` | 1 case — comptime safety invariant on a known-good cycle |
| Build gate (`zig build test`) | `posture-observable-end-to-end` | CI runs `zig build test --summary all` on every push to main |
| Test-count drift workflow | `posture-observable-end-to-end` | `.github/workflows/test-count-drift.yml` fails CI if declared `current_test_count` diverges from actual |
| EnergyPlus / TRNSYS / OpenStudio cross-check | not started | named in README "not" section |
| NIST REFPROP differential test | not started | named in README "not" section |
| Real BMS ingest (any building) | not started | gated post-ship |
| Production deployment | not started | gated post-ship |

## Gate posture

carreir is past the **substrate-and-hygiene** gate (v0.1.0) but not
yet at any of these:

| Gate | Status |
|---|---|
| Zig 1.0 substrate | blocked on upstream Zig 1.0 release |
| EnergyPlus differential reference test | not started |
| NIST REFPROP cross-check on refrigerant tables | not started |
| Real BMS ingest (any building) | not started |
| Production soak (any duration, any deployment) | not started |
| Independent security review | not started |

## What's safe to claim right now

- **54 ERT tests pass** on Zig 0.16 / Linux x86_64. Verified by
  `zig build test --summary all`. The corpus pins values to:
  - ASHRAE 2021 Ch.1 psychrometric reference values (humidity ratio,
    enthalpy, dewpoint, saturation pressure via ASHRAE eq. 6).
  - NIST-style refrigerant table interpolation invariants
    (saturation-curve monotonicity; pinned values for R-134a /
    R-410A / R-32 / R-1234yf / R-744).
  - Cold-chain log invariants (HMAC-SHA256 chained, tamper detection,
    determinism), reinforced by property-based fuzzing (200–500
    randomised trials per property).
- **The cold-chain log carries a TLA+ formal spec** (`Coldchain.tla`)
  that TLC model-checks for three invariants on every push touching
  the spec: `WriterLogIsAlwaysValid`, `TamperDetection`,
  `ReorderingDetected`.
- **CI catches test-count drift.** A workflow fails CI when the
  declared `current_test_count` and the actual count diverge.

## What's NOT safe to claim

- That carreir is production-ready.
- That it has been integrated with any real HVAC / BMS / SCADA system.
- That its calculations have been cross-validated against EnergyPlus
  / TRNSYS / OpenStudio / NIST REFPROP as software libraries.
- That the formal TLA+ spec covers anything other than the abstract
  HMAC-chain integrity property (it deliberately excludes HMAC-SHA256
  internals, wire format, confidentiality, and key-compromise
  scenarios).
- Any certified regulatory compliance (FDA 21 CFR Part 11, HACCP,
  EU GDP). The log shape is compatible with those requirements;
  compatibility is not certification.

## Audit history

- **2026-05-27 — v0.1.0 cut.** First explicit pre-1.0 tag; substrate
  hardened, scope tightened to the three unit-tested hulls plus the
  comptime chiller invariants. Earlier sketch modules removed from the
  public surface.
- **2026-05-22 — Type-II drift caught via CI.** Test-count workflow
  surfaced 41-residue drift; corrected to actual (`54`).
- **2026-05-20 — Type-II drift caught (manual).** README claimed 41/41
  tests; actual was 53/53. README + CHANGELOG corrected same commit.
- **2026-05-20 — Honesty correction.** v1.0.0 "production-grade
  hygiene milestone" framing identified as Type-I; CHANGELOG and
  STATUS corrected.
