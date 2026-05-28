# Changelog

All notable changes to `carreir` will be documented here. Format follows [Keep a Changelog](https://keepachangelog.com/); versions follow [Semantic Versioning](https://semver.org/).

## v0.1.0 — 2026-05-27

First explicit pre-1.0 tag. Tightens the public surface to the substrate
that earns its keep under `zig build test`.

### Added

- `src/chiller/mod.zig` — comptime safety invariants for vapor-compression
  chiller cycles (surge and slugging). A cycle that violates the invariants
  fails to compile rather than failing in the field.
- `src/coldchain/Coldchain.tla` + `Coldchain.cfg` — TLA+ formal
  specification of the HMAC-chained cold-chain log; three safety
  invariants are pinned (`WriterLogIsAlwaysValid`, `TamperDetection`,
  `ReorderingDetected`).
- `.github/workflows/tla.yml` — TLC model-check on every push that
  touches the spec. SANY syntax check first, then TLC with
  `-workers 4 -deadlock -cleanup` and a 15-minute timeout.
- `.github/workflows/test-count-drift.yml` — fails CI when the declared
  `current_test_count` (in STATUS.md or README.md) diverges from
  `zig build test --summary all`.
- `.github/workflows/ci.yml` — now runs `zig build` and
  `zig build test --summary all` on every push and PR; the earlier
  workflow only verified file presence.
- Property-based test suites (200–500 randomised trials per property)
  for psychrometric, refrigerant, and cold-chain hulls.
- `src/coldchain/REGULATORY_MAP.md` — mapping from the on-disk format
  to FDA 21 CFR Part 11, HACCP, and EU GDP audit-trail requirements
  (compatibility, not certification).

### Changed

- README rewritten as a substrate description. Lead with what each
  hull does + the proof level + the honest non-claims.
- STATUS adopts the v0.1.0 posture and refreshes the proof-vocabulary
  index to include `model-checked`.
- Chiller invariants vocabulary normalised to plain language
  (compile-error on threshold violation) — no internal jargon on the
  public surface.

### Removed

- `experimental/` tree — sketches that never reached `unit-tested` and
  are not in the main build path. They are out of scope for v0.1 and
  do not constrain future re-introduction at a stronger proof level.
- Orphaned `src/refrigerant/eos.zig` and `src/refrigerant/cycle.zig`
  modules that were not wired into the build. The substrate is what
  the test step covers.
- Auxiliary positioning documents (WAR_PLAN, GEMINI, AGENTS) and
  vendor-catalog scaffolding that did not belong on a substrate
  surface.

### Notes

- 54/54 tests pass on Zig 0.16 / Linux x86_64. Verified by
  `zig build test --summary all` immediately before the tag.
- Earlier `v1.0.0` tag is preserved in git history for changelog
  continuity; see the 2026-05-20 honesty correction below.

## [pre-0.1] — Honesty correction — 2026-05-20

Prior `v1.0.0` "production-grade hygiene milestone" framing was a
Type-I error class per the no-premature-production-claims doctrine.

Two independent reasons:

1. **Zig itself is on 0.16, not 1.0.** Until the Zig language hits 1.0,
   no Zig project can credibly claim API stability beyond "stable on
   Zig 0.16 today." Tagging v1.x against a pre-1.0 substrate is a
   vanity claim — the language guarantees aren't there yet.
2. **No production deployment exists.** carreir has zero real-traffic
   operation, zero soak time, zero production-incident history. The
   `v1.0.0` tag was described as a "production-grade hygiene
   milestone" — the hygiene work (LICENSE / SECURITY / CONTRIBUTING /
   CI) is real, but those are **shipping-process hygiene**: necessary,
   not sufficient, for "production-grade."

The hygiene work is real. The v1.x git tag is honored for changelog
continuity. But every reader should treat this as a pre-1.0 substrate
until both gates above close. See `STATUS.md` for the proof-vocabulary
index.

## [pre-0.1] — Type-II drift caught — 2026-05-20

`README.md` claimed "Tests: 41/41 pass on Zig 0.16 / Linux x86_64".
The actual test count was **53/53** (22 psychrometric + 21 refrigerant
+ 10 cold-chain log), verified by `zig build test --summary all`.

The README drift was 12 tests (~23% underclaim) — the canonical class
of Type-II error: underclaiming substrate by failing to update docs
after new tests landed.

## v1.0.0 — 2026-05-13

**[Originally framed as: "Production-grade hygiene milestone." See the
2026-05-20 honesty correction above. The framing is preserved here for
changelog continuity but the production-grade claim was not earned.]**

- LICENSE (AGPL-3.0), README, CONTRIBUTING, SECURITY, CI all present.
- Repo declared at v1.x milestone (later corrected to pre-1.0).
