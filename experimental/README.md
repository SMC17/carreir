# experimental/ — sketch-level scaffolds

Per `~/AGENT_HARNESS.md` evidence vocabulary, every file in this
directory is **`sketch`** — idea-or-prose-shaped code that compiles
but does not encode load-bearing physics or substrate.

These files are deliberately **not** in the main `zig build` path.
They are preserved as a record of earlier framing and may seed future
work, but they must not be confused with the substrate hulls under
`src/`.

## Files

| File | Status | Note |
|---|---|---|
| `ptx_incursion.zig` | `sketch` | PTX string template dressed as a kernel generator. "Theoretical Peak", "Carnot-cycle optimization" framing is aspirational rhetoric, not a real GPU codegen path. |
| `carrier_core.zig` | `sketch` | Shao-Yong `Hexagram` enum driving compressor speed via `random.uintAtMost(u6, 63)` is symbolic framing, not a thermodynamic control strategy. `calculateCOP` is one line of arithmetic on a hardcoded 3.517 kW/ton constant. `tokenizeAction` returns `0xCAFEBABE`. |
| `audit_node.zig` | `sketch` | "Audit" via `std.mem.indexOf` on PTX string templates. The asserted invariants are about whether the template contains certain literals, not about hardware properties. |
| `ingest.zig` | `sketch` | COBS-decode → return a hardcoded `PhysicalState`. The decode runs but the parsed bytes are discarded. |
| `main.zig` | `sketch` | Spawns 10 threads each running 10 random-Hexagram explorations. Demonstrates threading; does not demonstrate HVAC physics. |

## Why this matters

The first-principles HVAC/cold-chain substrate lives under `src/`:

- `src/psychrometric/` — ASHRAE Handbook 2021 moist-air primitives.
- `src/refrigerant/` — NIST-cited P-T saturation tables.
- `src/coldchain/` — HMAC-signed append-only reefer log.

A reader evaluating carreir as a substrate should read `src/`. This
directory is preserved for honesty (the work happened, name it for
what it is) and for any future agent who wants to rehabilitate one of
these sketches into a real module.

## Rehabilitation path

A sketch becomes substrate only when it earns a stronger evidence
label:

1. `sketch` → `scaffold` — code exists with a defined interface.
2. `scaffold` → `compiled` — builds under the main build path.
3. `compiled` → `unit-tested` — tests pass against cited reference data.
4. `unit-tested` → `integration-tested` — exercised end-to-end.

Nothing in this directory is past step 1.
