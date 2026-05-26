# Changelog

All notable changes to `carreir` will be documented here. Format follows [Keep a Changelog](https://keepachangelog.com/); versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Honesty correction — 2026-05-20

Prior `v1.0.0` "production-grade hygiene milestone" framing (below) was a Type-I error class per the no-premature-production-claims doctrine.

Two independent reasons:

1. **Zig itself is on 0.16, not 1.0.** Until the Zig language hits 1.0, no Zig project can credibly claim API stability beyond "stable on Zig 0.16 today." Tagging v1.x against a pre-1.0 substrate is a vanity claim — the language guarantees aren't there yet.
2. **No production deployment exists.** carreir has zero real-traffic operation, zero soak time, zero production-incident history. The `v1.0.0` tag was described as a "production-grade hygiene milestone" — the hygiene work (LICENSE / SECURITY / CONTRIBUTING / CI) is real, but those are **shipping-process hygiene**: necessary, not sufficient, for "production-grade."

The hygiene work is real. The v1.x git tag is honored for changelog continuity. But every reader should treat this as a **pre-1.0 substrate** until both gates above close. See `STATUS.md` for the proof-vocabulary index.

Reuses the exact framing mast applied on 2026-05-15 (`~/mast/CHANGELOG.md` §"Honesty correction — 2026-05-15"). This is the same Type-I class; same correction; same vocabulary discipline.

### Type-II drift caught — 2026-05-20

`README.md` claimed "Tests: 41/41 pass on Zig 0.16 / Linux x86_64" and listed per-module counts of 16 (psychrometric) + 18 (refrigerant) + 7 (cold-chain log) = 41. The actual test count is **53/53** (22 psychrometric + 21 refrigerant + 10 cold-chain log), verified by `zig build test --summary all` on 2026-05-20:

```
Build Summary: 11/11 steps succeeded; 53/53 tests passed
+- run test 22 pass (22 total) 34ms
+- run test 21 pass (21 total) 26ms
+- run test 10 pass (10 total) 375ms
```

The README drift was 12 tests (~23% underclaim). This is the canonical class of Type-II error — *underclaiming* substrate by failing to update docs after new tests landed. Caught by re-running `zig build test --summary all` against the canonical CHANGELOG numbers.

README updated this commit to reflect the actual 53/53 count + per-module 22/21/10 breakdown.

## v1.0.0 — 2026-05-13

**[Originally framed as: "Production-grade hygiene milestone." See 2026-05-20 honesty correction above. The framing is preserved here for changelog continuity but the production-grade claim was not earned.]**

- LICENSE (AGPL-3.0), README, CONTRIBUTING, SECURITY, CI all present.
- Repo declared at v1.x milestone: existing surface stable; breaking changes bump to v2.x.
